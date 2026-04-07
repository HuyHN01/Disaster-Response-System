import 'dart:convert';
import 'dart:typed_data';

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

class DownloadedAvatarData {
  final Uint8List bytes;
  final String contentType;

  const DownloadedAvatarData({required this.bytes, required this.contentType});
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
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-southeast1');

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

  Stream<AdminUserProfile?> watchUserProfile(String uid) {
    return _usersRef.doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return AdminUserProfile.fromFirestore(snap);
    });
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
        throw const AdminAuthException(
          'Không tìm thấy phiên đăng nhập hợp lệ.',
        );
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
        'photoUrl': user.photoURL ?? profile.photoUrl,
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

  Future<void> updateCurrentAdminAvatar({required String photoUrl}) async {
    final normalizedUrl = photoUrl.trim();
    if (normalizedUrl.isEmpty) {
      throw const AdminAuthException('URL ảnh đại diện không hợp lệ.');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw const AdminAuthException(
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }

    final previousPhotoUrl = user.photoURL;

    try {
      await user.updatePhotoURL(normalizedUrl);
      await _usersRef.doc(user.uid).set({
        'photoUrl': normalizedUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      throw AdminAuthException(_mapAuthError(e));
    } on FirebaseException catch (e) {
      try {
        await user.updatePhotoURL(previousPhotoUrl);
      } catch (_) {
        // Keep original error as the source of truth.
      }
      throw AdminAuthException(_mapFirestoreError(e));
    }
  }

  Future<void> updateCurrentAdminDisplayName({
    required String displayName,
  }) async {
    final normalizedDisplayName = displayName.trim();
    if (normalizedDisplayName.isEmpty) {
      throw const AdminAuthException('Tên hiển thị không được để trống.');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw const AdminAuthException(
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }

    final previousDisplayName = user.displayName;

    try {
      await user.updateDisplayName(normalizedDisplayName);
      await _usersRef.doc(user.uid).set({
        'displayName': normalizedDisplayName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      throw AdminAuthException(_mapAuthError(e));
    } on FirebaseException catch (e) {
      try {
        await user.updateDisplayName(previousDisplayName);
      } catch (_) {
        // Keep original error as the source of truth.
      }
      throw AdminAuthException(_mapFirestoreError(e));
    }
  }

  Future<void> changeCurrentAdminPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final normalizedCurrent = currentPassword.trim();
    final normalizedNew = newPassword.trim();

    if (normalizedCurrent.isEmpty) {
      throw const AdminAuthException('Vui lòng nhập mật khẩu hiện tại.');
    }
    if (normalizedNew.isEmpty) {
      throw const AdminAuthException('Vui lòng nhập mật khẩu mới.');
    }
    if (normalizedNew.length < 8) {
      throw const AdminAuthException('Mật khẩu mới phải có ít nhất 8 ký tự.');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw const AdminAuthException(
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }

    final email = (user.email ?? '').trim();
    if (email.isEmpty) {
      throw const AdminAuthException(
        'Không thể xác thực tài khoản hiện tại. Vui lòng đăng nhập lại.',
      );
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: normalizedCurrent,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(normalizedNew);

      await _usersRef.doc(user.uid).set({
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw const AdminAuthException('Mật khẩu hiện tại không chính xác.');
      }
      if (e.code == 'requires-recent-login') {
        throw const AdminAuthException(
          'Phiên xác thực không còn mới. Vui lòng đăng nhập lại rồi thử đổi mật khẩu.',
        );
      }
      throw AdminAuthException(_mapAuthError(e));
    } on FirebaseException catch (e) {
      throw AdminAuthException(_mapFirestoreError(e));
    }
  }

  Future<DownloadedAvatarData> fetchAvatarFromUrl({required String url}) async {
    final normalizedUrl = url.trim();
    if (normalizedUrl.isEmpty) {
      throw const AdminAuthException('Vui lòng nhập URL ảnh.');
    }

    try {
      final callable = _functions.httpsCallable('fetchAvatarFromUrl');
      final result = await callable.call(<String, dynamic>{
        'url': normalizedUrl,
      });

      final data = result.data;
      if (data is! Map) {
        throw const AdminAuthException('Dữ liệu ảnh trả về không hợp lệ.');
      }

      final base64Value = (data['bytesBase64'] as String?)?.trim() ?? '';
      if (base64Value.isEmpty) {
        throw const AdminAuthException(
          'Không nhận được dữ liệu ảnh từ máy chủ.',
        );
      }

      final contentTypeRaw = (data['contentType'] as String?)?.trim() ?? '';
      final contentType = contentTypeRaw.isEmpty
          ? 'image/jpeg'
          : contentTypeRaw;

      final imageBytes = base64Decode(base64Value);
      if (imageBytes.isEmpty) {
        throw const AdminAuthException('Dữ liệu ảnh từ máy chủ đang rỗng.');
      }

      return DownloadedAvatarData(bytes: imageBytes, contentType: contentType);
    } on FirebaseFunctionsException catch (e) {
      throw AdminAuthException(_mapCallableError(e));
    } on FormatException {
      throw const AdminAuthException(
        'Không thể giải mã dữ liệu ảnh từ máy chủ.',
      );
    } catch (e) {
      if (e is AdminAuthException) rethrow;
      throw const AdminAuthException(
        'Không thể tải ảnh từ URL. Vui lòng thử lại.',
      );
    }
  }

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
        return error.message ?? 'Không thỏa điều kiện để thực thi thao tác.';
      case 'already-exists':
        return error.message ?? 'Email này đã được sử dụng.';
      case 'permission-denied':
        return error.message ?? 'Bạn không có quyền thực hiện thao tác này.';
      case 'unauthenticated':
        return error.message ??
            'Phiên làm việc không hợp lệ. Vui lòng đăng nhập lại.';
      case 'deadline-exceeded':
        return error.message ??
            'Yêu cầu xử lý quá thời gian. Vui lòng thử lại.';
      case 'unavailable':
        return 'Cloud Functions chưa sẵn sàng hoặc chưa deploy. Vui lòng kiểm tra Firebase Functions và thử lại.';
      case 'not-found':
        return 'Không tìm thấy hàm backend cần thiết. Hãy deploy Firebase Functions trước.';
      default:
        final rawMessage = error.message?.trim();
        if (rawMessage != null && rawMessage.isNotEmpty) {
          return rawMessage;
        }
        return 'Đã có lỗi backend (${error.code}). Vui lòng thử lại.';
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

  return repo.authStateChanges().asyncExpand((user) {
    if (user == null) return Stream.value(null);
    return repo.watchUserProfile(user.uid);
  });
});
