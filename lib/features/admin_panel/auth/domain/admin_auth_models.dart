import 'package:cloud_firestore/cloud_firestore.dart';

class UserRoles {
  static const int superAdmin = 0;
  static const int admin = 1;
  static const int staff = 2;
  static const int user = 3;

  static bool isAdminRole(int role) => role == superAdmin || role == admin;
}

class UserStatuses {
  static const int inactive = 0;
  static const int active = 1;
  static const int pending = 2;
  static const int banned = 3;
}

class AdminUserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final int role;
  final int status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final DateTime? lastLoginAt;
  final bool mfaEnabled;

  const AdminUserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.status,
    this.photoUrl,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.lastLoginAt,
    required this.mfaEnabled,
  });

  bool get canAccessAdminPortal {
    return UserRoles.isAdminRole(role) && status == UserStatuses.active;
  }

  factory AdminUserProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final resolvedPhotoUrl =
        _asTrimmedString(data['photoURL']) ??
        _asTrimmedString(data['photoUrl']);

    return AdminUserProfile(
      uid: (data['uid'] as String?) ?? doc.id,
      email: (data['email'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ?? '',
      photoUrl: resolvedPhotoUrl,
      role: _asInt(data['role'], UserRoles.user),
      status: _asInt(data['status'], UserStatuses.pending),
      createdAt: _asDateTime(data['createdAt']),
      updatedAt: _asDateTime(data['updatedAt']),
      createdBy: data['createdBy'] as String?,
      lastLoginAt: _asDateTime(data['lastLoginAt']),
      mfaEnabled: (data['mfaEnabled'] as bool?) ?? false,
    );
  }

  static int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String? _asTrimmedString(dynamic value) {
    if (value is! String) return null;
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    return normalized;
  }
}
