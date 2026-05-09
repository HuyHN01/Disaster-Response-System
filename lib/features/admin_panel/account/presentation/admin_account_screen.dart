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

import 'dart:async';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

// ─── Borrow AppColors from the existing dashboard file ───────────────────────
// If AppColors is already in a shared file (e.g. core/theme/app_colors.dart),
// replace this import with the correct path.
import 'package:disaster_response_app/core/services/firebase/firebase_avatar_storage_service.dart';
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
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
class _ProfileCard extends ConsumerStatefulWidget {
  const _ProfileCard({required this.profile});

  final AdminUserProfile? profile;

  @override
  ConsumerState<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends ConsumerState<_ProfileCard> {
  late final TextEditingController _displayNameCtrl;
  late final TextEditingController _emailCtrl;
  bool _isEditingDisplayName = false;
  bool _isSavingProfile = false;
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
    if (!_isEditingDisplayName && _displayNameCtrl.text != newDisplayName) {
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
    if (role == UserRoles.staff) return 'Vai trò: Nhân viên';
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

  bool get _hasDisplayNameChange {
    final currentName = _displayNameCtrl.text.trim();
    final initialName = (widget.profile?.displayName ?? '').trim();
    return currentName.isNotEmpty && currentName != initialName;
  }

  Future<void> _onSave() async {
    if (_isSavingProfile) return;

    if (!_hasDisplayNameChange) {
      setState(() => _saved = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saved = false);
      });
      return;
    }

    setState(() {
      _isSavingProfile = true;
      _saved = false;
    });

    try {
      await ref
          .read(adminAuthRepositoryProvider)
          .updateCurrentAdminDisplayName(displayName: _displayNameCtrl.text);

      if (!mounted) return;
      setState(() {
        _isSavingProfile = false;
        _isEditingDisplayName = false;
        _saved = true;
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saved = false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingProfile = false);
      final message = e is AdminAuthException
          ? e.message
          : 'Không thể cập nhật tên hiển thị. Vui lòng thử lại.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.brandRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void _toggleDisplayNameEditing() {
    if (_isSavingProfile) return;
    setState(() {
      if (_isEditingDisplayName) {
        _displayNameCtrl.text = widget.profile?.displayName ?? '';
        _isEditingDisplayName = false;
      } else {
        _isEditingDisplayName = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section title ──────────────────────────────────────────────
          _SectionTitle(icon: Icons.person_rounded, label: 'Hồ sơ cá nhân'),
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
                      border: Border.all(color: AppColors.border, width: 3),
                    ),
                    child: _Avatar(
                      photoUrl:
                          widget.profile?.photoUrl ??
                          FirebaseAuth.instance.currentUser?.photoURL,
                    ),
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
                        border: Border.all(color: Colors.white, width: 2),
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
                      icon: const Icon(
                        Icons.upload_rounded,
                        size: 16,
                        color: AppColors.textPrimary,
                      ),
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
                          color: AppColors.border,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _MetaRow(icon: Icons.shield_outlined, text: _roleLabel),
                    const SizedBox(height: 4),
                    _MetaRow(
                      icon: Icons.calendar_today_outlined,
                      text: _createdAtLabel,
                    ),
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
                        readOnly: !_isEditingDisplayName || _isSavingProfile,
                        suffixIcon: IconButton(
                          onPressed: _toggleDisplayNameEditing,
                          tooltip: _isEditingDisplayName
                              ? 'Hủy chỉnh sửa'
                              : 'Chỉnh sửa tên hiển thị',
                          icon: Icon(
                            _isEditingDisplayName
                                ? Icons.close_rounded
                                : Icons.edit_rounded,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                        ),
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
                    readOnly: !_isEditingDisplayName || _isSavingProfile,
                    suffixIcon: IconButton(
                      onPressed: _toggleDisplayNameEditing,
                      tooltip: _isEditingDisplayName
                          ? 'Hủy chỉnh sửa'
                          : 'Chỉnh sửa tên hiển thị',
                      icon: Icon(
                        _isEditingDisplayName
                            ? Icons.close_rounded
                            : Icons.edit_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                    ),
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

          // ── Action Buttons: Save + Sign Out ──────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(
                width: 145,
                height: 44,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _saved
                      ? _SuccessButton(key: const ValueKey('success'))
                      : _SaveButton(
                          key: const ValueKey('save'),
                          onTap: _isSavingProfile ? null : _onSave,
                          isLoading: _isSavingProfile,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 145,
                height: 44,
                child: _SignOutButton(
                  onPressed: () {}, // Dummy callback for visual feedback
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Avatar extends ConsumerStatefulWidget {
  const _Avatar({this.photoUrl});

  final String? photoUrl;

  @override
  ConsumerState<_Avatar> createState() => _AvatarState();
}

class _AvatarState extends ConsumerState<_Avatar> {
  late Future<Uint8List?> _avatarBytesFuture;

  @override
  void initState() {
    super.initState();
    _avatarBytesFuture = _loadAvatarBytes(widget.photoUrl);
  }

  @override
  void didUpdateWidget(covariant _Avatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) {
      _avatarBytesFuture = _loadAvatarBytes(widget.photoUrl);
    }
  }

  Future<Uint8List?> _loadAvatarBytes(String? rawUrl) async {
    final normalizedUrl = rawUrl?.trim() ?? '';
    if (normalizedUrl.isEmpty) return null;

    try {
      final downloaded = await ref
          .read(adminAuthRepositoryProvider)
          .fetchAvatarFromUrl(url: normalizedUrl)
          .timeout(const Duration(seconds: 20));
      return downloaded.bytes;
    } catch (error) {
      debugPrint('Avatar bytes fetch failed for URL: $normalizedUrl');
      debugPrint('Avatar bytes fetch error: $error');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedPhotoUrl = widget.photoUrl?.trim() ?? '';
    final hasPhoto = normalizedPhotoUrl.isNotEmpty;

    if (!hasPhoto) {
      return const Icon(Icons.person, size: 40, color: AppColors.brandRed);
    }

    return FutureBuilder<Uint8List?>(
      key: ValueKey(normalizedPhotoUrl),
      future: _avatarBytesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 80,
            height: 80,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return const Icon(
            Icons.broken_image_outlined,
            size: 38,
            color: AppColors.textMuted,
          );
        }

        return ClipOval(
          child: Image.memory(
            bytes,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        );
      },
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
class _ChangePasswordCard extends ConsumerStatefulWidget {
  const _ChangePasswordCard();

  @override
  ConsumerState<_ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends ConsumerState<_ChangePasswordCard> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isUpdating = false;
  String? _errorMsg;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _onUpdate() async {
    if (_isUpdating) return;

    setState(() => _errorMsg = null);

    final currentPassword = _currentCtrl.text;
    final newPassword = _newCtrl.text;
    final confirmPassword = _confirmCtrl.text;

    if (currentPassword.trim().isEmpty) {
      setState(() => _errorMsg = 'Vui lòng nhập mật khẩu hiện tại.');
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() => _errorMsg = 'Mật khẩu mới và xác nhận không khớp.');
      return;
    }
    if (newPassword.length < 8) {
      setState(() => _errorMsg = 'Mật khẩu mới phải có ít nhất 8 ký tự.');
      return;
    }

    setState(() => _isUpdating = true);

    try {
      await ref.read(adminAuthRepositoryProvider).changeCurrentAdminPassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Mật khẩu đã được cập nhật thành công!'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
      setState(() {
        _errorMsg = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e is AdminAuthException
            ? e.message
            : 'Không thể đổi mật khẩu. Vui lòng thử lại.';
      });
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section title ──────────────────────────────────────────────
          _SectionTitle(icon: Icons.lock_reset_rounded, label: 'Đổi mật khẩu'),
          const SizedBox(height: 20),

          // ── Current password ───────────────────────────────────────────
          _DarkTextField(
            label: 'Mật khẩu hiện tại',
            controller: _currentCtrl,
            hintText: '••••••••••••',
            obscureText: _obscureCurrent,
            onChanged: (_) {
              if (_errorMsg != null) setState(() => _errorMsg = null);
            },
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
                        onChanged: (_) {
                          setState(() {
                            if (_errorMsg != null) _errorMsg = null;
                          });
                        },
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
                        onChanged: (_) {
                          if (_errorMsg != null) setState(() => _errorMsg = null);
                        },
                        suffixIcon: _EyeToggle(
                          obscure: _obscureConfirm,
                          onToggle: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
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
                    label: 'Mật khẩu mới',
                    controller: _newCtrl,
                    hintText: '••••••••',
                    obscureText: _obscureNew,
                    onChanged: (_) {
                      setState(() {
                        if (_errorMsg != null) _errorMsg = null;
                      });
                    },
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
                    onChanged: (_) {
                      if (_errorMsg != null) setState(() => _errorMsg = null);
                    },
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.brandRed,
                    size: 16,
                  ),
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
              onPressed: _isUpdating ? null : _onUpdate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandRed,
                disabledBackgroundColor: AppColors.brandRed,
                disabledForegroundColor: Colors.white,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                _isUpdating ? 'ĐANG CẬP NHẬT...' : 'CẬP NHẬT MẬT KHẨU',
                style: const TextStyle(
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
            color: readOnly ? AppColors.textMuted : AppColors.textPrimary,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
            ),
            filled: true,
            fillColor: readOnly ? AppColors.divider : AppColors.scaffoldBg,
            suffixIcon: suffixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: suffixIcon,
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: AppColors.border, width: 1.2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: AppColors.border, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(
                color: AppColors.brandRed,
                width: 1.5,
              ),
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
        obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: AppColors.textMuted,
        size: 18,
      ),
    );
  }
}

/// Animated Save Profile button.
class _SaveButton extends StatelessWidget {
  const _SaveButton({super.key, required this.onTap, this.isLoading = false});

  final Future<void> Function()? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.brandRed,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(),
        borderRadius: BorderRadius.circular(10),
        child: SizedBox.expand(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                const Icon(Icons.save_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                isLoading ? 'Đang lưu...' : 'Lưu hồ sơ',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Success state after saving profile.
class _SuccessButton extends StatelessWidget {
  const _SuccessButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF16A34A),
      borderRadius: BorderRadius.circular(10),
      child: SizedBox.expand(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Đã lưu!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
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
      case 1:
        return const Color(0xFFEF4444);
      case 2:
        return const Color(0xFFF97316);
      case 3:
        return const Color(0xFFEAB308);
      case 4:
        return const Color(0xFF16A34A);
      default:
        return AppColors.border;
    }
  }

  String get _label {
    switch (_strength) {
      case 1:
        return 'Yếu';
      case 2:
        return 'Trung bình';
      case 3:
        return 'Khá';
      case 4:
        return 'Mạnh';
      default:
        return '';
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
    barrierDismissible:
        false, // Bắt buộc người dùng nhấn nút Hủy hoặc X (chống click nhầm ra ngoài)
    builder: (BuildContext context) {
      return const AvatarUploadDialog();
    },
  );
}

enum UploadStep { select, crop }

enum UploadMethod { device, url }

class AvatarUploadDialog extends ConsumerStatefulWidget {
  const AvatarUploadDialog({super.key});

  @override
  ConsumerState<AvatarUploadDialog> createState() => _AvatarUploadDialogState();
}

class _AvatarUploadDialogState extends ConsumerState<AvatarUploadDialog> {
  static const int _maxFileSizeBytes = 5 * 1024 * 1024;
  static const Set<String> _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  final ImagePicker _imagePicker = ImagePicker();
  final CropController _cropController = CropController();
  final TextEditingController _urlController = TextEditingController();

  UploadStep _currentStep = UploadStep.select;
  UploadMethod _method = UploadMethod.device;

  Uint8List? _selectedImageBytes;
  String _selectedContentType = 'image/jpeg';
  bool _isPicking = false;
  bool _isDownloading = false;
  bool _isCropping = false;
  bool _isSaving = false;
  String? _errorMessage;

  // --- Bảng màu tinh chỉnh ---
  final Color primaryRed = const Color(
    0xFFDA291C,
  ); // Đỏ cờ chuẩn, nổi bật trên nền trắng
  final Color textDark = const Color(0xFF111827); // Đen xám đậm cho text chính
  final Color textMuted = const Color(0xFF6B7280); // Xám nhạt cho text phụ
  final Color borderGrey = const Color(0xFFE5E7EB); // Viền xám nhạt
  final Color innerBackground = const Color(
    0xFFF3F4F6,
  ); // Nền xám cực nhạt cho tab/box

  bool get _isBusy => _isPicking || _isDownloading || _isCropping || _isSaving;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  // --- Logic Xử lý ---

  Future<void> _onFileSelected() async {
    if (_isBusy) return;

    setState(() {
      _errorMessage = null;
      _isPicking = true;
    });

    try {
      final selectedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (!mounted || selectedFile == null) {
        return;
      }

      final extension = _extractExtension(selectedFile);
      if (!_allowedExtensions.contains(extension)) {
        throw const AdminAuthException(
          'Định dạng ảnh không hỗ trợ. Vui lòng chọn JPG, JPEG, PNG hoặc WEBP.',
        );
      }

      final bytes = await selectedFile.readAsBytes();
      if (bytes.length > _maxFileSizeBytes) {
        throw const AdminAuthException('Kích thước ảnh vượt quá 5MB.');
      }

      if (!mounted) return;
      setState(() {
        _method = UploadMethod.device;
        _selectedImageBytes = bytes;
        _selectedContentType = _contentTypeFromExtension(extension);
        _currentStep = UploadStep.crop;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _toUserMessage(e));
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  Future<void> _onUrlSubmitted() async {
    if (_isBusy) return;

    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập URL ảnh.';
      });
      return;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      setState(() {
        _errorMessage = 'URL không hợp lệ. Vui lòng dùng link http/https.';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _isDownloading = true;
    });

    try {
      final downloaded = await ref
          .read(adminAuthRepositoryProvider)
          .fetchAvatarFromUrl(url: rawUrl)
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;
      setState(() {
        _method = UploadMethod.url;
        _selectedImageBytes = downloaded.bytes;
        _selectedContentType = downloaded.contentType;
        _currentStep = UploadStep.crop;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Avatar URL download error: $e');
      setState(() => _errorMessage = _toUserMessage(e));
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  String _extractExtension(XFile file) {
    final fileName = file.name.trim().toLowerCase();
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot >= 0 && lastDot < fileName.length - 1) {
      return fileName.substring(lastDot + 1);
    }
    return '';
  }

  String _contentTypeFromExtension(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  String _toUserMessage(Object error) {
    if (error is TimeoutException) {
      return 'Hết thời gian tải ảnh từ URL. Vui lòng thử lại.';
    }
    if (error is AdminAuthException) return error.message;
    return 'Đã có lỗi khi xử lý ảnh. Vui lòng thử lại.';
  }

  Future<void> _handleFinalConfirm() async {
    if (_selectedImageBytes == null || _isBusy) return;
    setState(() {
      _errorMessage = null;
      _isCropping = true;
    });

    _cropController.cropCircle();
  }

  Future<void> _onCropped(CropResult result) async {
    switch (result) {
      case CropSuccess(:final croppedImage):
        await _persistAvatar(croppedImage);
      case CropFailure(:final cause):
        if (!mounted) return;
        setState(() {
          _isCropping = false;
          _errorMessage = 'Không thể cắt ảnh: $cause';
        });
    }
  }

  Future<void> _persistAvatar(Uint8List croppedImage) async {
    if (!mounted) return;

    setState(() {
      _isCropping = false;
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw const AdminAuthException(
          'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        );
      }

      final avatarUrl = await FirebaseAvatarStorageService.uploadAdminAvatar(
        uid: user.uid,
        imageBytes: croppedImage,
        contentType: _selectedContentType,
      );

      await ref
          .read(adminAuthRepositoryProvider)
          .updateCurrentAdminAvatar(photoUrl: avatarUrl);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ảnh đại diện đã được cập nhật.'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _toUserMessage(e));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white, // Khóa cứng nền trắng
      surfaceTintColor:
          Colors.transparent, // Loại bỏ hiệu ứng ám màu của Material 3
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 5,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Padding(
            padding: const EdgeInsets.all(
              32.0,
            ), // Tăng padding để Dialog thoáng hơn
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
        _buildHeader('Cập nhật ảnh đại diện'),
        const SizedBox(height: 24),
        _buildTabSwitcher(),
        const SizedBox(height: 24),
        if (_method == UploadMethod.device)
          _buildDevicePicker()
        else
          _buildUrlInput(),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          _buildErrorBanner(_errorMessage!),
        ],
        const SizedBox(height: 24),
        _buildFooterButtons(
          onCancel: () => Navigator.of(context).pop(),
          confirmLabel: '',
          onConfirm: null,
          showConfirm: false,
        ),
      ],
    );
  }

  // --- Giao diện BƯỚC 2: CROP & PREVIEW ---

  Widget _buildCropStep() {
    final selectedImage = _selectedImageBytes;
    if (selectedImage == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader('Chỉnh sửa ảnh'),
          const SizedBox(height: 24),
          Text(
            'Chưa có ảnh được chọn.',
            style: TextStyle(color: textMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          _buildFooterButtons(
            onCancel: () => setState(() => _currentStep = UploadStep.select),
            confirmLabel: _method == UploadMethod.device
                ? 'Chọn lại ảnh'
                : 'Tải lại từ URL',
            onConfirm: _method == UploadMethod.device
                ? _onFileSelected
                : _onUrlSubmitted,
            cancelLabel: 'Quay lại',
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader('Chỉnh sửa ảnh'),
        const SizedBox(height: 20),
        Container(
          height: 320,
          width: double.infinity,
          decoration: BoxDecoration(
            color: innerBackground,
            border: Border.all(color: borderGrey, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.hardEdge,
          child: Crop(
            image: selectedImage,
            controller: _cropController,
            withCircleUi: true,
            interactive: true,
            fixCropRect: true,
            maskColor: Colors.black.withValues(alpha: 0.45),
            baseColor: innerBackground,
            willUpdateScale: (newScale) => newScale <= 5,
            progressIndicator: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            onCropped: _onCropped,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Kéo ảnh để di chuyển. Dùng lăn chuột hoặc chụm để phóng to/thu nhỏ.',
          style: TextStyle(color: textMuted, fontSize: 13),
        ),
        if (_isCropping || _isSaving) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primaryRed,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _isSaving
                    ? 'Đang tải ảnh và cập nhật hồ sơ...'
                    : 'Đang xử lý ảnh...',
                style: TextStyle(color: textMuted, fontSize: 13),
              ),
            ],
          ),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          _buildErrorBanner(_errorMessage!),
        ],
        const SizedBox(height: 24),
        _buildFooterButtons(
          onCancel: _isBusy
              ? null
              : () => setState(() => _currentStep = UploadStep.select),
          confirmLabel: _isSaving ? 'Đang lưu...' : 'Xác nhận & Lưu',
          onConfirm: _isBusy ? null : _handleFinalConfirm,
          cancelLabel: 'Quay lại',
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
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textDark,
          ),
        ),
        IconButton(
          icon: Icon(Icons.close, color: textMuted),
          onPressed: _isBusy ? null : () => Navigator.pop(context),
          padding: EdgeInsets.zero,
          constraints:
              const BoxConstraints(), // Thu gọn padding mặc định của icon
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.brandRed,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.brandRed, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: innerBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderGrey, width: 0.5),
      ),
      child: Row(
        children: [
          _tabItem('Tải ảnh lên', UploadMethod.device),
          _tabItem('Nhập URL', UploadMethod.url),
        ],
      ),
    );
  }

  Widget _tabItem(String label, UploadMethod method) {
    final isSelected = _method == method;

    return Expanded(
      child: GestureDetector(
        onTap: _isBusy
            ? null
            : () {
                setState(() {
                  _errorMessage = null;
                  _method = method;
                });
              },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : const [],
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
      onTap: _isBusy ? null : _onFileSelected,
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
                color: primaryRed.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: _isPicking
                  ? SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primaryRed,
                      ),
                    )
                  : Icon(
                      Icons.cloud_upload_outlined,
                      size: 32,
                      color: primaryRed,
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              _isPicking
                  ? 'Đang mở thư viện ảnh...'
                  : 'Nhấn để chọn ảnh từ thiết bị',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: textDark,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hỗ trợ JPG, JPEG, PNG, WEBP. Tối đa 5MB',
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
          'Dán link ảnh đại diện',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: textDark,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _urlController,
          enabled: !_isBusy,
          onFieldSubmitted: (_) => _onUrlSubmitted(),
          style: TextStyle(color: textDark),
          decoration: InputDecoration(
            hintText: 'https://...',
            hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.6)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            suffixIcon: _isDownloading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
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
        const SizedBox(height: 8),
        Text(
          'Hỗ trợ JPG, JPEG, PNG, WEBP. Tối đa 5MB',
          style: TextStyle(color: textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildFooterButtons({
    required VoidCallback? onCancel,
    required String confirmLabel,
    required Future<void> Function()? onConfirm,
    String cancelLabel = 'Hủy',
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
          child: Text(
            cancelLabel,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        if (showConfirm) ...[
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onConfirm == null ? null : () => onConfirm(),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryRed,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              confirmLabel,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// SIGN OUT BUTTON
// =============================================================================
class _SignOutButton extends StatelessWidget {
  const _SignOutButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.brandRed.withOpacity(0.4),
              width: 1.5,
            ),
          ),
          child: SizedBox.expand(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.logout_rounded, size: 16, color: AppColors.brandRed),
                SizedBox(width: 8),
                Text(
                  'Đăng xuất',
                  style: TextStyle(
                    color: AppColors.brandRed,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
