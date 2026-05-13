// lib/core/services/firebase/fcm_service.dart
//
// Firebase Cloud Messaging Service — OmniDisaster
// ─────────────────────────────────────────────────────────────────────────────
// Mô hình hoạt động:
//
//   [FCM Server]
//       │  publish to topic "disaster_alerts"
//       ▼
//   [FCM SDK]
//       ├── App TERMINATED  → firebaseMessagingBackgroundHandler()  [isolate riêng]
//       ├── App BACKGROUND  → firebaseMessagingBackgroundHandler()  [isolate riêng]
//       └── App FOREGROUND  → onMessage.listen() → FlutterLocalNotifications
//
// Dependencies (pubspec.yaml):
//   firebase_messaging: ^15.x.x
//   flutter_local_notifications: ^18.x.x
//
// Android thêm vào AndroidManifest.xml (xem hướng dẫn cuối file).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui';
import 'dart:convert';
import 'dart:async';

import 'package:disaster_response_app/core/routes/route_names.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

// =============================================================================
// BACKGROUND HANDLER — top-level function (bắt buộc)
// =============================================================================

/// Xử lý tin nhắn FCM khi app đang BACKGROUND hoặc TERMINATED.
///
/// ⚠️  PHẢI là hàm top-level (không nằm trong class).
/// ⚠️  PHẢI có annotation `@pragma('vm:entry-point')` để Dart AOT compiler
///     không tree-shake hàm này — Flutter sẽ gọi nó từ một isolate riêng.
///
/// Lưu ý: Ở trạng thái này FCM tự hiển thị notification từ `notification`
/// payload mà không cần FlutterLocalNotifications. Hàm này dùng để xử lý
/// logic phụ (ví dụ: ghi log, cập nhật badge, lưu DB local...).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Không cần gọi Firebase.initializeApp() ở đây —
  // FlutterFire tự khởi tạo trong isolate background kể từ firebase_core 2.x.

  debugPrint(
    '[FCM Background] id=${message.messageId} '
    'title=${message.notification?.title} '
    'data=${message.data} '
    'postType=${message.data['postType']}',
  );

  // TODO: Nếu cần ghi Drift / SharedPreferences từ background,
  // khởi tạo chúng ở đây trước khi dùng.
}

// =============================================================================
// ANDROID NOTIFICATION CHANNEL
// =============================================================================

/// Channel ID phải khớp với `android:channelId` trong AndroidManifest.xml
/// (xem hướng dẫn cuối file).
const _kChannelId = 'disaster_alerts_channel';
const _kChannelName = 'Cảnh báo Thiên tai';
const _kChannelDesc =
    'Thông báo khẩn cấp về thiên tai, lũ lụt và chỉ đạo sơ tán từ Ban Chỉ huy';

/// Channel với độ ưu tiên MAX để hiển thị Heads-up notification
/// (popup trên đầu màn hình ngay cả khi điện thoại đang dùng).
const AndroidNotificationChannel _kDisasterChannel = AndroidNotificationChannel(
  _kChannelId,
  _kChannelName,
  description: _kChannelDesc,
  importance: Importance.max,       // Heads-up notification
  playSound: true,
  enableVibration: true,
  enableLights: true,
  ledColor: Color(0xFFDC2626),       // Đèn LED đỏ (thiết bị hỗ trợ)
);

// =============================================================================
// FCM SERVICE
// =============================================================================

/// Singleton service quản lý toàn bộ vòng đời FCM.
///
/// Sử dụng:
/// ```dart
/// // Trong main.dart, SAU WidgetsFlutterBinding.ensureInitialized() và
/// // SAU Firebase.initializeApp():
/// await FCMService.instance.initialize();
/// ```
class FCMService {
  FCMService._();
  static final FCMService instance = FCMService._();

  // ── Internal references ───────────────────────────────────────────────────
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  // Giữ FCM token hiện tại để gửi targeted notification nếu cần
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // Guard tránh gọi initialize() nhiều lần
  bool _initialized = false;

  // Router được inject từ main.dart để service có thể điều hướng ngoài BuildContext.
  GoRouter? _router;

  // Queue điều hướng khi app mở từ terminated state trước khi router attach xong.
  String? _pendingNewsPostId;

