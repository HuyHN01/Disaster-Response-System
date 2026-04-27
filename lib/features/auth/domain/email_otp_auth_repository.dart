import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

class EmailOtpAuthException implements Exception {
  final String message;

  const EmailOtpAuthException(this.message);

  @override
  String toString() => message;
}

class EmailOtpAuthRepository {
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;
  bool _isGoogleInitialized = false;

  EmailOtpAuthRepository({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1'),
      _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

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

      final credential = await _auth.signInWithCustomToken(token);
      final user = credential.user;
      if (user == null) {
        throw const EmailOtpAuthException(
          'Không tìm thấy thông tin tài khoản sau khi đăng nhập.',
        );
      }
      await _upsertUserProfile(user);
      return credential;
    } on FirebaseFunctionsException catch (e) {
      throw EmailOtpAuthException(_mapCallableError(e));
    } on FirebaseAuthException catch (e) {
      throw EmailOtpAuthException(_mapAuthError(e));
    } on FirebaseException catch (e) {
      throw EmailOtpAuthException(_mapFirestoreError(e));
    } catch (e) {
      if (e is EmailOtpAuthException) rethrow;
      throw const EmailOtpAuthException(
        'Xác thực OTP thất bại. Vui lòng thử lại.',
      );
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();
      final googleUser = await _googleSignIn.authenticate();
      final idToken = googleUser.authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw const EmailOtpAuthException(
          'Không nhận được ID token từ Google. Vui lòng thử lại.',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        throw const EmailOtpAuthException(
          'Không tìm thấy thông tin tài khoản sau khi đăng nhập Google.',
        );
      }

      await _upsertUserProfile(user);
      return userCredential;
    } on GoogleSignInException catch (e) {
      throw EmailOtpAuthException(_mapGoogleSignInError(e));
    } on FirebaseAuthException catch (e) {
      throw EmailOtpAuthException(_mapAuthError(e));
    } on FirebaseException catch (e) {
      throw EmailOtpAuthException(_mapFirestoreError(e));
    } catch (e) {
      if (e is EmailOtpAuthException) rethrow;
      throw const EmailOtpAuthException(
        'Đăng nhập Google thất bại. Vui lòng thử lại.',
      );
    }
  }

