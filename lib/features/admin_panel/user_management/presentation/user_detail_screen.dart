// lib/features/admin_panel/user_management/presentation/user_detail_screen.dart
//
// User Detail / Edit Screen — Thêm / Sửa người dùng
// Màn hình toàn bộ không có sidebar, dùng GoRouter detail route
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'user_models.dart';

// =============================================================================
// USER DETAIL / EDIT SCREEN
// =============================================================================
class UserDetailScreen extends StatefulWidget {
  /// null = tạo mới; có giá trị = chỉnh sửa
  final AppUser? existingUser;

  const UserDetailScreen({super.key, this.existingUser});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  bool get _isEditing => widget.existingUser != null;

  // ── Form controllers ────────────────────────────────────────────────────────
  late final TextEditingController _displayNameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _photoUrlCtrl;
  late int _selectedRole;
  late int _selectedStatus;
  late bool _mfaEnabled;

  bool _saving = false;
  final _formKey = GlobalKey<FormState>();

  static final _dtFmt = DateFormat('dd/MM/yyyy HH:mm:ss');

  @override
  void initState() {
    super.initState();
    final u = widget.existingUser;
    _displayNameCtrl = TextEditingController(text: u?.displayName ?? '');
    _emailCtrl = TextEditingController(text: u?.email ?? '');
    _photoUrlCtrl = TextEditingController(text: u?.photoUrl ?? '');
    _selectedRole = u?.role ?? 3;
    _selectedStatus = u?.status ?? 1;
    _mfaEnabled = u?.mfaEnabled ?? false;
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _emailCtrl.dispose();
    _photoUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    // TODO: Gọi FirebaseFirestore / Riverpod để lưu user
    await Future.delayed(const Duration(milliseconds: 800)); // giả lập

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing
            ? 'Cập nhật thông tin thành công!'
            : 'Tạo người dùng mới thành công!'),
        backgroundColor: UC.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    Navigator.of(context).pop();
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
                                    fontFamily: 'monospace'),
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
                          helper: _isEditing ? 'Không thể thay đổi email sau khi tạo' : null,
                          child: _StyledTextField(
                            controller: _emailCtrl,
                            hint: 'example@omnidisaster.vn',
                            keyboardType: TextInputType.emailAddress,
                            readOnly: _isEditing,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Vui lòng nhập email';
                              }
                              if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$')
                                  .hasMatch(v.trim())) {
                                return 'Email không hợp lệ';
                              }
                              return null;
                            },
                          ),
                        ),
                        const _FormDivider(),

                        _FormRow(
                          label: 'Ảnh đại diện (URL)',
                          child: _StyledTextField(
                            controller: _photoUrlCtrl,
                            hint: 'https://example.com/avatar.jpg',
                            keyboardType: TextInputType.url,
                          ),
                        ),
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
                            onChanged: (v) =>
                                setState(() => _selectedRole = v ?? 3),
                          ),
                        ),
                        const _FormDivider(),

                        _FormRow(
                          label: 'Trạng thái tài khoản',
                          required: true,
                          child: _StatusDropdown(
                            value: _selectedStatus,
                            onChanged: (v) =>
                                setState(() => _selectedStatus = v ?? 1),
                          ),
                        ),
                        const _FormDivider(),

                        _FormRow(
                          label: 'Xác thực hai lớp (MFA)',
                          helper: 'Người dùng sẽ cần xác minh OTP khi đăng nhập',
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
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
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
                              fontSize: 14.5, fontWeight: FontWeight.w700),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: UC.brandRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
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
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: UserRole.fromValue(u.role).bgColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: UserRole.fromValue(u.role)
                                    .color
                                    .withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                u.displayName.isNotEmpty
                                    ? u.displayName
                                        .trim()
                                        .split(' ')
                                        .where((s) => s.isNotEmpty)
                                        .take(2)
                                        .map((s) => s[0])
                                        .join()
                                        .toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: UserRole.fromValue(u.role).color,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
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
                          Text(u.email,
                              style: const TextStyle(
                                  color: UC.textSecondary, fontSize: 12)),
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
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // TODO: Reset password logic
                        },
                        icon: const Icon(Icons.lock_reset_rounded, size: 15),
                        label: const Text('Đặt lại mật khẩu'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: UC.amber,
                          side: const BorderSide(color: UC.amber),
                          textStyle: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // TODO: Delete user logic
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: 15),
                        label: const Text('Xoá tài khoản'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: UC.brandRed,
                          side: const BorderSide(color: UC.brandRed),
                          textStyle: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
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
                        color: UC.textMuted, fontSize: 11.5, height: 1.4),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
                child: Icon(Icons.lock_outline_rounded,
                    size: 14, color: UC.textMuted),
              )
            : null,
        suffixIconConstraints:
            const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }
}

class _RoleDropdown extends StatelessWidget {
  final int value;
  final ValueChanged<int?> onChanged;
  const _RoleDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final role = UserRole.fromValue(value);
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
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: UC.textSecondary),
          selectedItemBuilder: (_) => UserRole.values
              .map(
                (r) => Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: r.bgColor,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(r.icon, size: 12, color: r.color),
                          const SizedBox(width: 5),
                          Text(r.label,
                              style: TextStyle(
                                color: r.color,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
          items: UserRole.values
              .map(
                (r) => DropdownMenuItem(
                  value: r.value,
                  child: Row(
                    children: [
                      Icon(r.icon, size: 16, color: r.color),
                      const SizedBox(width: 8),
                      Text(r.label,
                          style: TextStyle(
                              color: UC.textPrimary,
                              fontSize: 13,
                              fontWeight: r.value == value
                                  ? FontWeight.w700
                                  : FontWeight.w400)),
                      const Spacer(),
                      Text('Cấp ${r.value}',
                          style: const TextStyle(
                              color: UC.textMuted, fontSize: 11)),
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
  final ValueChanged<int?> onChanged;
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
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: UC.textSecondary),
          selectedItemBuilder: (_) => UserStatus.values
              .map(
                (s) => Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: s.bgColor,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(s.label,
                          style: TextStyle(
                            color: s.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          )),
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
                      Text(s.label,
                          style: TextStyle(
                              color: UC.textPrimary,
                              fontSize: 13,
                              fontWeight: s.value == value
                                  ? FontWeight.w700
                                  : FontWeight.w400)),
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

  const _MetaItem({required this.label, required this.value, this.mono = false});

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
