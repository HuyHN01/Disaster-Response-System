import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/user_models.dart';
import 'user_management_exception.dart';

class UserManagementRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  UserManagementRepository({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
  }) : _firestore = firestore,
       _functions = functions;

  Future<List<AppUser>> fetchUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return _sortUsers(snapshot.docs.map(_mapDoc).toList());
    } on FirebaseException catch (error) {
      throw UserManagementException(_mapFirestoreError(error));
    }
  }

  Stream<List<AppUser>> watchUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      final users = snapshot.docs.map(_mapDoc).toList();
      return _sortUsers(users);
    });
  }

  Future<void> createUser({
    required String email,
    required String displayName,
    required int role,
    required bool mfaEnabled,
    required String password,
    String? loginUrl,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedDisplayName = displayName.trim();
    final normalizedPassword = password.trim();
    final normalizedLoginUrl = _normalizeOptionalString(loginUrl);

    if (normalizedEmail.isEmpty) {
      throw const UserManagementException('Vui lòng nhập email.');
    }
    if (normalizedDisplayName.isEmpty) {
      throw const UserManagementException('Vui lòng nhập tên hiển thị.');
    }
    if (role == 3) {
      throw const UserManagementException(
        'Tài khoản người dùng thường (Role 3) phải tự đăng ký qua OTP hoặc Google.',
      );
    }

    final passwordError = _validateStrongPassword(normalizedPassword);
    if (passwordError != null) {
      throw UserManagementException(passwordError);
    }

    try {
      final callable = _functions.httpsCallable('createManagedUser');
      await callable.call(<String, dynamic>{
        'email': normalizedEmail,
        'displayName': normalizedDisplayName,
        'role': role,
        'password': normalizedPassword,
        'loginUrl': normalizedLoginUrl,
        'mfaEnabled': mfaEnabled,
      });
    } on FirebaseFunctionsException catch (error) {
      throw UserManagementException(_mapCallableError(error));
    } on FirebaseException catch (error) {
      throw UserManagementException(_mapFirestoreError(error));
    }
  }

  Future<void> updateUser({
    required String uid,
    required String email,
    required String displayName,
    required int role,
    required int status,
    required bool mfaEnabled,
  }) async {
    final normalizedUid = uid.trim();
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedDisplayName = displayName.trim();

    if (normalizedUid.isEmpty) {
      throw const UserManagementException('Thiếu UID người dùng cần cập nhật.');
    }
    if (normalizedEmail.isEmpty) {
      throw const UserManagementException('Email người dùng không hợp lệ.');
    }
    if (normalizedDisplayName.isEmpty) {
      throw const UserManagementException('Tên hiển thị không được để trống.');
    }

    try {
      final callable = _functions.httpsCallable('updateManagedUser');
      await callable.call(<String, dynamic>{
        'uid': normalizedUid,
        'email': normalizedEmail,
        'displayName': normalizedDisplayName,
        'role': role,
        'status': status,
        'mfaEnabled': mfaEnabled,
      });
    } on FirebaseFunctionsException catch (error) {
      throw UserManagementException(_mapCallableError(error));
    } on FirebaseException catch (error) {
      throw UserManagementException(_mapFirestoreError(error));
    }
  }

  Future<void> softDeleteUser({required String uid}) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      throw const UserManagementException('Thiếu UID người dùng cần khóa.');
    }

    try {
      final callable = _functions.httpsCallable('softDeleteManagedUser');
      await callable.call(<String, dynamic>{'uid': normalizedUid});
    } on FirebaseFunctionsException catch (error) {
      throw UserManagementException(_mapCallableError(error));
    } on FirebaseException catch (error) {
      throw UserManagementException(_mapFirestoreError(error));
    }
  }

  Future<void> sendPasswordReset({
    required String uid,
    required String email,
  }) async {
    final normalizedUid = uid.trim();
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedUid.isEmpty) {
      throw const UserManagementException(
        'Thiếu UID người dùng cần đặt lại mật khẩu.',
      );
    }
    if (normalizedEmail.isEmpty) {
      throw const UserManagementException('Email người dùng không hợp lệ.');
    }

    try {
      final callable = _functions.httpsCallable('sendManagedPasswordReset');
      await callable.call(<String, dynamic>{
        'uid': normalizedUid,
        'email': normalizedEmail,
      });
    } on FirebaseFunctionsException catch (error) {
      throw UserManagementException(_mapCallableError(error));
    } on FirebaseException catch (error) {
      throw UserManagementException(_mapFirestoreError(error));
    }
  }

  AppUser _mapDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    final createdAt = _asDateTime(data['createdAt']) ?? DateTime.now();
    final updatedAt = _asDateTime(data['updatedAt']) ?? createdAt;

    final uidRaw = (data['uid'] as String?)?.trim();

    return AppUser(
      uid: (uidRaw == null || uidRaw.isEmpty) ? doc.id : uidRaw,
      email: ((data['email'] as String?) ?? '').trim(),
      displayName: ((data['displayName'] as String?) ?? '').trim(),
      photoUrl: _normalizeOptionalString(data['photoUrl'] as String?),
      role: _asInt(data['role'], 3),
      status: _asInt(data['status'], 2),
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: _normalizeOptionalString(data['createdBy'] as String?),
      lastLoginAt: _asDateTime(data['lastLoginAt']),
      mfaEnabled: (data['mfaEnabled'] as bool?) ?? false,
    );
  }

  List<AppUser> _sortUsers(List<AppUser> users) {
    users.sort((a, b) {
      final left = a.updatedAt;
      final right = b.updatedAt;
      return right.compareTo(left);
    });
    return users;
  }

  DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value.trim()) ?? fallback;
    }
    return fallback;
  }

  String? _normalizeOptionalString(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) return null;
    return normalized;
  }

  String? _validateStrongPassword(String password) {
    if (password.isEmpty) {
      return 'Vui lòng nhập mật khẩu cho tài khoản đặc biệt.';
    }
    if (password.length < 10) {
      return 'Mật khẩu phải có ít nhất 10 ký tự.';
    }

    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasDigit = RegExp(r'\d').hasMatch(password);
    final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(password);

    if (!hasUpper || !hasLower || !hasDigit || !hasSpecial) {
      return 'Mật khẩu cần có chữ hoa, chữ thường, số và ký tự đặc biệt.';
    }

    return null;
  }

  String _mapCallableError(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'invalid-argument':
        return error.message ?? 'Dữ liệu gửi lên không hợp lệ.';
      case 'failed-precondition':
        return error.message ?? 'Không thỏa điều kiện để thực hiện thao tác.';
      case 'permission-denied':
        return error.message ?? 'Bạn không có quyền thực hiện thao tác này.';
      case 'unauthenticated':
        return error.message ??
            'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      case 'not-found':
        return error.message ?? 'Không tìm thấy người dùng mục tiêu.';
      case 'already-exists':
        return error.message ?? 'Thông tin đã tồn tại trên hệ thống.';
      case 'unavailable':
        return 'Dịch vụ backend chưa sẵn sàng. Vui lòng thử lại sau.';
      default:
        final raw = error.message?.trim();
        if (raw != null && raw.isNotEmpty) {
          return raw;
        }
        return 'Đã xảy ra lỗi backend (${error.code}).';
    }
  }

  String _mapFirestoreError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Không có quyền truy cập dữ liệu người dùng.';
      case 'unavailable':
        return 'Dịch vụ dữ liệu hiện không khả dụng. Vui lòng thử lại sau.';
      default:
        final raw = error.message?.trim();
        if (raw != null && raw.isNotEmpty) {
          return raw;
        }
        return 'Đã xảy ra lỗi dữ liệu (${error.code}).';
    }
  }
}

final userManagementRepositoryProvider = Provider<UserManagementRepository>((
  ref,
) {
  return UserManagementRepository(
    firestore: FirebaseFirestore.instance,
    functions: FirebaseFunctions.instanceFor(region: 'asia-southeast1'),
  );
});