  // Payload keys
  static const _kPayloadScreen = 'screen';
  static const _kPayloadPostId = 'postId';
  static const _kPayloadNewsId = 'newsId';
  static const _kPayloadPostIdSnake = 'post_id';
  static const _kPayloadId = 'id';

  /// Gắn [GoRouter] sau khi app tạo router.
  ///
  /// Cần gọi trong main trước runApp để xử lý được initial notification tap.
  void attachRouter(GoRouter router) {
    _router = router;
    _flushPendingNavigation();
  }

  // ==========================================================================
  // PUBLIC — initialize
  // ==========================================================================

  /// Khởi tạo toàn bộ FCM pipeline.
  ///
  /// Thứ tự quan trọng:
  ///   1. Đăng ký background handler
  ///   2. Xin quyền (iOS / Android 13+)
  ///   3. Cấu hình local notifications channel
  ///   4. Subscribe topic
  ///   5. Lắng nghe foreground messages
  ///   6. Lắng nghe khi user tap notification (app từ background lên)
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    debugPrint('[FCMService] 🔍 [START] Khởi tạo FCM Service...');

    // ── 1. Đăng ký background handler ────────────────────────────────────────
    // Phải gọi TRƯỚC khi app xử lý bất kỳ message nào.
    debugPrint('[FCMService] ① Đăng ký background handler...');
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    debugPrint('[FCMService] ① Background handler đã đăng ký ✓');

    // ── 2. Xin quyền thông báo ────────────────────────────────────────────────
    debugPrint('[FCMService] ② Xin quyền thông báo (Android 13+/iOS)...');
    await _requestPermission();

    // ── 3. Cấu hình FlutterLocalNotifications ────────────────────────────────
    debugPrint('[FCMService] ③ Cấu hình local notifications channel...');
    await _setupLocalNotifications();
    debugPrint('[FCMService] ③ Local notifications đã cấu hình ✓');

    // ── 4. Lấy & log FCM token (debug) ───────────────────────────────────────
    debugPrint('[FCMService] ④ Lấy FCM token từ Firebase Installations...');
    await _fetchToken();
    debugPrint('[FCMService] ④ FCM token: $_fcmToken ${_fcmToken == null ? '❌ NULL' : '✓'}');

    // ── 5. Subscribe topic ────────────────────────────────────────────────────
    debugPrint('[FCMService] ⑤ Subscribe topic disaster_alerts...');
    await _subscribeTopics();

    // ── 6. Lắng nghe foreground messages ─────────────────────────────────────
    debugPrint('[FCMService] ⑥ Setup foreground message listener...');
    _listenForeground();
    debugPrint('[FCMService] ⑥ Foreground listener đã setup ✓');

    // ── 7. Xử lý notification tap (app đang background → foreground) ─────────
    debugPrint('[FCMService] ⑦ Setup notification tap listener (onMessageOpenedApp)...');
    _listenNotificationTap();
    debugPrint('[FCMService] ⑦ Notification tap listener đã setup ✓');

    // ── 8. Xử lý initial message (app TERMINATED, user tap → mở app) ─────────
    debugPrint('[FCMService] ⑧ Kiểm tra initial message (app từ terminated)...');
    await _handleInitialMessage();
    debugPrint('[FCMService] ⑧ Initial message check hoàn tất ✓');

