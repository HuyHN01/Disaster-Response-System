// lib/features/admin_panel/user_management/presentation/user_detail_screen.dart
//
// User Detail / Edit Screen — Thêm / Sửa người dùng
// Màn hình toàn bộ không có sidebar, dùng GoRouter detail route
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';

import 'package:disaster_response_app/features/admin_panel/auth/domain/admin_auth_repository.dart';

import '../domain/user_management_controller.dart';
import '../domain/user_management_exception.dart';
import 'password_generator_dialog.dart';
import 'user_models.dart';

// =============================================================================
// USER DETAIL / EDIT SCREEN
// =============================================================================
class UserDetailScreen extends ConsumerStatefulWidget {
  /// null = tạo mới; có giá trị = chỉnh sửa
  final AppUser? existingUser;

  const UserDetailScreen({super.key, this.existingUser});

  @override
  ConsumerState<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends ConsumerState<UserDetailScreen> {
  bool get _isEditing => widget.existingUser != null;
  bool get _isSpecialCreateRole => !_isEditing && _selectedRole != 3;

  // ── Form controllers ────────────────────────────────────────────────────────
  late final TextEditingController _displayNameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passwordCtrl;
  late int _selectedRole;
  late int _selectedStatus;
  late bool _mfaEnabled;
  bool _obscurePassword = true;

  bool _saving = false;
  bool _resettingPassword = false;
  bool _deletingUser = false;
  final _formKey = GlobalKey<FormState>();

  static final _dtFmt = DateFormat('dd/MM/yyyy HH:mm:ss');

  @override
  void initState() {
    super.initState();
    final u = widget.existingUser;
    _displayNameCtrl = TextEditingController(text: u?.displayName ?? '');
    _emailCtrl = TextEditingController(text: u?.email ?? '');
    _passwordCtrl = TextEditingController();
    _selectedRole = u?.role ?? 2;
    _selectedStatus = u?.status ?? 2;
    _mfaEnabled = u?.mfaEnabled ?? false;
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final controller = ref.read(userManagementControllerProvider.notifier);

      if (_isEditing) {
        final existing = widget.existingUser;
        if (existing == null) {
          throw const UserManagementException(
            'Không tìm thấy người dùng để cập nhật.',
          );
        }

        await controller.updateUser(
          uid: existing.uid,
          email: _emailCtrl.text,
          displayName: _displayNameCtrl.text,
          role: _selectedRole,
          status: _selectedStatus,
          mfaEnabled: _mfaEnabled,
        );
      } else {
        if (_selectedRole == 3) {
          throw const UserManagementException(
            'Role Người dùng thường (3) phải tự đăng ký qua OTP hoặc Google.',
          );
        }

        final passwordError = _validateStrongPassword(_passwordCtrl.text);
        if (passwordError != null) {
          throw UserManagementException(passwordError);
        }

        await controller.createUser(
          email: _emailCtrl.text,
          displayName: _displayNameCtrl.text,
          role: _selectedRole,
          mfaEnabled: _mfaEnabled,
          password: _passwordCtrl.text,
          loginUrl: _resolveAdminLoginUrl(),
        );
      }

      if (!mounted) return;
      _showSnack(
        _isEditing
            ? 'Cập nhật thông tin thành công!'
            : 'Tạo người dùng mới thành công!',
        color: UC.green,
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      _showSnack(_errorMessageFrom(error), color: UC.brandRed);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _resetPassword(AppUser user) async {
    if (_resettingPassword || _saving || _deletingUser) return;

    setState(() => _resettingPassword = true);

    try {
      await ref
          .read(userManagementControllerProvider.notifier)
          .sendPasswordReset(uid: user.uid, email: user.email);

      if (!mounted) return;
      _showSnack(
        'Đã gửi email đặt lại mật khẩu cho ${user.email}.',
        color: UC.green,
      );
    } catch (error) {
      if (!mounted) return;
      _showSnack(_errorMessageFrom(error), color: UC.brandRed);
    } finally {
      if (mounted) {
        setState(() => _resettingPassword = false);
      }
    }
  }

  Future<void> _softDeleteUser(AppUser user) async {
    if (_deletingUser || _saving || _resettingPassword) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xác nhận khoá tài khoản'),
          content: Text(
            'Bạn có chắc muốn khoá tài khoản "${user.displayName}" không?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: UC.brandRed),
              child: const Text('Khoá tài khoản'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _deletingUser = true);

    try {
      await ref
          .read(userManagementControllerProvider.notifier)
          .softDeleteUser(uid: user.uid);

      if (!mounted) return;
      _showSnack('Đã khoá tài khoản thành công.', color: UC.green);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      _showSnack(_errorMessageFrom(error), color: UC.brandRed);
    } finally {
      if (mounted) {
        setState(() => _deletingUser = false);
      }
    }
  }

  String _errorMessageFrom(Object error) {
    if (error is UserManagementException) {
      return error.message;
    }

    final raw = error.toString().trim();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length).trim();
    }
    return raw.isEmpty ? 'Đã xảy ra lỗi. Vui lòng thử lại.' : raw;
  }

  String? _validateStrongPassword(String rawPassword) {
    final password = rawPassword.trim();
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

  String? _resolveAdminLoginUrl() {
    final uri = Uri.base;
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }
    return '${uri.scheme}://${uri.authority}/admin/login';
  }

  Future<void> _openPasswordGenerator() async {
    final generated = await showPasswordGeneratorDialog(context);
    if (generated == null || generated.trim().isEmpty) return;

    setState(() {
      _passwordCtrl.text = generated;
      _obscurePassword = false;
    });
  }

  void _showSnack(String message, {required Color color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.existingUser;

    return Scaffold(
      backgroundColor: UC.scaffoldBg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left panel: form ─────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          style: IconButton.styleFrom(
                            foregroundColor: UC.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEditing
                                  ? 'Chỉnh sửa Người Dùng'
                                  : 'Thêm Người Dùng Mới',
                              style: const TextStyle(
                                color: UC.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (_isEditing && u != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'UID: ${u.uid}',
                                style: const TextStyle(
                                  color: UC.textMuted,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ],
                        ),
                        const Spacer(),
                        if (_isEditing && u != null)
                          _StatusBadge(status: UserStatus.fromValue(u.status)),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // ── SECTION: Thông tin cơ bản ──────────────────────────
                    _SectionHeader(
                      icon: Icons.person_rounded,
                      title: 'Thông tin cơ bản',
                    ),
                    const SizedBox(height: 16),

                    _DetailCard(
                      children: [
                        _FormRow(
                          label: 'Tên hiển thị',
                          required: true,
                          child: _StyledTextField(
                            controller: _displayNameCtrl,
                            hint: 'Nguyễn Văn A',
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Vui lòng nhập tên hiển thị'
                                : null,
                          ),
                        ),
                        const _FormDivider(),

                        _FormRow(
                          label: 'Email',
                          required: !_isEditing,
                          helper: _isEditing
                              ? 'Không thể thay đổi email sau khi tạo'
                              : null,
                          child: _StyledTextField(
                            controller: _emailCtrl,
                            hint: 'example@omnidisaster.vn',
                            keyboardType: TextInputType.emailAddress,
                            readOnly: _isEditing,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Vui lòng nhập email';
                              }
                              if (!RegExp(
                                r'^[\w.-]+@[\w.-]+\.\w+$',
                              ).hasMatch(v.trim())) {
                                return 'Email không hợp lệ';
                              }
                              return null;
                            },
                          ),
                        ),
                        if (_isSpecialCreateRole) ...[
                          const _FormDivider(),
                          _FormRow(
                            label: 'Mật khẩu đăng nhập',
                            required: true,
                            helper:
                                'Bắt buộc cho tài khoản role 0/1/2. Sẽ gửi trong email mời.',
                            child: TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _obscurePassword,
                              validator: (value) =>
                                  _validateStrongPassword(value ?? ''),
                              style: const TextStyle(
                                color: UC.textPrimary,
                                fontSize: 13.5,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Nhập hoặc tạo tự động mật khẩu mạnh',
                                hintStyle: const TextStyle(
                                  color: UC.textMuted,
                                  fontSize: 13.5,
                                ),
                                filled: true,
                                fillColor: UC.inputBg,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(9),
                                  borderSide: const BorderSide(
                                    color: UC.border,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(9),
                                  borderSide: const BorderSide(
                                    color: UC.border,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(9),
                                  borderSide: const BorderSide(
                                    color: UC.focusBorder,
                                    width: 1.5,
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(9),
                                  borderSide: const BorderSide(
                                    color: UC.brandRed,
                                  ),
                                ),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Tạo mật khẩu tự động',
                                      onPressed: _openPasswordGenerator,
                                      icon: const Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 18,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: _obscurePassword
                                          ? 'Hiện mật khẩu'
                                          : 'Ẩn mật khẩu',
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_rounded
                                            : Icons.visibility_rounded,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                suffixIconConstraints: const BoxConstraints(
                                  minHeight: 40,
                                  minWidth: 92,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── SECTION: Quyền & Trạng thái ───────────────────────
                    _SectionHeader(
                      icon: Icons.tune_rounded,
                      title: 'Quyền & Trạng thái',
                    ),
                    const SizedBox(height: 16),

                    _DetailCard(
                      children: [
                        _FormRow(
                          label: 'Vai trò',
                          required: true,
                          helper: 'Xác định quyền truy cập của người dùng',
                          child: _RoleDropdown(
                            value: _selectedRole,
                            includeCitizenRole: _isEditing,
                            onChanged: (v) =>
                                setState(() => _selectedRole = v ?? 2),
                          ),
                        ),
                        const _FormDivider(),

                        _FormRow(
                          label: 'Trạng thái tài khoản',
                          required: true,
                          helper: _isEditing
                              ? null
                              : 'Tài khoản do Super Admin tạo luôn bắt đầu ở trạng thái Chờ duyệt.',
                          child: _StatusDropdown(
                            value: _isEditing ? _selectedStatus : 2,
                            onChanged: _isEditing
                                ? (v) =>
                                      setState(() => _selectedStatus = v ?? 1)
                                : null,
                          ),
                        ),
                        const _FormDivider(),

                        _FormRow(
                          label: 'Xác thực hai lớp (MFA)',
                          helper:
                              'Người dùng sẽ cần xác minh OTP khi đăng nhập',
                          child: Row(
                            children: [
                              Switch(
                                value: _mfaEnabled,
                                onChanged: (v) =>
                                    setState(() => _mfaEnabled = v),
                                activeColor: UC.purple,
                                inactiveThumbColor: UC.textMuted,
                                inactiveTrackColor: UC.grayBg,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _mfaEnabled ? 'Đã bật' : 'Chưa bật',
                                style: TextStyle(
                                  color: _mfaEnabled ? UC.purple : UC.textMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // ── Save button ────────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton.icon(
                        onPressed:
                            (_saving || _resettingPassword || _deletingUser)
                            ? null
                            : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _isEditing
                                    ? Icons.save_rounded
                                    : Icons.person_add_rounded,
                                size: 18,
                              ),
                        label: Text(
                          _isEditing ? 'Lưu thay đổi' : 'Tạo người dùng',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: UC.brandRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Right panel: read-only metadata ─────────────────────────────
          if (_isEditing && u != null)
            Container(
              width: 300,
              decoration: const BoxDecoration(
                color: UC.cardBg,
                border: Border(left: BorderSide(color: UC.border)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 60),
                    _SectionHeader(
                      icon: Icons.info_outline_rounded,
                      title: 'Thông tin hệ thống',
                    ),
                    const SizedBox(height: 16),

                    // Avatar preview
                    Center(
                      child: Column(
                        children: [
                          _SystemUserAvatar(user: u),
                          const SizedBox(height: 10),
                          Text(
                            u.displayName,
                            style: const TextStyle(
                              color: UC.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            u.email,
                            style: const TextStyle(
                              color: UC.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: UC.border),
                    const SizedBox(height: 16),

                    _MetaItem(label: 'UID', value: u.uid, mono: true),
                    _MetaItem(
                      label: 'Ngày tạo',
                      value: _dtFmt.format(u.createdAt.toLocal()),
                    ),
                    _MetaItem(
                      label: 'Cập nhật lần cuối',
                      value: _dtFmt.format(u.updatedAt.toLocal()),
                    ),
                    _MetaItem(
                      label: 'Đăng nhập gần nhất',
                      value: u.lastLoginAt != null
                          ? _dtFmt.format(u.lastLoginAt!.toLocal())
                          : '—',
                    ),
                    _MetaItem(
                      label: 'Tạo bởi',
                      value: u.createdBy ?? '(Tự đăng ký)',
                      mono: u.createdBy != null,
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: UC.border),
                    const SizedBox(height: 16),

                    // Danger zone
                    const Text(
                      'Vùng nguy hiểm',
                      style: TextStyle(
                        color: UC.brandRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (u.role != 3) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              (_resettingPassword || _deletingUser || _saving)
                              ? null
                              : () => _resetPassword(u),
                          icon: const Icon(Icons.lock_reset_rounded, size: 15),
                          label: Text(
                            _resettingPassword
                                ? 'Đang gửi email...'
                                : 'Đặt lại mật khẩu',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: UC.amber,
                            side: const BorderSide(color: UC.amber),
                            textStyle: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            (_deletingUser || _resettingPassword || _saving)
                            ? null
                            : () => _softDeleteUser(u),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 15,
                        ),
                        label: Text(
                          _deletingUser ? 'Đang khoá...' : 'Xoá tài khoản',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: UC.brandRed,
                          side: const BorderSide(color: UC.brandRed),
                          textStyle: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// FORM WIDGETS
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: UC.brandRedBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: UC.brandRed),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: UC.textPrimary,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  final List<Widget> children;
  const _DetailCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: UC.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UC.border),
        boxShadow: const [
          BoxShadow(color: UC.shadow, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _FormRow extends StatelessWidget {
  final String label;
  final bool required;
  final String? helper;
  final Widget child;

  const _FormRow({
    required this.label,
    required this.child,
    this.required = false,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label column
          SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: UC.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (required) ...[
                      const SizedBox(width: 4),
                      const Text(
                        '*',
                        style: TextStyle(color: UC.brandRed, fontSize: 13),
                      ),
                    ],
                  ],
                ),
                if (helper != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    helper!,
                    style: const TextStyle(
                      color: UC.textMuted,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Input column
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _FormDivider extends StatelessWidget {
  const _FormDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: UC.divider, indent: 20, endIndent: 20);
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final bool readOnly;
  final String? Function(String?)? validator;

  const _StyledTextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.readOnly = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      validator: validator,
      style: TextStyle(
        color: readOnly ? UC.textSecondary : UC.textPrimary,
        fontSize: 13.5,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: UC.textMuted, fontSize: 13.5),
        filled: true,
        fillColor: readOnly ? UC.scaffoldBg : UC.inputBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: UC.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: UC.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: UC.focusBorder, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: UC.brandRed),
        ),
        suffixIcon: readOnly
            ? const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: UC.textMuted,
                ),
              )
            : null,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
      ),
    );
  }
}

class _RoleDropdown extends StatelessWidget {
  final int value;
  final bool includeCitizenRole;
  final ValueChanged<int?> onChanged;
  const _RoleDropdown({
    required this.value,
    required this.onChanged,
    this.includeCitizenRole = true,
  });

  @override
  Widget build(BuildContext context) {
    final roles = UserRole.values
        .where((r) => includeCitizenRole || r != UserRole.user)
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: UC.inputBg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: UC.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: UC.textSecondary,
          ),
          selectedItemBuilder: (_) => roles
              .map(
                (r) => Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: r.bgColor,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(r.icon, size: 12, color: r.color),
                          const SizedBox(width: 5),
                          Text(
                            r.label,
                            style: TextStyle(
                              color: r.color,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
          items: roles
              .map(
                (r) => DropdownMenuItem(
                  value: r.value,
                  child: Row(
                    children: [
                      Icon(r.icon, size: 16, color: r.color),
                      const SizedBox(width: 8),
                      Text(
                        r.label,
                        style: TextStyle(
                          color: UC.textPrimary,
                          fontSize: 13,
                          fontWeight: r.value == value
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Cấp ${r.value}',
                        style: const TextStyle(
                          color: UC.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          dropdownColor: UC.cardBg,
          borderRadius: BorderRadius.circular(10),
          style: const TextStyle(color: UC.textPrimary, fontSize: 13.5),
        ),
      ),
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  final int value;
  final ValueChanged<int?>? onChanged;
  const _StatusDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: UC.inputBg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: UC.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: UC.textSecondary,
          ),
          selectedItemBuilder: (_) => UserStatus.values
              .map(
                (s) => Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: s.bgColor,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        s.label,
                        style: TextStyle(
                          color: s.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
          items: UserStatus.values
              .map(
                (s) => DropdownMenuItem(
                  value: s.value,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: s.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        s.label,
                        style: TextStyle(
                          color: UC.textPrimary,
                          fontSize: 13,
                          fontWeight: s.value == value
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          dropdownColor: UC.cardBg,
          borderRadius: BorderRadius.circular(10),
          style: const TextStyle(color: UC.textPrimary, fontSize: 13.5),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final UserStatus status;
  const _StatusBadge({required this.status});

  IconData get _icon => switch (status) {
    UserStatus.active => Icons.check_circle_rounded,
    UserStatus.inactive => Icons.remove_circle_outline_rounded,
    UserStatus.pending => Icons.hourglass_empty_rounded,
    UserStatus.banned => Icons.block_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 12, color: status.color),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: TextStyle(
              color: status.color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const _MetaItem({
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: UC.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: UC.textPrimary,
              fontSize: mono ? 11 : 12.5,
              fontWeight: FontWeight.w500,
              fontFamily: mono ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemUserAvatar extends StatelessWidget {
  final AppUser user;

  const _SystemUserAvatar({required this.user});

  String get _initials {
    final parts = user.displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?';
  }

  bool _isDirectAvatarUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  @override
  Widget build(BuildContext context) {
    final role = UserRole.fromValue(user.role);
    final normalizedPhotoUrl = (user.photoUrl ?? '').trim();
    final hasPhotoUrl = normalizedPhotoUrl.isNotEmpty;

    if (hasPhotoUrl && _isDirectAvatarUrl(normalizedPhotoUrl)) {
      return _SystemAvatarFrame(
        role: role,
        child: Image.network(
          normalizedPhotoUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _SystemFetchedAvatarOrFallback(
            rawUrl: normalizedPhotoUrl,
            role: role,
            initials: _initials,
          ),
        ),
      );
    }

    if (hasPhotoUrl) {
      return _SystemFetchedAvatarOrFallback(
        rawUrl: normalizedPhotoUrl,
        role: role,
        initials: _initials,
      );
    }

    return _SystemDefaultAvatar(role: role, initials: _initials);
  }
}

class _SystemFetchedAvatarOrFallback extends ConsumerStatefulWidget {
  final String rawUrl;
  final UserRole role;
  final String initials;

  const _SystemFetchedAvatarOrFallback({
    required this.rawUrl,
    required this.role,
    required this.initials,
  });

  @override
  ConsumerState<_SystemFetchedAvatarOrFallback> createState() =>
      _SystemFetchedAvatarOrFallbackState();
}

class _SystemFetchedAvatarOrFallbackState
    extends ConsumerState<_SystemFetchedAvatarOrFallback> {
  late Future<Uint8List?> _avatarBytesFuture;

  @override
  void initState() {
    super.initState();
    _avatarBytesFuture = _loadAvatarBytes(widget.rawUrl);
  }

  @override
  void didUpdateWidget(covariant _SystemFetchedAvatarOrFallback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawUrl != widget.rawUrl) {
      _avatarBytesFuture = _loadAvatarBytes(widget.rawUrl);
    }
  }

  Future<Uint8List?> _loadAvatarBytes(String rawUrl) async {
    final normalizedUrl = rawUrl.trim();
    if (normalizedUrl.isEmpty) return null;

    try {
      final downloaded = await ref
          .read(adminAuthRepositoryProvider)
          .fetchAvatarFromUrl(url: normalizedUrl)
          .timeout(const Duration(seconds: 20));
      return downloaded.bytes;
    } catch (error) {
      debugPrint('System avatar bytes fetch failed for URL: $normalizedUrl');
      debugPrint('System avatar bytes fetch error: $error');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SystemAvatarFrame(
      role: widget.role,
      child: FutureBuilder<Uint8List?>(
        key: ValueKey(widget.rawUrl),
        future: _avatarBytesFuture,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null || bytes.isEmpty) {
            return _SystemAvatarInitials(
              initials: widget.initials,
              role: widget.role,
            );
          }

          return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
        },
      ),
    );
  }
}

class _SystemAvatarFrame extends StatelessWidget {
  final UserRole role;
  final Widget child;

  const _SystemAvatarFrame({required this.role, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: role.bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: role.color.withOpacity(0.3), width: 2),
      ),
      clipBehavior: Clip.hardEdge,
      child: child,
    );
  }
}

class _SystemDefaultAvatar extends StatelessWidget {
  final UserRole role;
  final String initials;

  const _SystemDefaultAvatar({required this.role, required this.initials});

  @override
  Widget build(BuildContext context) {
    return _SystemAvatarFrame(
      role: role,
      child: _SystemAvatarInitials(initials: initials, role: role),
    );
  }
}

class _SystemAvatarInitials extends StatelessWidget {
  final String initials;
  final UserRole role;

  const _SystemAvatarInitials({required this.initials, required this.role});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: role.color,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
