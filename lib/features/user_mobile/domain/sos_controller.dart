import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:disaster_response_app/core/database/app_database.dart';
import 'package:disaster_response_app/core/database/db_provider.dart';
import 'package:disaster_response_app/core/services/sms_fallback_service.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:drift/drift.dart';

/// Trạng thái của SOS request
enum SOSStatus {
  idle,
  loading,
  success,
  error,
  fallbackActivated,
}

/// State class cho SOS Controller
class SOSState {
  final SOSStatus status;
  final String? message;
  final String? errorMessage;

  SOSState({
    this.status = SOSStatus.idle,
    this.message,
    this.errorMessage,
  });

  SOSState copyWith({
    SOSStatus? status,
    String? message,
    String? errorMessage,
  }) {
    return SOSState(
      status: status ?? this.status,
      message: message ?? this.message,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// SOS Controller - Quản lý logic SOS
class SOSController extends StateNotifier<SOSState> {
  final SmsFallbackService _smsFallback;
  final AppDatabase _db;
  final FirebaseFirestore _firestore;

  SOSController(
    this._db, {
    SmsFallbackService? smsFallback,
    FirebaseFirestore? firestore,
  })  : _smsFallback = smsFallback ?? SmsFallbackService(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        super(SOSState());

  Future<void> _saveLocally({
    required String postId,
    required String locationId,
    required String userName,
    required String phoneNumber,
    required String description,
    required double latitude,
    required double longitude,
    required DateTime createdAt,
  }) async {
    final post = PostsCompanion(
      id: Value(postId),
      eventId: const Value('sos'),
      userId: Value(phoneNumber),
      postType: const Value('sos'),
      title: const Value('SOS khẩn cấp'),
      content: Value(description),
      isVerified: const Value(false),
      createdAt: Value(createdAt),
      syncStatus: const Value('pending'),
    );

    final location = LocationsCompanion(
      id: Value(locationId),
      postId: Value(postId),
      latitude: Value(latitude),
      longitude: Value(longitude),
      addressText: const Value(null),
    );

    await _db.transaction(() async {
      await _db.into(_db.posts).insert(post);
      await _db.into(_db.locations).insert(location);
    });
  }

  Future<void> _uploadToFirebase({
    required String postId,
    required String locationId,
    required String userName,
    required String phoneNumber,
    required String description,
    required double latitude,
    required double longitude,
    required DateTime createdAt,
  }) async {
    final postData = {
      'userId': phoneNumber,
      'eventId': 'sos',
      'postType': 'sos',
      'title': 'SOS khẩn cấp',
      'content': description,
      'isVerified': false,
      'createdAt': Timestamp.fromDate(createdAt),
      'syncStatus': 'synced',
      'latitude': latitude,
      'longitude': longitude,
      'phoneNumber': phoneNumber,
    };

    final locationData = {
      'postId': postId,
      'latitude': latitude,
      'longitude': longitude,
      'addressText': null,
    };

    final batch = _firestore.batch();
    final postRef = _firestore.collection('posts').doc(postId);
    final locationRef = _firestore.collection('locations').doc(locationId);
    batch.set(postRef, postData);
    batch.set(locationRef, locationData);
    await batch.commit();

    await (_db.update(_db.posts)..where((tbl) => tbl.id.equals(postId))).write(
      PostsCompanion(syncStatus: const Value('synced')),
    );
  }

  /// Gửi SOS request
  /// Quy trình:
  /// 1. Nếu đã có tọa độ truyền vào thì dùng trực tiếp
  /// 2. Nếu chưa có tọa độ thì lấy GPS một lần ở cấp controller
  /// 3. Lưu dữ liệu vào Drift database
  /// 4. Kiểm tra mạng. Nếu có -> Gửi lên Firebase
  /// 5. Nếu không có mạng -> Kích hoạt SMS Fallback
  Future<void> sendSOS({
    required String userName,
    required String phoneNumber,
    required String description,
    double? latitude,
    double? longitude,
  }) async {
    try {
      state = state.copyWith(status: SOSStatus.loading, message: 'Đang gửi SOS...');

      double lat;
      double lng;
      if ((latitude == null) != (longitude == null)) {
        state = state.copyWith(
          status: SOSStatus.error,
          errorMessage:
              'Cần truyền đầy đủ latitude và longitude hoặc không truyền cả hai.',
        );
        return;
      }

      if (latitude != null && longitude != null) {
        lat = latitude;
        lng = longitude;
      } else {
        final position = await _smsFallback.getCurrentLocation();
        if (position == null) {
          state = state.copyWith(
            status: SOSStatus.error,
            errorMessage:
                'Không thể xác định vị trí. Vui lòng bật GPS và thử lại.',
          );
          return;
        }

        lat = position.latitude;
        lng = position.longitude;
      }

      final createdAt = DateTime.now();
      final postId = 'sos_${createdAt.microsecondsSinceEpoch}';
      final locationId = 'location_$postId';

      await _saveLocally(
        postId: postId,
        locationId: locationId,
        userName: userName,
        phoneNumber: phoneNumber,
        description: description,
        latitude: latitude,
        longitude: longitude,
        createdAt: createdAt,
      );

      final hasNetwork = await _smsFallback.hasNetworkConnection();
      if (hasNetwork) {
        await _uploadToFirebase(
          postId: postId,
          locationId: locationId,
          userName: userName,
          phoneNumber: phoneNumber,
          description: description,
          latitude: latitude,
          longitude: longitude,
          createdAt: createdAt,
        );

        state = state.copyWith(
          status: SOSStatus.success,
          message: 'SOS đã gửi lên máy chủ thành công.',
        );
        return;
      }

      state = state.copyWith(
        status: SOSStatus.loading,
        message: 'Không có mạng, gửi SMS khẩn cấp...',
      );

      final smsSent = await _smsFallback.activateEmergencyFallback(
        userName: userName,
        phoneNumber: phoneNumber,
        latitude: latitude,
        longitude: longitude,
        description: description,
      );

      if (smsSent) {
        state = state.copyWith(
          status: SOSStatus.fallbackActivated,
          message: 'SMS khẩn cấp đã gửi thành công.',
        );
      } else {
        state = state.copyWith(
          status: SOSStatus.error,
          errorMessage: 'Gửi SMS thất bại. Vui lòng kiểm tra quyền và kết nối.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: SOSStatus.error,
        errorMessage: 'Lỗi: $e',
      );
      print('Error in sendSOS: $e');
    }
  }

  /// Reset SOS state
  void reset() {
    state = SOSState();
  }
}

/// Provider cho SOS Controller
final sosControllerProvider =
    StateNotifierProvider<SOSController, SOSState>((ref) {
  return SOSController(ref.watch(dbProvider));
});
