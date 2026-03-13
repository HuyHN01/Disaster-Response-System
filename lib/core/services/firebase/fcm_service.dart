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

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
    'title=${message.notification?.title}',
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

    // ── 1. Đăng ký background handler ────────────────────────────────────────
    // Phải gọi TRƯỚC khi app xử lý bất kỳ message nào.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // ── 2. Xin quyền thông báo ────────────────────────────────────────────────
    await _requestPermission();

    // ── 3. Cấu hình FlutterLocalNotifications ────────────────────────────────
    await _setupLocalNotifications();

    // ── 4. Lấy & log FCM token (debug) ───────────────────────────────────────
    await _fetchToken();

    // ── 5. Subscribe topic ────────────────────────────────────────────────────
    await _subscribeTopics();

    // ── 6. Lắng nghe foreground messages ─────────────────────────────────────
    _listenForeground();

    // ── 7. Xử lý notification tap (app đang background → foreground) ─────────
    _listenNotificationTap();

    // ── 8. Xử lý initial message (app TERMINATED, user tap → mở app) ─────────
    await _handleInitialMessage();

    debugPrint('[FCMService] Khởi tạo hoàn tất. Token: $_fcmToken');
  }

  // ==========================================================================
  // PRIVATE STEPS
  // ==========================================================================

  // ── 2. Request permission ─────────────────────────────────────────────────

  Future<void> _requestPermission() async {
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
      '[FCMService] Quyền thông báo: ${settings.authorizationStatus.name}',
    );

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
    try {
      _fcmToken = await _messaging.getToken();

      // Lắng nghe token refresh (xảy ra khi reinstall, restore backup...)
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('[FCMService] Token mới: $newToken');
        // TODO: Gửi token mới lên Firestore nếu dùng targeted notification
        // _saveTokenToFirestore(newToken);
      });
    } catch (e) {
      debugPrint('[FCMService] Không lấy được token: $e');
    }
  }

  // ── 5. Subscribe topics ───────────────────────────────────────────────────

  Future<void> _subscribeTopics() async {
    try {
      // Topic chính: tất cả cảnh báo thiên tai
      await _messaging.subscribeToTopic('disaster_alerts');
      debugPrint('[FCMService] Đã subscribe topic: disaster_alerts');

      // Có thể subscribe thêm topic theo tỉnh/khu vực nếu cần:
      // await _messaging.subscribeToTopic('region_danang');
    } catch (e) {
      debugPrint('[FCMService] Lỗi subscribe topic: $e');
    }
  }

  // ── 6. Foreground message listener ───────────────────────────────────────

  void _listenForeground() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        '[FCMService] Foreground message: ${message.notification?.title}',
      );

      final notification = message.notification;
      if (notification == null) return;

      // FCM KHÔNG tự show notification khi app đang foreground —
      // phải dùng FlutterLocalNotifications để hiển thị thủ công.
      _showLocalNotification(
        id: message.hashCode,
        title: notification.title ?? 'Cảnh báo OmniDisaster',
        body: notification.body ?? '',
        payload: message.data['screen'], // Dữ liệu tuỳ chỉnh để điều hướng
      );
    });
  }

  // ── 7. Background tap listener ────────────────────────────────────────────

  void _listenNotificationTap() {
    // onMessageOpenedApp: user tap notification khi app đang BACKGROUND
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(
        '[FCMService] User mở app từ notification: ${message.notification?.title}',
      );
      _handleNavigationFromMessage(message);
    });
  }

  // ── 8. Initial message (app TERMINATED) ──────────────────────────────────

  Future<void> _handleInitialMessage() async {
    // getInitialMessage() trả về message nếu app vừa được mở từ notification
    // khi đang ở trạng thái TERMINATED (bị kill hoàn toàn).
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint(
        '[FCMService] App mở từ terminated state: '
        '${initialMessage.notification?.title}',
      );
      _handleNavigationFromMessage(initialMessage);
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

    await _localNotif.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Callback khi user tap vào local notification (app FOREGROUND).
  void _onLocalNotifTap(NotificationResponse response) {
    final payload = response.payload;
    debugPrint('[FCMService] Local notification tapped. payload=$payload');
    // TODO: điều hướng dựa trên payload
    // Ví dụ: if (payload == 'sos_list') { navigatorKey.currentState?.pushNamed('/sos'); }
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
    final screen = message.data['screen'] as String?;
    final eventId = message.data['eventId'] as String?;

    debugPrint('[FCMService] Navigate to: screen=$screen eventId=$eventId');

    // TODO: Dùng GoRouter hoặc navigatorKey để điều hướng
    // Ví dụ với GlobalKey<NavigatorState>:
    //
    // switch (screen) {
    //   case 'event_detail':
    //     if (eventId != null) {
    //       navigatorKey.currentState?.pushNamed('/event/$eventId');
    //     }
    //   case 'sos_list':
    //     navigatorKey.currentState?.pushNamed('/sos');
    //   default:
    //     navigatorKey.currentState?.pushNamed('/home');
    // }
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