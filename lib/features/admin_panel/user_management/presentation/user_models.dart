// lib/features/admin_panel/user_management/presentation/user_models.dart
//
// Shared models and design tokens for User Management feature
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

// =============================================================================
// DESIGN TOKENS — kế thừa palette của OmniDisaster Admin
// =============================================================================
class UC {
  // Backgrounds
  static const Color scaffoldBg = Color(0xFFF4F6F9);
  static const Color cardBg = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  // Brand
  static const Color brandRed = Color(0xFFDC2626);
  static const Color brandRedBg = Color(0xFFFEE2E2);

  // Status palette
  static const Color green = Color(0xFF16A34A);
  static const Color greenBg = Color(0xFFDCFCE7);
  static const Color amber = Color(0xFFD97706);
  static const Color amberBg = Color(0xFFFEF3C7);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueBg = Color(0xFFEFF6FF);
  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleBg = Color(0xFFF5F3FF);
  static const Color gray = Color(0xFF6B7280);
  static const Color grayBg = Color(0xFFF3F4F6);
  static const Color red = Color(0xFFDC2626);
  static const Color redBg = Color(0xFFFEE2E2);
  static const Color orange = Color(0xFFEA580C);
  static const Color orangeBg = Color(0xFFFFF7ED);

  // Borders
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);
  static const Color shadow = Color(0x0A000000);

  // Input
  static const Color inputBg = Color(0xFFF9FAFB);
  static const Color focusBorder = Color(0xFFDC2626);
}

// =============================================================================
// ENUMS & MODELS
// =============================================================================

enum UserRole {
  superadmin(0, 'Super Admin', UC.purple, UC.purpleBg, Icons.shield_rounded),
  admin(1, 'Admin', UC.blue, UC.blueBg, Icons.admin_panel_settings_rounded),
  staff(2, 'Nhân viên', UC.amber, UC.amberBg, Icons.badge_rounded),
  user(3, 'Người dùng', UC.gray, UC.grayBg, Icons.person_rounded);

  const UserRole(
      this.value, this.label, this.color, this.bgColor, this.icon);

  final int value;
  final String label;
  final Color color;
  final Color bgColor;
  final IconData icon;

  static UserRole fromValue(int v) =>
      UserRole.values.firstWhere((r) => r.value == v, orElse: () => UserRole.user);
}

enum UserStatus {
  active(1, 'Hoạt động', UC.green, UC.greenBg),
  inactive(0, 'Vô hiệu', UC.gray, UC.grayBg),
  pending(2, 'Chờ duyệt', UC.amber, UC.amberBg),
  banned(3, 'Bị cấm', UC.red, UC.redBg);

  const UserStatus(this.value, this.label, this.color, this.bgColor);

  final int value;
  final String label;
  final Color color;
  final Color bgColor;

  static UserStatus fromValue(int v) =>
      UserStatus.values.firstWhere((s) => s.value == v,
          orElse: () => UserStatus.inactive);
}

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoURL;
  final int role;
  final int status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final DateTime? lastLoginAt;
  final bool mfaEnabled;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoURL,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.lastLoginAt,
    this.mfaEnabled = false,
  });

  AppUser copyWith({
    String? displayName,
    String? photoURL,
    int? role,
    int? status,
    bool? mfaEnabled,
  }) =>
      AppUser(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        photoURL: photoURL ?? this.photoURL,
        role: role ?? this.role,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        createdBy: createdBy,
        lastLoginAt: lastLoginAt,
        mfaEnabled: mfaEnabled ?? this.mfaEnabled,
      );
}
