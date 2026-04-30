import 'package:disaster_response_app/core/database/app_database.dart';
import 'package:disaster_response_app/core/services/sms_fallback_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

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
  final SmsFallbackService _smsFallback = SmsFallbackService();

  SOSController() : super(SOSState());

  /// Gửi SOS request
  /// Quy trình:
  /// 1. Lưu dữ liệu vào Drift database
  /// 2. Kiểm tra mạng. Nếu có -> Gửi lên Firebase
  /// 3. Nếu không có mạng -> Kích hoạt SMS Fallback
  Future<void> sendSOS({
    required String userName,
    required String phoneNumber,
    required double latitude,
    required double longitude,
    required String description,
  }) async {
    try {
      state = state.copyWith(status: SOSStatus.loading, message: 'Gửi SOS...');

      // Bước 1: Lưu dữ liệu vào database (Drift)
      // Giả định bạn có một bảng SOS trong database
      // Lưu SOS vào database để backup dữ liệu
      print('Saving SOS data to database...');
      final sosData = {
        'userName': userName,
        'phoneNumber': phoneNumber,
        'latitude': latitude,
        'longitude': longitude,
        'description': description,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // TODO: Implement database save when SOS table is created
      // await _database.sosDAO.insertSOS(sosData);
      print('SOS data saved to database (TODO: implement database save)');

      // Bước 2: Kiểm tra mạng
      final hasNetwork = await _smsFallback.hasNetworkConnection();

      if (hasNetwork) {
        // Có mạng -> Gửi lên Firebase
        state = state.copyWith(
          status: SOSStatus.success,
          message: 'SOS đã gửi lên máy chủ thành công',
        );
        print('Network available - SOS sent to Firebase');
        // TODO: Implement Firebase upload
        // await _firebaseService.uploadSOS(sosData);
      } else {
        // Không có mạng -> Kích hoạt SMS Fallback
        state = state.copyWith(
          status: SOSStatus.loading,
          message: 'Không có mạng, gửi SMS khẩn cấp...',
        );
        print('No network - Activating SMS fallback');

        final smsSent = await _smsFallback.activateEmergencyFallback(
          userName: userName,
          phoneNumber: phoneNumber,
          description: description,
        );

        if (smsSent) {
          state = state.copyWith(
            status: SOSStatus.fallbackActivated,
            message: 'SMS khẩn cấp đã gửi thành công',
          );
          print('SMS fallback activated successfully');
        } else {
          state = state.copyWith(
            status: SOSStatus.error,
            errorMessage: 'Gửi SMS thất bại. Vui lòng kiểm tra kết nối.',
          );
          print('SMS fallback failed');
        }
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
  return SOSController();
});
