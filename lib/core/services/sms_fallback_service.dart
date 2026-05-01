import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:telephony/telephony.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

/// SmsFallbackService - Dịch vụ gửi SMS tự động khi không có mạng
/// Tính năng này hoạt động như "lưới an toàn" cuối cùng
class SmsFallbackService {
  static const String _emergencyPrefix = 'SOS';
  static const List<String> _emergencyNumbers = ['0343111004'];

  final Connectivity _connectivity = Connectivity();
  final Telephony _telephony = Telephony.instance;

  /// Kiểm tra xem có kết nối mạng hay không
  Future<bool> hasNetworkConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result.contains(ConnectivityResult.mobile) ||
          result.contains(ConnectivityResult.wifi);
    } catch (e) {
      print('Error checking network: $e');
      return false;
    }
  }

  /// Lấy tọa độ GPS hiện tại
  Future<Position?> getCurrentLocation() async {
    try {
      // Kiểm tra quyền vị trí
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are denied forever');
        return null;
      }

      // Lấy vị trí hiện tại
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      return position;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  /// Nén dữ liệu: Thay vì gửi một file JSON dài, hãy tạo một chuỗi ngắn gọn. Ví dụ: SOS|Chau|0912345678|10.762,106.660|CanCapCuu.
  String compressSOSData({
    required String userName,
    required String phoneNumber,
    required double latitude,
    required double longitude,
    required String description,
  }) {
    return '$_emergencyPrefix|$userName|$phoneNumber|$latitude,$longitude|$description';
  }

  /// Gửi SMS tới tất cả các số khẩn cấp (chỉ Android)
  Future<bool> sendEmergencySMS({
    required String userName,
    required String phoneNumber,
    required double latitude,
    required double longitude,
    required String description,
  }) async {
    try {
      // Kiểm tra platform
      if (!Platform.isAndroid) {
        print('SMS fallback is only supported on Android');
        return false;
      }

      // Kiểm tra quyền SMS
      bool? permissionGranted = await _telephony.requestSmsPermissions;
      if (permissionGranted == false) {
        print('SMS permissions not granted');
        return false;
      }

      // Tạo nội dung SMS nén gọn
      final smsContent = compressSOSData(
        userName: userName,
        phoneNumber: phoneNumber,
        latitude: latitude,
        longitude: longitude,
        description: description,
      );

      // Gửi SMS tới tất cả các số khẩn cấp
      bool successCount = true;
      for (String emergencyNumber in _emergencyNumbers) {
        try {
          await _telephony.sendSms(
            to: emergencyNumber,
            message: smsContent,
          );
          print('SMS sent to $emergencyNumber: $smsContent');
        } catch (e) {
          print('Error sending SMS to $emergencyNumber: $e');
          successCount = false;
        }
      }

      return successCount;
    } catch (e) {
      print('Error in sendEmergencySMS: $e');
      return false;
    }
  }

  /// Mở ứng dụng tin nhắn với nội dung điền sẵn (cho iOS)
  Future<bool> openMessagingApp({
    required String userName,
    required String phoneNumber,
    required double latitude,
    required double longitude,
    required String description,
  }) async {
    try {
      final smsContent = compressSOSData(
        userName: userName,
        phoneNumber: phoneNumber,
        latitude: latitude,
        longitude: longitude,
        description: description,
      );

      // URL Scheme cho tin nhắn (hỗ trợ multiple recipients)
      final recipients = _emergencyNumbers.join(',');
      final smsUrl = 'sms:$recipients?body=${Uri.encodeComponent(smsContent)}';

      if (await canLaunchUrl(Uri.parse(smsUrl))) {
        await launchUrl(Uri.parse(smsUrl));
        return true;
      } else {
        print('Cannot launch SMS app');
        return false;
      }
    } catch (e) {
      print('Error opening messaging app: $e');
      return false;
    }
  }

  /// Hàm chính - Kích hoạt SMS Fallback khi không có mạng.
  /// Logic các bước:
  /// 1. Kiểm tra mạng
  /// 2. Sử dụng vị trí đã lấy sẵn từ controller
  /// 3. Gửi SMS (Android) hoặc mở ứng dụng tin nhắn (iOS)
  Future<bool> activateEmergencyFallback({
    required String userName,
    required String phoneNumber,
    required double latitude,
    required double longitude,
    required String description,
  }) async {
    try {
      print('Activating SMS Fallback Service...');

      final hasNetwork = await hasNetworkConnection();
      if (hasNetwork) {
        print('Network is available. SMS fallback not needed.');
        return false;
      }

      if (latitude == 0.0 && longitude == 0.0) {
        print('Invalid location data for SMS fallback.');
        return false;
      }

      // Gửi SMS dựa trên platform
      if (Platform.isAndroid) {
        return await sendEmergencySMS(
          userName: userName,
          phoneNumber: phoneNumber,
          latitude: latitude,
          longitude: longitude,
          description: description,
        );
      } else if (Platform.isIOS) {
        return await openMessagingApp(
          userName: userName,
          phoneNumber: phoneNumber,
          latitude: latitude,
          longitude: longitude,
          description: description,
        );
      }

      return false;
    } catch (e) {
      print('Error in activateEmergencyFallback: $e');
      return false;
    }
  }
}