// lib/features/admin_panel/presentation/admin_account_screen.dart
//
// Màn hình Quản lý tài khoản cá nhân — Admin Panel
//
// Bố cục:
//   AdminLayout (ShellRoute)
//     └── AdminAccountScreen
//           ├── _ProfileCard      — Avatar + Upload, Display Name / Email, Save Profile
//           └── _ChangePasswordCard — Current / New / Confirm password, Update button
//
// Import AppColors từ event_dashboard_screen.dart (hoặc tách ra core/theme nếu cần).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Borrow AppColors from the existing dashboard file ───────────────────────
// If AppColors is already in a shared file (e.g. core/theme/app_colors.dart),
// replace this import with the correct path.
import 'package:disaster_response_app/features/admin_panel/auth/domain/admin_auth_models.dart';
import 'package:disaster_response_app/features/admin_panel/auth/domain/admin_auth_repository.dart';
import 'package:disaster_response_app/features/admin_panel/presentation/event_dashboard_screen.dart'
    show AppColors;

// =============================================================================
// ROOT SCREEN
// =============================================================================
class AdminAccountScreen extends ConsumerWidget {
  const AdminAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(adminSessionProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Page header ─────────────────────────────────────────────────
            _PageHeader(),
            const SizedBox(height: 24),

            // ── Responsive layout: cards stacked on narrow, side-by-side wide ─
            LayoutBuilder(
              builder: (context, constraints) {
                final Widget profileCard = profileAsync.when(
                  data: (profile) => _ProfileCard(profile: profile),
                  loading: () => const _ProfileCardSkeleton(),
                  error: (_, __) => const _ProfileCardError(),
                );

                if (constraints.maxWidth >= 860) {
                  // Wide: profile left (flex 3) + password right (flex 2)
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(flex: 3, child: profileCard),
                      const SizedBox(width: 20),
                      const Flexible(flex: 2, child: _ChangePasswordCard()),
                    ],
                  );
                }
                // Narrow: stack vertically
                return Column(
                  children: [
                    profileCard,
                    const SizedBox(height: 20),
                    const _ChangePasswordCard(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// PAGE HEADER
// =============================================================================
class _PageHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.statIconRedBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.manage_accounts_rounded,
            color: AppColors.brandRed,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Tài khoản cá nhân',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Quản lý thông tin hồ sơ và bảo mật tài khoản',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// PROFILE CARD
// =============================================================================
class _ProfileCard extends StatefulWidget {
  const _ProfileCard({required this.profile});

  final AdminUserProfile? profile;

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  late final TextEditingController _displayNameCtrl;
  late final TextEditingController _emailCtrl;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _displayNameCtrl = TextEditingController(
      text: widget.profile?.displayName ?? '',
    );
    _emailCtrl = TextEditingController(text: widget.profile?.email ?? '');
  }

  @override
  void didUpdateWidget(covariant _ProfileCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newDisplayName = widget.profile?.displayName ?? '';
    if (_displayNameCtrl.text != newDisplayName) {
      _displayNameCtrl.text = newDisplayName;
    }

    final newEmail = widget.profile?.email ?? '';
    if (_emailCtrl.text != newEmail) {
      _emailCtrl.text = newEmail;
    }
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  String get _roleLabel {
    final role = widget.profile?.role;
    if (role == UserRoles.superAdmin) return 'Vai trò: Quản trị viên cấp cao';
    if (role == UserRoles.admin) return 'Vai trò: Quản trị viên';
    return 'Vai trò: Chưa xác định';
  }

  String get _createdAtLabel {
    final createdAt = widget.profile?.createdAt;
    if (createdAt == null) return 'Ngày tạo tài khoản: Chưa cập nhật';
    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    final year = createdAt.year.toString();
    return 'Ngày tạo tài khoản: $day Tháng $month, $year';
  }

  void _onSave() {
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section title ──────────────────────────────────────────────
          _SectionTitle(
            icon: Icons.person_rounded,
            label: 'Hồ sơ cá nhân',
          ),
          const SizedBox(height: 20),

          // ── Avatar + meta ──────────────────────────────────────────────
          Row(
            children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.statIconRedBg,
                      border: Border.all(
                          color: AppColors.border, width: 3),
                    ),
                    child: _Avatar(photoUrl: widget.profile?.photoURL),
                  ),
                  // Camera badge
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.brandRed,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),

              // Meta + Upload button
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => showAvatarUploadDialog(context),
                      icon: const Icon(Icons.upload_rounded,
                          size: 16, color: AppColors.textPrimary),
                      label: const Text(
                        'Tải ảnh lên',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: AppColors.border, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _MetaRow(
                        icon: Icons.shield_outlined,
                        text: _roleLabel),
                    const SizedBox(height: 4),
                    _MetaRow(
                        icon: Icons.calendar_today_outlined,
                        text: _createdAtLabel),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 24),

          // ── Fields: Display Name + Email Address ──────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 520) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _DarkTextField(
                        label: 'Tên hiển thị',
                        controller: _displayNameCtrl,
                        hintText: 'Nhập tên hiển thị',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _DarkTextField(
                        label: 'Địa chỉ Email',
                        controller: _emailCtrl,
                        hintText: 'Chưa có email',
                        readOnly: true,
                        suffixIcon: Tooltip(
                          message: 'Email không thể thay đổi',
                          child: const Icon(
                            Icons.lock_outline_rounded,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _DarkTextField(
                    label: 'Tên hiển thị',
                    controller: _displayNameCtrl,
                    hintText: 'Nhập tên hiển thị',
                  ),
                  const SizedBox(height: 16),
                  _DarkTextField(
                    label: 'Địa chỉ Email',
                    controller: _emailCtrl,
                    hintText: 'Chưa có email',
                    readOnly: true,
                    suffixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // ── Save button ───────────────────────────────────────────────
          SizedBox(
            height: 44,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _saved
                  ? _SuccessButton(key: const ValueKey('success'))
                  : _SaveButton(
                      key: const ValueKey('save'),
                      onTap: _onSave,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.trim().isNotEmpty;

    if (!hasPhoto) {
      return const Icon(
        Icons.person,
        size: 40,
        color: AppColors.brandRed,
      );
    }

    return ClipOval(
      child: Image.network(
        photoUrl!,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return const Icon(
            Icons.person,
            size: 40,
            color: AppColors.brandRed,
          );
        },
      ),
    );
  }
}

class _ProfileCardSkeleton extends StatelessWidget {
  const _ProfileCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const _SectionCard(
      child: SizedBox(
        height: 260,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.brandRed),
        ),
      ),
    );
  }
}

class _ProfileCardError extends StatelessWidget {
  const _ProfileCardError();

  @override
  Widget build(BuildContext context) {
    return const _SectionCard(
      child: SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'Không tải được hồ sơ tài khoản.',
            style: TextStyle(
              color: AppColors.brandRed,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// CHANGE PASSWORD CARD
// =============================================================================
class _ChangePasswordCard extends StatefulWidget {
  const _ChangePasswordCard();

  @override
  State<_ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends State<_ChangePasswordCard> {
  final _currentCtrl = TextEditingController();
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew     = true;
  bool _obscureConfirm = true;
  String? _errorMsg;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _onUpdate() {
    setState(() => _errorMsg = null);
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() => _errorMsg = 'Mật khẩu mới và xác nhận không khớp.');
      return;
    }
    if (_newCtrl.text.length < 8) {
      setState(
          () => _errorMsg = 'Mật khẩu mới phải có ít nhất 8 ký tự.');
      return;
    }
    // TODO: call auth service
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Mật khẩu đã được cập nhật!'),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ),
    );
    _currentCtrl.clear();
    _newCtrl.clear();
    _confirmCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section title ──────────────────────────────────────────────
          _SectionTitle(
            icon: Icons.lock_reset_rounded,
            label: 'Đổi mật khẩu',
          ),
          const SizedBox(height: 20),

          // ── Current password ───────────────────────────────────────────
          _DarkTextField(
            label: 'Mật khẩu hiện tại',
            controller: _currentCtrl,
            hintText: '••••••••••••',
            obscureText: _obscureCurrent,
            suffixIcon: _EyeToggle(
              obscure: _obscureCurrent,
              onToggle: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
            ),
          ),
          const SizedBox(height: 16),

          // ── New + Confirm side-by-side ─────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 400) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _DarkTextField(
                        label: 'Mật khẩu mới',
                        controller: _newCtrl,
                        hintText: '••••••••',
                        obscureText: _obscureNew,
                        suffixIcon: _EyeToggle(
                          obscure: _obscureNew,
                          onToggle: () =>
                              setState(() => _obscureNew = !_obscureNew),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DarkTextField(
                        label: 'Xác nhận mật khẩu mới',
                        controller: _confirmCtrl,
                        hintText: '••••••••',
                        obscureText: _obscureConfirm,
                        suffixIcon: _EyeToggle(
                          obscure: _obscureConfirm,
                          onToggle: () =>
                              setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _DarkTextField(
                    label: 'Mật khẩu mới',
                    controller: _newCtrl,
                    hintText: '••••••••',
                    obscureText: _obscureNew,
                    suffixIcon: _EyeToggle(
                      obscure: _obscureNew,
                      onToggle: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DarkTextField(
                    label: 'Xác nhận mật khẩu mới',
                    controller: _confirmCtrl,
                    hintText: '••••••••',
                    obscureText: _obscureConfirm,
                    suffixIcon: _EyeToggle(
                      obscure: _obscureConfirm,
                      onToggle: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Error message ──────────────────────────────────────────────
          if (_errorMsg != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFFCA5A5), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.brandRed, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMsg!,
                      style: const TextStyle(
                        color: AppColors.brandRed,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── Strength hint ──────────────────────────────────────────────
          if (_newCtrl.text.isNotEmpty) ...[
            _PasswordStrengthBar(password: _newCtrl.text),
            const SizedBox(height: 18),
          ],

          // ── Update button ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _onUpdate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandRed,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'CẬP NHẬT MẬT KHẨU',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SHARED SMALL WIDGETS
// =============================================================================

/// White card container consistent with cardBg across the admin panel.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Section title with a coloured icon pill — mirrors the dashboard stat cards.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.statIconRedBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.brandRed, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Small metadata row (icon + uppercase text) — used in the profile card.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// Reusable text field — styled to match AdminTopBar's search input pattern.
class _DarkTextField extends StatelessWidget {
  const _DarkTextField({
    required this.label,
    this.controller,
    this.hintText,
    this.obscureText = false,
    this.readOnly = false,
    this.keyboardType,
    this.suffixIcon,
    this.onChanged,
  });

  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final bool obscureText;
  final bool readOnly;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          obscureText: obscureText,
          readOnly: readOnly,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: TextStyle(
            color: readOnly
                ? AppColors.textMuted
                : AppColors.textPrimary,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
            ),
            filled: true,
            fillColor:
                readOnly ? AppColors.divider : AppColors.scaffoldBg,
            suffixIcon: suffixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: suffixIcon,
                  )
                : null,
            suffixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(
                  color: AppColors.border, width: 1.2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(
                  color: AppColors.border, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(
                  color: AppColors.brandRed, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Eye toggle icon used inside password fields.
class _EyeToggle extends StatelessWidget {
  const _EyeToggle({required this.obscure, required this.onToggle});
  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Icon(
        obscure
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
        color: AppColors.textMuted,
        size: 18,
      ),
    );
  }
}

/// Animated Save Profile button.
class _SaveButton extends StatelessWidget {
  const _SaveButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.save_rounded, size: 16, color: Colors.white),
      label: const Text(
        'Lưu hồ sơ',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brandRed,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
    );
  }
}

/// Success state after saving profile.
class _SuccessButton extends StatelessWidget {
  const _SuccessButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: null,
      icon: const Icon(Icons.check_circle_rounded,
          size: 16, color: Colors.white),
      label: const Text(
        'Đã lưu!',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF16A34A),
        disabledBackgroundColor: const Color(0xFF16A34A),
        disabledForegroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
    );
  }
}

/// 4-segment password strength bar.
class _PasswordStrengthBar extends StatelessWidget {
  const _PasswordStrengthBar({required this.password});
  final String password;

  int get _strength {
    int s = 0;
    if (password.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(password)) s++;
    if (RegExp(r'[0-9]').hasMatch(password)) s++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) s++;
    return s;
  }

  Color get _color {
    switch (_strength) {
      case 1: return const Color(0xFFEF4444);
      case 2: return const Color(0xFFF97316);
      case 3: return const Color(0xFFEAB308);
      case 4: return const Color(0xFF16A34A);
      default: return AppColors.border;
    }
  }

  String get _label {
    switch (_strength) {
      case 1: return 'Yếu';
      case 2: return 'Trung bình';
      case 3: return 'Khá';
      case 4: return 'Mạnh';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 3 ? 5 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: i < _strength ? _color : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 5),
        Text(
          'Độ mạnh mật khẩu: $_label',
          style: TextStyle(
            color: _color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Hàm hỗ trợ gọi Dialog nhanh từ bất kỳ đâu
Future<void> showAvatarUploadDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: false, // Bắt buộc người dùng nhấn nút Hủy hoặc X (chống click nhầm ra ngoài)
    builder: (BuildContext context) {
      return const AvatarUploadDialog();
    },
  );
}

enum UploadStep { select, crop }
enum UploadMethod { device, url }

class AvatarUploadDialog extends StatefulWidget {
  const AvatarUploadDialog({super.key});

  @override
  State<AvatarUploadDialog> createState() => _AvatarUploadDialogState();
}

class _AvatarUploadDialogState extends State<AvatarUploadDialog> {
  // Trạng thái hiện tại của quy trình
  UploadStep _currentStep = UploadStep.select;
  UploadMethod _method = UploadMethod.device;
  
  final TextEditingController _urlController = TextEditingController();
  bool _isDownloading = false;
  double _zoomValue = 1.0; 

  // --- Bảng màu tinh chỉnh ---
  final Color primaryRed = const Color(0xFFDA291C); // Đỏ cờ chuẩn, nổi bật trên nền trắng
  final Color textDark = const Color(0xFF111827); // Đen xám đậm cho text chính
  final Color textMuted = const Color(0xFF6B7280); // Xám nhạt cho text phụ
  final Color borderGrey = const Color(0xFFE5E7EB); // Viền xám nhạt
  final Color innerBackground = const Color(0xFFF3F4F6); // Nền xám cực nhạt cho tab/box

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  // --- Logic Xử lý ---

  void _onFileSelected() {
    // TODO: Triển khai FilePicker tại đây
    setState(() {
      _method = UploadMethod.device;
      _currentStep = UploadStep.crop;
    });
  }

  void _onUrlSubmitted() async {
    if (_urlController.text.trim().isEmpty) return;

    setState(() => _isDownloading = true);
    
    // TODO: Triển khai logic kiểm tra URL
    await Future.delayed(const Duration(seconds: 1)); // Giả lập delay

    setState(() {
      _isDownloading = false;
      _method = UploadMethod.url;
      _currentStep = UploadStep.crop;
    });
  }

  void _handleFinalConfirm() {
    // TODO: Thực thi logic lưu ảnh
    debugPrint("Đang upload ảnh đã crop lên server...");
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white, // Khóa cứng nền trắng
      surfaceTintColor: Colors.transparent, // Loại bỏ hiệu ứng ám màu của Material 3
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 5,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Padding(
            padding: const EdgeInsets.all(32.0), // Tăng padding để Dialog thoáng hơn
            child: _currentStep == UploadStep.select 
                ? _buildSelectionStep() 
                : _buildCropStep(),
          ),
        ),
      ),
    );
  }

  // --- Giao diện BƯỚC 1: CHỌN NGUỒN ---

  Widget _buildSelectionStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader("Cập nhật ảnh đại diện"),
        const SizedBox(height: 24),
        _buildTabSwitcher(),
        const SizedBox(height: 24),
        if (_method == UploadMethod.device) _buildDevicePicker() else _buildUrlInput(),
        const SizedBox(height: 32),
        _buildFooterButtons(
          onCancel: () => Navigator.of(context).pop(),
          confirmLabel: "Tiếp tục",
          onConfirm: null, 
          showConfirm: false,
        ),
      ],
    );
  }

  // --- Giao diện BƯỚC 2: CROP & PREVIEW ---

  Widget _buildCropStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader("Chỉnh sửa ảnh"),
        const SizedBox(height: 32),
        
        // Khu vực Preview hình tròn
        Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: innerBackground,
            border: Border.all(color: borderGrey, width: 1),
          ),
          child: ClipOval(
            child: Transform.scale(
              scale: _zoomValue,
              // TODO: Thay Placeholder bằng ảnh thật
              child: Image.network(
                _method == UploadMethod.url ? _urlController.text : "https://via.placeholder.com/300",
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, size: 50, color: textMuted),
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        Text("Kéo để điều chỉnh hoặc phóng to/thu nhỏ", style: TextStyle(color: textMuted, fontSize: 13)),
        
        // Thanh trượt Zoom
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: primaryRed,
            inactiveTrackColor: borderGrey,
            thumbColor: primaryRed,
            overlayColor: primaryRed.withOpacity(0.1),
          ),
          child: Slider(
            value: _zoomValue,
            min: 1.0,
            max: 3.0,
            onChanged: (val) => setState(() => _zoomValue = val),
          ),
        ),
        
        const SizedBox(height: 32),
        _buildFooterButtons(
          onCancel: () => setState(() => _currentStep = UploadStep.select),
          confirmLabel: "Xác nhận & Lưu",
          onConfirm: _handleFinalConfirm,
          cancelLabel: "Quay lại",
        ),
      ],
    );
  }

  // --- Các Widget thành phần ---

  Widget _buildHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title, 
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textDark),
        ),
        IconButton(
          icon: Icon(Icons.close, color: textMuted), 
          onPressed: () => Navigator.pop(context),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(), // Thu gọn padding mặc định của icon
        ),
      ],
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: innerBackground, 
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderGrey, width: 0.5), // Thêm viền mờ cho khu vực tab
      ),
      child: Row(
        children: [
          _tabItem("Tải ảnh lên", UploadMethod.device),
          _tabItem("Nhập URL", UploadMethod.url),
        ],
      ),
    );
  }

  Widget _tabItem(String label, UploadMethod method) {
    bool isSelected = _method == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _method = method),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected 
                ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))] 
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label, 
            style: TextStyle(
              color: isSelected ? primaryRed : textMuted, 
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDevicePicker() {
    return InkWell(
      onTap: _onFileSelected,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(48),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: borderGrey, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryRed.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_upload_outlined, size: 32, color: primaryRed),
            ),
            const SizedBox(height: 16),
            Text(
              "Nhấn để chọn file từ máy tính", 
              style: TextStyle(fontWeight: FontWeight.w500, color: textDark, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              "Hỗ trợ JPG, PNG. Tối đa 5MB", 
              style: TextStyle(color: textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Dán link ảnh đại diện", 
          style: TextStyle(fontWeight: FontWeight.w500, color: textDark, fontSize: 14),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _urlController,
          style: TextStyle(color: textDark),
          decoration: InputDecoration(
            hintText: "https://...",
            hintStyle: TextStyle(color: textMuted.withOpacity(0.6)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            suffixIcon: _isDownloading 
              ? const Padding(
                  padding: EdgeInsets.all(14), 
                  child: SizedBox(
                    width: 20, height: 20, 
                    child: CircularProgressIndicator(strokeWidth: 2)
                  ),
                )
              : IconButton(
                  icon: Icon(Icons.arrow_forward_rounded, color: primaryRed),
                  onPressed: _onUrlSubmitted,
                ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderGrey, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: primaryRed, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterButtons({
    required VoidCallback onCancel,
    required String confirmLabel,
    required VoidCallback? onConfirm,
    String cancelLabel = "Hủy",
    bool showConfirm = true,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: onCancel, 
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            foregroundColor: textMuted,
          ),
          child: Text(cancelLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        if (showConfirm) ...[
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryRed,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ]
      ],
    );
  }
}