  Future<void> updateCurrentUserAvatar({required String photoUrl}) async {
    final normalizedUrl = photoUrl.trim();
    if (normalizedUrl.isEmpty) {
      throw const EmailOtpAuthException('URL ảnh đại diện không hợp lệ.');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw const EmailOtpAuthException(
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }

    try {
      await _upsertAvatarProfile(user: user, photoUrl: normalizedUrl);

      // Firestore sync is the source of truth for profile rendering.
      // Auth update is best-effort to avoid false failure after successful upload.
      try {
        await user.updatePhotoURL(normalizedUrl);
        await user.reload();
      } catch (_) {
        // Ignore non-critical auth profile sync errors.
      }
    } on FirebaseException catch (e) {
      throw EmailOtpAuthException(_mapFirestoreError(e));
    }
  }

  Future<void> _upsertAvatarProfile({
    required User user,
    required String photoUrl,
  }) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await docRef.get();
    final now = FieldValue.serverTimestamp();

    if (snapshot.exists) {
      await docRef.set({
        'photoUrl': photoUrl,
        'updatedAt': now,
      }, SetOptions(merge: true));
      return;
    }

    final normalizedEmail = (user.email ?? '').trim().toLowerCase();
    final normalizedDisplayName = (user.displayName ?? '').trim();
    var hasMfa = false;
    try {
      final factors = await user.multiFactor.getEnrolledFactors();
      hasMfa = factors.isNotEmpty;
    } catch (_) {
      hasMfa = false;
    }

    final createPayload = <String, dynamic>{
      'uid': user.uid,
      'email': normalizedEmail,
      'displayName': normalizedDisplayName,
      'photoUrl': photoUrl,
      'role': 3,
      'status': 1,
      'createdAt': now,
      'updatedAt': now,
      'createdBy': null,
      'lastLoginAt': now,
      'mfaEnabled': hasMfa,
    };

    await docRef.set(createPayload, SetOptions(merge: true));
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_isGoogleInitialized) return;
    await _googleSignIn.initialize();
    _isGoogleInitialized = true;
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Google session may not exist for OTP users.
    }
    await _auth.signOut();
    _isGoogleInitialized = false;
  }

  Future<void> _upsertUserProfile(User user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await docRef.get();
    final now = FieldValue.serverTimestamp();
    final normalizedEmail = (user.email ?? '').trim().toLowerCase();
    final normalizedDisplayName = (user.displayName ?? '').trim();
    final normalizedPhotoUrl = (user.photoURL ?? '').trim();
    var hasMfa = false;
    try {
      final factors = await user.multiFactor.getEnrolledFactors();
      hasMfa = factors.isNotEmpty;
    } catch (_) {
      hasMfa = false;
    }

    if (!snapshot.exists) {
      // If there is already a profile with this email, keep existing identity
      // data untouched (displayName/photoUrl/role/status).
      if (normalizedEmail.isNotEmpty) {
        final existingByEmail = await _firestore
            .collection('users')
            .where('email', isEqualTo: normalizedEmail)
            .limit(1)
            .get();

        if (existingByEmail.docs.isNotEmpty) {
          return;
        }
      }

      final createPayload = <String, dynamic>{
        'uid': user.uid,
        'email': normalizedEmail,
        'displayName': normalizedDisplayName,
        'photoUrl': normalizedPhotoUrl,
        'role': 3,
        'status': 1,
        'createdAt': now,
        'updatedAt': now,
        'createdBy': null,
        'lastLoginAt': now,
        'mfaEnabled': hasMfa,
      };
      await docRef.set(createPayload, SetOptions(merge: true));
      return;
    }

    final existing = snapshot.data() ?? const <String, dynamic>{};
    final updatePayload = <String, dynamic>{
      'updatedAt': now,
      'lastLoginAt': now,
    };

    // Backfill only when current profile is empty; never overwrite existing
    // values from another provider/account profile.
    final currentDisplayName = ((existing['displayName'] as String?) ?? '')
        .trim();
    final currentPhotoUrl = ((existing['photoUrl'] as String?) ?? '').trim();
    final currentEmail = ((existing['email'] as String?) ?? '').trim();

    if (currentDisplayName.isEmpty && normalizedDisplayName.isNotEmpty) {
      updatePayload['displayName'] = normalizedDisplayName;
    }
    if (currentPhotoUrl.isEmpty && normalizedPhotoUrl.isNotEmpty) {
      updatePayload['photoUrl'] = normalizedPhotoUrl;
    }
    if (currentEmail.isEmpty && normalizedEmail.isNotEmpty) {
      updatePayload['email'] = normalizedEmail;
    }

    await docRef.set(updatePayload, SetOptions(merge: true));
  }

  String _mapCallableError(FirebaseFunctionsException error) {
    final rawMessage = error.message?.trim();

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
        return _mapUnavailableError(rawMessage);
      default:
        if (rawMessage != null && rawMessage.isNotEmpty) {
          return rawMessage;
        }
        return 'Đã có lỗi backend (${error.code}). Vui lòng thử lại.';
    }
  }

  String _mapUnavailableError(String? rawMessage) {
    if (rawMessage == null || rawMessage.isEmpty) {
      return 'Dịch vụ OTP tạm thời không khả dụng. Vui lòng thử lại sau.';
    }

    final statusMatch = RegExp(r'HTTP\s+(\d{3})').firstMatch(rawMessage);
    final statusCode = statusMatch?.group(1);

    switch (statusCode) {
      case '400':
        return 'Mailtrap từ chối yêu cầu gửi mail (HTTP 400). Vui lòng kiểm tra cấu hình sender email/name.';
      case '401':
        return 'Mailtrap xác thực thất bại (HTTP 401). Vui lòng kiểm tra MAILTRAP_API_TOKEN.';
      case '403':
        return 'Mailtrap không cho phép gửi mail (HTTP 403). Kiểm tra quyền API token và sender đã xác minh.';
      case '404':
        return 'Không tìm thấy endpoint Mailtrap (HTTP 404). Vui lòng kiểm tra URL API.';
      case '429':
        return 'Mailtrap đang giới hạn tần suất gửi (HTTP 429). Vui lòng thử lại sau ít phút.';
      case '500':
      case '502':
      case '503':
      case '504':
        return 'Mailtrap đang tạm lỗi máy chủ ($statusCode). Vui lòng thử lại sau.';
      default:
        break;
    }

    if (rawMessage.contains('Mailtrap')) {
      return rawMessage;
    }

    return 'Không thể gửi OTP qua Mailtrap. Vui lòng thử lại.';
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

  String _mapFirestoreError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Không có quyền cập nhật hồ sơ người dùng. Vui lòng liên hệ quản trị viên.';
      case 'unavailable':
        return 'Dịch vụ dữ liệu tạm thời không khả dụng. Vui lòng thử lại.';
      default:
        return error.message ?? 'Không thể đồng bộ hồ sơ người dùng.';
    }
  }

  String _mapGoogleSignInError(GoogleSignInException error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Bạn đã hủy đăng nhập Google.';
      case GoogleSignInExceptionCode.interrupted:
        return 'Đăng nhập Google bị gián đoạn. Vui lòng thử lại.';
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'Cấu hình Google Sign-In chưa đúng. Vui lòng liên hệ quản trị viên.';
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Dịch vụ Google Sign-In chưa sẵn sàng trên thiết bị này.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Không thể mở giao diện đăng nhập Google lúc này.';
      case GoogleSignInExceptionCode.userMismatch:
        return 'Tài khoản Google không khớp phiên đăng nhập hiện tại.';
      case GoogleSignInExceptionCode.unknownError:
        return error.description?.trim().isNotEmpty == true
            ? error.description!.trim()
            : 'Đăng nhập Google thất bại. Vui lòng thử lại.';
    }
  }
}

final emailOtpAuthRepositoryProvider = Provider<EmailOtpAuthRepository>((ref) {
  return EmailOtpAuthRepository(
    functions: FirebaseFunctions.instanceFor(region: 'asia-southeast1'),
    auth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
    googleSignIn: GoogleSignIn.instance,
  );
});
