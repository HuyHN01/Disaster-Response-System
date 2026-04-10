import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EmailOtpAuthException implements Exception {
  final String message;

  const EmailOtpAuthException(this.message);

  @override
  String toString() => message;
}

class EmailOtpAuthRepository {
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  EmailOtpAuthRepository({FirebaseFunctions? functions, FirebaseAuth? auth})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1'),
      _auth = auth ?? FirebaseAuth.instance;

  Future<void> sendOtp({required String email}) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw const EmailOtpAuthException('Vui lòng nhập địa chỉ email.');
    }

    try {
      final callable = _functions.httpsCallable('sendOtp');
      await callable.call(<String, dynamic>{'email': normalizedEmail});
    } on FirebaseFunctionsException catch (e) {
      throw EmailOtpAuthException(_mapCallableError(e));
    } catch (_) {
      throw const EmailOtpAuthException(
        'Không thể gửi mã OTP. Vui lòng thử lại.',
      );
    }
  }

  Future<UserCredential> verifyOtp({
    required String email,
    required String otpCode,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedOtp = otpCode.trim();

    if (normalizedEmail.isEmpty || normalizedOtp.isEmpty) {
      throw const EmailOtpAuthException('Thiếu thông tin email hoặc mã OTP.');
    }

    try {
      final callable = _functions.httpsCallable('verifyOtp');
      final response = await callable.call(<String, dynamic>{
        'email': normalizedEmail,
        'otpCode': normalizedOtp,
      });

      final data = (response.data as Map?)?.cast<String, dynamic>() ?? {};
      final token = (data['customToken'] as String?)?.trim();
      if (token == null || token.isEmpty) {
        throw const EmailOtpAuthException(
          'Không nhận được custom token từ server.',
        );
      }

      return _auth.signInWithCustomToken(token);
    } on FirebaseFunctionsException catch (e) {
      throw EmailOtpAuthException(_mapCallableError(e));
    } on FirebaseAuthException catch (e) {
      throw EmailOtpAuthException(_mapAuthError(e));
    } catch (e) {
      if (e is EmailOtpAuthException) rethrow;
      throw const EmailOtpAuthException(
        'Xác thực OTP thất bại. Vui lòng thử lại.',
      );
    }
  }

  String _mapCallableError(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'invalid-argument':
        return error.message ?? 'Dữ liệu không hợp lệ.';
      case 'deadline-exceeded':
        return error.message ?? 'Mã OTP đã hết hạn. Vui lòng yêu cầu mã mới.';
      case 'resource-exhausted':
        return error.message ??
            'Bạn đã thao tác quá nhanh hoặc vượt giới hạn. Vui lòng thử lại sau.';
      case 'not-found':
        return error.message ?? 'Không tìm thấy mã OTP. Vui lòng gửi lại mã.';
      case 'permission-denied':
        return error.message ?? 'Mã OTP không đúng. Vui lòng kiểm tra lại.';
      case 'failed-precondition':
        return error.message ??
            'Mã OTP không còn hiệu lực. Vui lòng gửi lại mã.';
      case 'unavailable':
        return error.message ??
            'Dịch vụ OTP tạm thời không khả dụng. Vui lòng thử lại sau.';
      default:
        final rawMessage = error.message?.trim();
        if (rawMessage != null && rawMessage.isNotEmpty) {
          return rawMessage;
        }
        return 'Đã có lỗi backend (${error.code}). Vui lòng thử lại.';
    }
  }

  String _mapAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-custom-token':
        return 'Custom token không hợp lệ.';
      case 'custom-token-mismatch':
        return 'Custom token không khớp với dự án Firebase hiện tại.';
      case 'network-request-failed':
        return 'Lỗi mạng. Vui lòng kiểm tra kết nối internet.';
      default:
        return error.message ?? 'Đăng nhập Firebase thất bại.';
    }
  }
}

final emailOtpAuthRepositoryProvider = Provider<EmailOtpAuthRepository>((ref) {
  return EmailOtpAuthRepository(
    functions: FirebaseFunctions.instanceFor(region: 'asia-southeast1'),
    auth: FirebaseAuth.instance,
  );
});