    debugPrint('[FCMService] 🔍 [DONE] Khởi tạo hoàn tất. Token: $_fcmToken ${_fcmToken == null ? '⚠️ NULL - KHÔNG SUBSCRIBE ĐƯỢC TOPIC' : '✓'}');
  }

  // ==========================================================================
  // PRIVATE STEPS
  // ==========================================================================

  // ── 2. Request permission ─────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    debugPrint('[FCMService] _requestPermission() START');
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        // criticalAlert: true — chỉ dùng nếu được Apple cấp entitlement đặc biệt
        provisional: false,  // false = hỏi user ngay, không dùng provisional
        announcement: false,
        carPlay: false,
      );

      debugPrint(
        '[FCMService] ✓ Quyền thông báo: ${settings.authorizationStatus.name}',
      );
    } catch (e) {
      debugPrint('[FCMService] ❌ Lỗi _requestPermission(): $e');
    }

    // Trên Android, FCM tự xử lý quyền qua POST_NOTIFICATIONS (API 33+).
    // Trên iOS, nếu user từ chối → không nhận được alert/sound nhưng
    // data-only messages vẫn đến và background handler vẫn chạy.
  }

  // ── 3. Setup local notifications ─────────────────────────────────────────

  Future<void> _setupLocalNotifications() async {
    // ── Android: tạo high-priority channel ──────────────────────────────────
    final androidPlugin = _localNotif.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(_kDisasterChannel);

    // ── Khởi tạo plugin với cấu hình từng platform ───────────────────────────
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings(
        // Tên file icon (không có đuôi) trong android/app/src/main/res/drawable/
        // Nên dùng icon trắng/trong suốt (monochrome) theo Material guideline.
        '@drawable/ic_notification',
      ),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,  // Đã xin qua requestPermission() ở trên
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _localNotif.initialize(
      settings: initSettings,
      // Callback khi user TAP vào notification lúc app đang FOREGROUND
      onDidReceiveNotificationResponse: _onLocalNotifTap,
    );
  }

  // ── 4. Fetch token ────────────────────────────────────────────────────────

  Future<void> _fetchToken() async {
    debugPrint('[FCMService] _fetchToken() START - gọi FirebaseMessaging.instance.getToken()...');
    try {
      debugPrint('[FCMService] Chờ getToken() (này có thể bị timeout nếu FIS_AUTH_ERROR)...');
      _fcmToken = await _messaging.getToken().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[FCMService] ⏱️ getToken() TIMEOUT sau 10 giây');
          return null;
        },
      );

      if (_fcmToken == null) {
        debugPrint('[FCMService] ⚠️ getToken() trả về NULL (có thể FIS_AUTH_ERROR hoặc timeout)');
      } else {
        debugPrint('[FCMService] ✓ getToken() thành công: $_fcmToken');
      }

      // Lắng nghe token refresh (xảy ra khi reinstall, restore backup...)
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('[FCMService] 🔄 Token refresh listener: Token mới = $newToken');
        // TODO: Gửi token mới lên Firestore nếu dùng targeted notification
        // _saveTokenToFirestore(newToken);
      }, onError: (e) {
        debugPrint('[FCMService] ❌ Token refresh listener error: $e');
      });

      debugPrint('[FCMService] ✓ Token refresh listener đã setup');
    } catch (e, stackTrace) {
      debugPrint('[FCMService] ❌ _fetchToken() ERROR: $e\nStacktrace: $stackTrace');
      _fcmToken = null;
    }
  }

  // ── 5. Subscribe topics ───────────────────────────────────────────────────

  Future<void> _subscribeTopics() async {
    debugPrint('[FCMService] _subscribeTopics() START - token=$_fcmToken');
    if (_fcmToken == null) {
      debugPrint('[FCMService] ⚠️ Token NULL → không thể subscribe (bỏ qua)');
      return;
    }
    try {
      // Topic chính: tất cả cảnh báo thiên tai
      debugPrint('[FCMService] Gọi subscribeToTopic("disaster_alerts") với timeout 8s...');
      await _messaging
          .subscribeToTopic('disaster_alerts')
          .timeout(const Duration(seconds: 8));
      debugPrint('[FCMService] ✓ Đã subscribe topic: disaster_alerts');

      // Có thể subscribe thêm topic theo tỉnh/khu vực nếu cần:
      // await _messaging.subscribeToTopic('region_danang');
    } on TimeoutException {
      debugPrint(
        '[FCMService] ⏱️ Subscribe topic TIMEOUT sau 8 giây (bỏ qua để không chặn app)',
      );
    } catch (e, stackTrace) {
      debugPrint('[FCMService] ❌ Lỗi subscribe topic: $e\nStacktrace: $stackTrace');
    }
  }

  // ── 6. Foreground message listener ───────────────────────────────────────

  void _listenForeground() {
    debugPrint('[FCMService] _listenForeground() - setup onMessage listener...');
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        '[FCMService] 📬 Foreground message nhận được: title="${message.notification?.title}" body="${message.notification?.body}" data=${message.data}',
      );

      final notification = message.notification;
      if (notification == null) return;

      // FCM KHÔNG tự show notification khi app đang foreground —
      // phải dùng FlutterLocalNotifications để hiển thị thủ công.
      _showLocalNotification(
        id: message.hashCode,
        title: notification.title ?? 'Cảnh báo OmniDisaster',
        body: notification.body ?? '',
        payload: jsonEncode({
          _kPayloadScreen: message.data[_kPayloadScreen],
          _kPayloadPostId: message.data[_kPayloadPostId],
        }),
      );
    });
  }

  // ── 7. Background tap listener ────────────────────────────────────────────

  void _listenNotificationTap() {
    debugPrint('[FCMService] _listenNotificationTap() - setup onMessageOpenedApp listener...');
    // onMessageOpenedApp: user tap notification khi app đang BACKGROUND
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(
        '[FCMService] 👆 User tap notification (app từ background): title="${message.notification?.title}" data=${message.data}',
      );
      _handleNavigationFromMessage(message);
    }, onError: (e) {
      debugPrint('[FCMService] ❌ onMessageOpenedApp listener error: $e');
    });
  }

  // ── 8. Initial message (app TERMINATED) ──────────────────────────────────

  Future<void> _handleInitialMessage() async {
    debugPrint('[FCMService] _handleInitialMessage() - kiểm tra xem app có được mở từ notification (terminated state) không...');
    // getInitialMessage() trả về message nếu app vừa được mở từ notification
    // khi đang ở trạng thái TERMINATED (bị kill hoàn toàn).
    try {
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint(
          '[FCMService] ✓ App mở từ terminated state (initial message found): title="${initialMessage.notification?.title}" data=${initialMessage.data}',
        );
        _handleNavigationFromMessage(initialMessage);
      } else {
        debugPrint(
          '[FCMService] ℹ️ Không có initial message (app mở bình thường, không phải từ notification)',
        );
      }
    } catch (e) {
      debugPrint('[FCMService] ❌ Error getInitialMessage(): $e');
    }
  }

  // ==========================================================================
  // PRIVATE HELPERS
  // ==========================================================================

  /// Hiển thị local notification với heads-up style (xuất hiện trên đầu màn hình).
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    debugPrint('[FCMService] _showLocalNotification() START: id=$id title="$title" payload=$payload');
    final androidDetails = AndroidNotificationDetails(
      _kChannelId,
      _kChannelName,
      channelDescription: _kChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      // Heads-up notification trên Android
      fullScreenIntent: false,
      // Icon nhỏ (monochrome) hiện trên status bar
      icon: '@drawable/ic_notification',
      // Màu nền icon (tông đỏ OmniDisaster)
      color: const Color(0xFFDC2626),
      // Ticker text cho accessibility
      ticker: title,
      // Tự động đóng khi user tap
      autoCancel: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _localNotif.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
      debugPrint('[FCMService] ✓ Local notification đã show thành công');
    } catch (e) {
      debugPrint('[FCMService] ❌ Error _showLocalNotification(): $e');
    }
  }

  /// Callback khi user tap vào local notification (app FOREGROUND).
  void _onLocalNotifTap(NotificationResponse response) {
    final payload = response.payload;
    debugPrint('[FCMService] _onLocalNotifTap() - Local notification tapped. id=${response.id} payload=$payload');
    if (payload == null || payload.isEmpty) {
      debugPrint('[FCMService] ⚠️ Payload rỗng, bỏ qua');
      return;
    }

    try {
      final decoded = jsonDecode(payload);
      debugPrint('[FCMService] ✓ Payload decoded: $decoded');
      if (decoded is! Map<String, dynamic>) {
        debugPrint('[FCMService] ❌ Payload không phải Map<String, dynamic>');
        return;
      }

      final screen = decoded[_kPayloadScreen] as String?;
      final postId = _extractPostId(decoded);

      debugPrint('[FCMService] screen=$screen, postId=$postId');

      if (_isNewsScreen(screen) && postId != null && postId.isNotEmpty) {
        debugPrint('[FCMService] 📄 Nắng dùng _navigateToNewsDetail($postId)');
        _navigateToNewsDetail(postId);
      } else {
        debugPrint(
          '[FCMService] ❌ Thiếu postId hợp lệ hoặc screen không phải news. '
          'screen=$screen postId=$postId payload=$decoded',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[FCMService] ❌ Error _onLocalNotifTap(): $e\nStacktrace: $stackTrace');
      // backward-compat: payload cũ có thể chỉ là screen string.
    }
  }

  /// Điều hướng dựa trên data payload của FCM message.
  ///
  /// Payload format ví dụ:
  /// ```json
  /// {
  ///   "notification": { "title": "...", "body": "..." },
  ///   "data": { "screen": "sos_list", "eventId": "abc123" }
  /// }
  /// ```
  void _handleNavigationFromMessage(RemoteMessage message) {
    final screen = message.data[_kPayloadScreen] as String?;
    final postId = _extractPostId(message.data);

    debugPrint('[FCMService] _handleNavigationFromMessage() - screen=$screen postId=$postId, data=${message.data}');

    if (_isNewsScreen(screen) && postId != null && postId.isNotEmpty) {
      debugPrint('[FCMService] 🔗 Nắng dùng _navigateToNewsDetail($postId)');
      _navigateToNewsDetail(postId);
      return;
    }

    debugPrint('[FCMService] ⚠️ Không có route phù hợp cho payload: screen=$screen postId=$postId');
  }

  String? _extractPostId(Map<String, dynamic> data) {
    debugPrint('[FCMService] _extractPostId() - tìm postId trong data=${data.keys.toList()}');
    final candidates = <String?>[data[_kPayloadPostId] as String?, data[_kPayloadNewsId] as String?, data[_kPayloadPostIdSnake] as String?, data[_kPayloadId] as String?];

    for (final value in candidates) {
      final v = value?.trim();
      if (v != null && v.isNotEmpty) {
        debugPrint('[FCMService] ✓ PostId found: $v');
        return v;
      }
    }
    debugPrint('[FCMService] ❌ PostId not found in candidates: $candidates');
    return null;
  }

  bool _isNewsScreen(String? screen) {
    if (screen == null) return false;
    return screen == 'news_detail' ||
        screen == 'citizen_news_detail' ||
        screen == RouteNames.nameNewsDetail;
  }

  void _navigateToNewsDetail(String postId) {
    final router = _router;
    debugPrint('[FCMService] _navigateToNewsDetail($postId) - router=${router != null ? 'READY' : 'NOT_YET'} ');
    if (router == null) {
      _pendingNewsPostId = postId;
      debugPrint('[FCMService] ⚠️ Router chưa sẵn sàng, queue postId=$postId để điều hướng sau');
      return;
    }

    try {
      debugPrint('[FCMService] 🔗 pushNamed(${RouteNames.nameNewsDetail}, pathParameters={postId: $postId})');
      router.pushNamed(
        RouteNames.nameNewsDetail,
        pathParameters: {RouteNames.paramPostId: postId},
      );
      debugPrint('[FCMService] ✓ Navigation thành công');
    } catch (e) {
      debugPrint('[FCMService] ❌ Error pushNamed: $e');
    }
  }

  void _flushPendingNavigation() {
    final pending = _pendingNewsPostId;
    debugPrint('[FCMService] _flushPendingNavigation() - pending postId=$pending');
    if (pending == null) {
      debugPrint('[FCMService] Không có pending navigation');
      return;
    }

    _pendingNewsPostId = null;
    debugPrint('[FCMService] 🔗 Processing pending navigation: postId=$pending');
    _navigateToNewsDetail(pending);
  }

  // ==========================================================================
  // PUBLIC UTILITIES
  // ==========================================================================

  /// Huỷ subscribe khi user đăng xuất hoặc tắt thông báo trong Settings.
  Future<void> unsubscribeAll() async {
    await _messaging.unsubscribeFromTopic('disaster_alerts');
    debugPrint('[FCMService] Đã unsubscribe tất cả topics');
  }

  /// Xoá tất cả local notifications đang hiển thị (dùng sau khi user đọc hết).
  Future<void> clearAllNotifications() async {
    await _localNotif.cancelAll();
  }

  /// Yêu cầu FCM xoá token hiện tại (dùng khi user đăng xuất).
  Future<void> deleteToken() async {
    await _messaging.deleteToken();
    _fcmToken = null;
    debugPrint('[FCMService] Đã xoá FCM token');
  }
}