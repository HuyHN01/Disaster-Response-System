import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_auth_models.dart';

class AdminAuthException implements Exception {
  final String message;

  const AdminAuthException(this.message);

  @override
  String toString() => message;
}

class AdminAuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  AdminAuthRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    FirebaseFunctions? functions,
  }) : _auth = auth,
       _firestore = firestore,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  CollectionReference<Map<String, dynamic>> get _usersRef {
    return _firestore.collection('users');
  }

  DocumentReference<Map<String, dynamic>> get _bootstrapRef {
    return _firestore.collection('_system').doc('bootstrap_auth');
  }

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<bool> isInitialRegistrationOpen() async {
    try {
      final bootstrapSnap = await _bootstrapRef.get();
      final bootstrapData = bootstrapSnap.data();

      if (bootstrapData == null) {
        return true;
      }

      final initialized = (bootstrapData['initialized'] as bool?) ?? false;
      return !initialized;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return false;
      }
      rethrow;
    }
  }

  Future<AdminUserProfile?> fetchUserProfile(String uid) async {
    final snap = await _usersRef.doc(uid).get();
    if (!snap.exists) return null;
    return AdminUserProfile.fromFirestore(snap);
  }

  Future<AdminUserProfile?> getCurrentAdminProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return fetchUserProfile(user.uid);
  }

  Future<void> registerInitialSuperAdmin({
    required String displayName,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final normalizedDisplayName = displayName.trim();
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedDisplayName.isEmpty) {
      throw const AdminAuthException('Tên hiển thị không được để trống.');
    }
    if (normalizedEmail.isEmpty) {
      throw const AdminAuthException('Email đăng ký không được để trống.');
    }
    if (password.length < 8) {
      throw const AdminAuthException('Mật khẩu phải có ít nhất 8 ký tự.');
    }
    if (password != confirmPassword) {
      throw const AdminAuthException('Mật khẩu xác nhận không khớp.');
    }

    final isOpen = await isInitialRegistrationOpen();
    if (!isOpen) {
      throw const AdminAuthException(
        'Đăng ký quản trị đã đóng. Vui lòng đăng nhập.',
      );
    }

    try {
      final callable = _functions.httpsCallable('registerInitialSuperAdmin');

      await callable.call(<String, dynamic>{
        'displayName': normalizedDisplayName,
        'email': normalizedEmail,
        'password': password,
        'confirmPassword': confirmPassword,
      });

      if (kIsWeb) {
        await _auth.setPersistence(Persistence.LOCAL);
      }

      await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
    } on FirebaseFunctionsException catch (e) {
      throw AdminAuthException(_mapCallableError(e));
    } on FirebaseAuthException catch (e) {
      throw AdminAuthException(_mapAuthError(e));
    } on FirebaseException catch (e) {
      throw AdminAuthException(_mapFirestoreError(e));
    } catch (e) {
      if (e is AdminAuthException) rethrow;
      throw const AdminAuthException('Không thể khởi tạo Super Admin.');
    }
  }

  Future<AdminUserProfile> signInAdmin({
    required String email,
    required String password,
    required bool keepSession,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw const AdminAuthException('Vui lòng nhập đầy đủ email và mật khẩu.');
    }

    try {
      if (kIsWeb) {
        await _auth.setPersistence(
          keepSession ? Persistence.LOCAL : Persistence.SESSION,
        );
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw const AdminAuthException('Không tìm thấy phiên đăng nhập hợp lệ.');
      }

      final profile = await fetchUserProfile(user.uid);
      if (profile == null) {
        await _auth.signOut();
        throw const AdminAuthException(
          'Tài khoản chưa được cấp hồ sơ quyền truy cập admin.',
        );
      }

      if (!profile.canAccessAdminPortal) {
        await _auth.signOut();
        throw const AdminAuthException(
          'Bạn không có quyền truy cập cổng quản trị hoặc tài khoản chưa kích hoạt.',
        );
      }

      await _usersRef.doc(user.uid).set({
        'displayName': user.displayName ?? profile.displayName,
        'photoURL': user.photoURL ?? profile.photoURL,
        'lastLoginAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return profile;
    } on FirebaseAuthException catch (e) {
      throw AdminAuthException(_mapAuthError(e));
    } on FirebaseException catch (e) {
      throw AdminAuthException(_mapFirestoreError(e));
    }
  }

  Future<void> signOut() => _auth.signOut();

  String _mapAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Email không hợp lệ.';
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'Email hoặc mật khẩu không chính xác.';
      case 'email-already-in-use':
        return 'Email này đã được sử dụng.';
      case 'weak-password':
        return 'Mật khẩu quá yếu. Vui lòng dùng mật khẩu mạnh hơn.';
      case 'network-request-failed':
        return 'Không thể kết nối mạng. Vui lòng thử lại.';
      case 'operation-not-allowed':
        return 'Email/Password chưa được bật trong Firebase Auth. Hãy bật Sign-in method Email/Password trong Firebase Console.';
      case 'too-many-requests':
        return 'Bạn thao tác quá nhiều lần. Vui lòng thử lại sau ít phút.';
      default:
        final rawMessage = error.message?.trim();
        final looksGenericError =
            rawMessage != null &&
            (rawMessage.toLowerCase() == 'error' ||
                rawMessage.toLowerCase() == 'an error has occurred');

        if (rawMessage != null && rawMessage.isNotEmpty && !looksGenericError) {
          return rawMessage;
        }
        return 'Đã có lỗi xác thực (${error.code}). Vui lòng thử lại.';
    }
  }

  String _mapFirestoreError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Không có quyền ghi dữ liệu người dùng trên Firestore. Cần cập nhật Firestore Rules.';
      case 'unavailable':
        return 'Dịch vụ Firestore hiện không khả dụng. Vui lòng thử lại sau.';
      default:
        if (error.message != null && error.message!.trim().isNotEmpty) {
          return error.message!;
        }
        return 'Đã có lỗi dữ liệu (${error.code}). Vui lòng thử lại.';
    }
  }

    String _mapCallableError(FirebaseFunctionsException error) {
      switch (error.code) {
        case 'invalid-argument':
          return error.message ?? 'Dữ liệu không hợp lệ.';
        case 'failed-precondition':
          return error.message ?? 'Hệ thống đã có Super Admin. Đăng ký đã bị khóa.';
        case 'already-exists':
          return error.message ?? 'Email này đã được sử dụng.';
        case 'permission-denied':
          return error.message ?? 'Bạn không có quyền thực hiện thao tác này.';
        case 'unauthenticated':
          return error.message ?? 'Phiên làm việc không hợp lệ. Vui lòng đăng nhập lại.';
        case 'unavailable':
          return 'Cloud Functions chưa sẵn sàng hoặc chưa deploy. Vui lòng kiểm tra Firebase Functions và thử lại.';
        case 'not-found':
          return 'Không tìm thấy hàm backend registerInitialSuperAdmin. Hãy deploy Firebase Functions trước.';
        default:
          final rawMessage = error.message?.trim();
          if (rawMessage != null && rawMessage.isNotEmpty) {
            return rawMessage;
          }
          return 'Đã có lỗi backend (${error.code.name}). Vui lòng thử lại.';
      }
    }
}

final adminAuthRepositoryProvider = Provider<AdminAuthRepository>((ref) {
  return AdminAuthRepository(
    auth: FirebaseAuth.instance,
    firestore: FirebaseFirestore.instance,
      functions: FirebaseFunctions.instanceFor(region: 'asia-southeast1'),
  );
});

final adminBootstrapOpenProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(adminAuthRepositoryProvider);
  return repo.isInitialRegistrationOpen();
});

final adminSessionProfileProvider = StreamProvider<AdminUserProfile?>((ref) {
  final repo = ref.watch(adminAuthRepositoryProvider);

  return repo.authStateChanges().asyncMap((user) async {
    if (user == null) return null;
    return repo.fetchUserProfile(user.uid);
  });
});
