// lib/features/admin_panel/user_management/presentation/user_management_screen.dart
//
// User Management — OmniDisaster Admin Panel
// Giao diện quản lý người dùng: danh sách, tìm kiếm, lọc, CRUD thật.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:disaster_response_app/core/routes/route_names.dart';

import '../domain/user_management_controller.dart';
import 'user_models.dart';

// =============================================================================
// USER MANAGEMENT SCREEN — Danh sách chính
// =============================================================================
class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  // ── Filter state ────────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  int? _roleFilter; // null = tất cả
  int? _statusFilter; // null = tất cả
  String _searchQuery = '';

  // ── Pagination ──────────────────────────────────────────────────────────────
  int _currentPage = 1;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Computed ─────────────────────────────────────────────────────────────────
  List<AppUser> _filterUsers(List<AppUser> users) {
    return users.where((u) {
      final matchSearch =
          _searchQuery.isEmpty ||
          u.displayName.toLowerCase().contains(_searchQuery) ||
          u.email.toLowerCase().contains(_searchQuery) ||
          u.uid.toLowerCase().contains(_searchQuery);
      final matchRole = _roleFilter == null || u.role == _roleFilter;
      final matchStatus = _statusFilter == null || u.status == _statusFilter;
      return matchSearch && matchRole && matchStatus;
    }).toList();
  }

  int _totalPages(int count) => (count / _pageSize).ceil().clamp(1, 9999);

  List<AppUser> _pagedUsers(List<AppUser> all, int currentPage) {
    final start = (currentPage - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, all.length);
    return all.sublist(start.clamp(0, all.length), end);
  }

  String _errorMessageFrom(Object error) {
    final raw = error.toString().trim();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length).trim();
    }
    return raw.isEmpty ? 'Đã xảy ra lỗi khi tải danh sách người dùng.' : raw;
  }

  // ── Navigation ────────────────────────────────────────────────────────
  void _openDetail(AppUser? user) {
    context.pushNamed(
      RouteNames.nameAdminUserDetail,
      pathParameters: <String, String>{
        RouteNames.paramUserId: user?.uid ?? 'new',
      },
      extra: user,
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(userManagementControllerProvider);
    final allUsers = usersAsync.asData?.value ?? const <AppUser>[];
    final filtered = _filterUsers(allUsers);
    final totalPages = _totalPages(filtered.length);
    final safeCurrentPage = _currentPage.clamp(1, totalPages);
    final paged = _pagedUsers(filtered, safeCurrentPage);
    final isInitialLoading = usersAsync.isLoading && allUsers.isEmpty;
    final loadError = usersAsync.hasError
        ? _errorMessageFrom(usersAsync.error!)
        : null;

    return Scaffold(
      backgroundColor: UC.scaffoldBg,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Page Header ──────────────────────────────────────────────
            _PageHeader(onAddUser: () => _openDetail(null)),
            const SizedBox(height: 24),

            // ── Summary stats ────────────────────────────────────────────
            _SummaryRow(users: allUsers),
            const SizedBox(height: 24),

            // ── Search & Filters ─────────────────────────────────────────
            _SearchFilterBar(
              searchCtrl: _searchCtrl,
              roleFilter: _roleFilter,
              statusFilter: _statusFilter,
              onRoleChanged: (v) => setState(() {
                _roleFilter = v;
                _currentPage = 1;
              }),
              onStatusChanged: (v) => setState(() {
                _statusFilter = v;
                _currentPage = 1;
              }),
              onClearFilters: () => setState(() {
                _searchCtrl.clear();
                _roleFilter = null;
                _statusFilter = null;
                _currentPage = 1;
              }),
            ),
            if (loadError != null && allUsers.isEmpty) ...[
              const SizedBox(height: 10),
              _TableErrorState(message: loadError),
            ],
            const SizedBox(height: 16),

            // ── Table ────────────────────────────────────────────────────
            Expanded(
              child: isInitialLoading
                  ? const _TableLoadingState()
                  : _UsersTable(users: paged, onEdit: _openDetail),
            ),

            // ── Pagination ───────────────────────────────────────────────
            _PaginationBar(
              totalCount: filtered.length,
              currentPage: safeCurrentPage,
              totalPages: totalPages,
              pageSize: _pageSize,
              onPrev: safeCurrentPage > 1
                  ? () => setState(() => _currentPage = safeCurrentPage - 1)
                  : null,
              onNext: safeCurrentPage < totalPages
                  ? () => setState(() => _currentPage = safeCurrentPage + 1)
                  : null,
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
  final VoidCallback onAddUser;
  const _PageHeader({required this.onAddUser});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Quản lý Người Dùng',
              style: TextStyle(
                color: UC.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Quản lý tài khoản, phân quyền và trạng thái người dùng',
              style: TextStyle(color: UC.textSecondary, fontSize: 14),
            ),
          ],
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: onAddUser,
          icon: const Icon(Icons.person_add_rounded, size: 18),
          label: const Text(
            'Thêm Người Dùng',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: UC.brandRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// SUMMARY ROW — 5 stat mini-cards
// =============================================================================
class _SummaryRow extends StatelessWidget {
  final List<AppUser> users;
  const _SummaryRow({required this.users});

  @override
  Widget build(BuildContext context) {
    final totalActive = users.where((u) => u.status == 1).length;
    final totalPending = users.where((u) => u.status == 2).length;
    final totalBanned = users.where((u) => u.status == 3).length;
    final mfaCount = users.where((u) => u.mfaEnabled).length;

    return Row(
      children: [
        _MiniStatCard(
          label: 'Tổng tài khoản',
          value: users.length.toString(),
          icon: Icons.people_rounded,
          color: UC.blue,
          bg: UC.blueBg,
        ),
        const SizedBox(width: 14),
        _MiniStatCard(
          label: 'Đang hoạt động',
          value: totalActive.toString(),
          icon: Icons.check_circle_rounded,
          color: UC.green,
          bg: UC.greenBg,
        ),
        const SizedBox(width: 14),
        _MiniStatCard(
          label: 'Chờ duyệt',
          value: totalPending.toString(),
          icon: Icons.hourglass_empty_rounded,
          color: UC.amber,
          bg: UC.amberBg,
        ),
        const SizedBox(width: 14),
        _MiniStatCard(
          label: 'Bị cấm',
          value: totalBanned.toString(),
          icon: Icons.block_rounded,
          color: UC.red,
          bg: UC.redBg,
        ),
        const SizedBox(width: 14),
        _MiniStatCard(
          label: 'Bật MFA',
          value: mfaCount.toString(),
          icon: Icons.verified_user_rounded,
          color: UC.purple,
          bg: UC.purpleBg,
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bg;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: UC.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: UC.border),
          boxShadow: const [
            BoxShadow(color: UC.shadow, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(
                    color: UC.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SEARCH & FILTER BAR
// =============================================================================
class _SearchFilterBar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final int? roleFilter;
  final int? statusFilter;
  final ValueChanged<int?> onRoleChanged;
  final ValueChanged<int?> onStatusChanged;
  final VoidCallback onClearFilters;

  const _SearchFilterBar({
    required this.searchCtrl,
    required this.roleFilter,
    required this.statusFilter,
    required this.onRoleChanged,
    required this.onStatusChanged,
    required this.onClearFilters,
  });

  bool get _hasActiveFilters =>
      searchCtrl.text.isNotEmpty || roleFilter != null || statusFilter != null;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Search box ────────────────────────────────────────────────────
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 42,
            child: TextField(
              controller: searchCtrl,
              style: const TextStyle(color: UC.textPrimary, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên, email, UID...',
                hintStyle: const TextStyle(color: UC.textMuted, fontSize: 13.5),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: UC.textMuted,
                  size: 20,
                ),
                suffixIcon: searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: UC.textMuted,
                          size: 16,
                        ),
                        onPressed: searchCtrl.clear,
                      )
                    : null,
                filled: true,
                fillColor: UC.cardBg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: UC.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: UC.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: UC.focusBorder,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // ── Role filter ───────────────────────────────────────────────────
        _FilterDropdown<int>(
          hint: 'Vai trò',
          value: roleFilter,
          icon: Icons.manage_accounts_rounded,
          items: UserRole.values
              .map(
                (r) => DropdownMenuItem(value: r.value, child: Text(r.label)),
              )
              .toList(),
          onChanged: onRoleChanged,
        ),
        const SizedBox(width: 10),

        // ── Status filter ─────────────────────────────────────────────────
        _FilterDropdown<int>(
          hint: 'Trạng thái',
          value: statusFilter,
          icon: Icons.toggle_on_rounded,
          items: UserStatus.values
              .map(
                (s) => DropdownMenuItem(value: s.value, child: Text(s.label)),
              )
              .toList(),
          onChanged: onStatusChanged,
        ),
        const SizedBox(width: 10),

        // ── Clear filters ─────────────────────────────────────────────────
        AnimatedOpacity(
          opacity: _hasActiveFilters ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: SizedBox(
            height: 42,
            child: OutlinedButton.icon(
              onPressed: _hasActiveFilters ? onClearFilters : null,
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              label: const Text('Xoá bộ lọc'),
              style: OutlinedButton.styleFrom(
                foregroundColor: UC.textSecondary,
                side: const BorderSide(color: UC.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  final String hint;
  final T? value;
  final IconData icon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _FilterDropdown({
    required this.hint,
    required this.value,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: value != null ? UC.brandRedBg : UC.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value != null ? UC.brandRed.withOpacity(0.4) : UC.border,
          width: value != null ? 1.5 : 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Row(
            children: [
              Icon(icon, size: 15, color: UC.textMuted),
              const SizedBox(width: 6),
              Text(
                hint,
                style: const TextStyle(
                  color: UC.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          items: [
            DropdownMenuItem<T>(
              value: null,
              child: Text(
                'Tất cả $hint',
                style: const TextStyle(color: UC.textSecondary, fontSize: 13),
              ),
            ),
            ...items,
          ],
          onChanged: onChanged,
          isDense: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: value != null ? UC.brandRed : UC.textMuted,
          ),
          style: const TextStyle(
            color: UC.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          dropdownColor: UC.cardBg,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

// =============================================================================
// USERS TABLE
// =============================================================================
class _UsersTable extends StatelessWidget {
  final List<AppUser> users;
  final ValueChanged<AppUser> onEdit;

  const _UsersTable({required this.users, required this.onEdit});

  static final _colWidths = <int, FlexColumnWidth>{
    0: FlexColumnWidth(3.5),
    1: FlexColumnWidth(1.8),
    2: FlexColumnWidth(1.6),
    3: FlexColumnWidth(1.0),
    4: FlexColumnWidth(2.0),
    5: FlexColumnWidth(1.8),
    6: FlexColumnWidth(0.9),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: UC.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: UC.border),
        boxShadow: const [
          BoxShadow(color: UC.shadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            _TableHeaderRow(colWidths: _colWidths),
            const Divider(height: 1, color: UC.border),
            Expanded(
              child: users.isEmpty
                  ? const _EmptyState()
                  : ListView.separated(
                      itemCount: users.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: UC.divider),
                      itemBuilder: (_, i) => _UserRow(
                        user: users[i],
                        colWidths: _colWidths,
                        onEdit: () => onEdit(users[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHeaderRow extends StatelessWidget {
  final Map<int, TableColumnWidth> colWidths;
  const _TableHeaderRow({required this.colWidths});

  @override
  Widget build(BuildContext context) {
    const headers = [
      'Người dùng',
      'Vai trò',
      'Trạng thái',
      'MFA',
      'Đăng nhập gần nhất',
      'Ngày tạo',
      'Thao tác',
    ];

    return Container(
      color: UC.scaffoldBg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: headers
            .asMap()
            .entries
            .map(
              (e) => Expanded(
                flex: _flex(e.key),
                child: Text(
                  e.value,
                  style: const TextStyle(
                    color: UC.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  int _flex(int i) {
    const flexes = [35, 18, 16, 10, 20, 18, 9];
    return flexes[i];
  }
}

class _UserRow extends StatefulWidget {
  final AppUser user;
  final Map<int, TableColumnWidth> colWidths;
  final VoidCallback onEdit;

  const _UserRow({
    required this.user,
    required this.colWidths,
    required this.onEdit,
  });

  @override
  State<_UserRow> createState() => _UserRowState();
}

class _UserRowState extends State<_UserRow> {
  bool _hovered = false;
  static final _dateFmt = DateFormat('dd/MM/yy HH:mm');

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final role = UserRole.fromValue(u.role);
    final status = UserStatus.fromValue(u.status);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _hovered ? const Color(0xFFF9FAFB) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            Expanded(
              flex: 35,
              child: Row(
                children: [
                  _UserAvatar(user: u, role: role),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          u.displayName,
                          style: const TextStyle(
                            color: UC.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          u.email,
                          style: const TextStyle(
                            color: UC.textSecondary,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: u.uid));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã sao chép UID'),
                                duration: Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Text(
                            'UID: ${u.uid.substring(0, 12)}…',
                            style: const TextStyle(
                              color: UC.textMuted,
                              fontSize: 10.5,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(flex: 18, child: _RoleBadge(role: role)),
            Expanded(flex: 16, child: _StatusBadge(status: status)),
            Expanded(flex: 10, child: _MfaBadge(enabled: u.mfaEnabled)),
            Expanded(
              flex: 20,
              child: Text(
                u.lastLoginAt != null
                    ? _dateFmt.format(u.lastLoginAt!.toLocal())
                    : '—',
                style: TextStyle(
                  color: u.lastLoginAt != null
                      ? UC.textSecondary
                      : UC.textMuted,
                  fontSize: 12.5,
                ),
              ),
            ),
            Expanded(
              flex: 18,
              child: Text(
                _dateFmt.format(u.createdAt.toLocal()),
                style: const TextStyle(color: UC.textSecondary, fontSize: 12.5),
              ),
            ),
            Expanded(
              flex: 9,
              child: _RowActionBtn(
                icon: Icons.edit_rounded,
                tooltip: 'Chỉnh sửa',
                onTap: widget.onEdit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SMALL WIDGETS
// =============================================================================

class _UserAvatar extends StatelessWidget {
  final AppUser user;
  final UserRole role;

  const _UserAvatar({required this.user, required this.role});

  String get _initials {
    final parts = user.displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return user.displayName.isNotEmpty
        ? user.displayName[0].toUpperCase()
        : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: role.bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: role.color.withOpacity(0.3), width: 1.5),
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: role.color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final UserRole role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: role.bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(role.icon, size: 12, color: role.color),
          const SizedBox(width: 5),
          Text(
            role.label,
            style: TextStyle(
              color: role.color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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

class _MfaBadge extends StatelessWidget {
  final bool enabled;
  const _MfaBadge({required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: enabled ? 'MFA đã bật' : 'MFA chưa bật',
      child: Container(
        width: 30,
        height: 26,
        decoration: BoxDecoration(
          color: enabled ? UC.purpleBg : UC.grayBg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          enabled ? Icons.verified_user_rounded : Icons.shield_outlined,
          size: 14,
          color: enabled ? UC.purple : UC.textMuted,
        ),
      ),
    );
  }
}

class _RowActionBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RowActionBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_RowActionBtn> createState() => _RowActionBtnState();
}

class _RowActionBtnState extends State<_RowActionBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _hovered ? UC.brandRedBg : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: _hovered
                  ? Border.all(color: UC.brandRed.withOpacity(0.3))
                  : null,
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: _hovered ? UC.brandRed : UC.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PAGINATION BAR
// =============================================================================
class _PaginationBar extends StatelessWidget {
  final int totalCount;
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _PaginationBar({
    required this.totalCount,
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final start = totalCount == 0 ? 0 : ((currentPage - 1) * pageSize + 1).clamp(1, totalCount);
    final end = totalCount == 0 ? 0 : (currentPage * pageSize).clamp(0, totalCount);

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          Text(
            'Hiển thị $start–$end trong tổng số $totalCount người dùng',
            style: const TextStyle(color: UC.textSecondary, fontSize: 12.5),
          ),
          const Spacer(),
          _PageBtn(
            icon: Icons.chevron_left_rounded,
            onTap: onPrev,
            tooltip: 'Trang trước',
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: UC.cardBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: UC.border),
            ),
            child: Text(
              'Trang $currentPage / $totalPages',
              style: const TextStyle(
                color: UC.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _PageBtn(
            icon: Icons.chevron_right_rounded,
            onTap: onNext,
            tooltip: 'Trang sau',
          ),
        ],
      ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;

  const _PageBtn({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: UC.cardBg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: UC.border),
            ),
            child: Icon(
              icon,
              size: 18,
              color: onTap != null ? UC.textPrimary : UC.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _TableLoadingState extends StatelessWidget {
  const _TableLoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: UC.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: UC.border),
        boxShadow: const [
          BoxShadow(color: UC.shadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      ),
    );
  }
}

class _TableErrorState extends StatelessWidget {
  final String message;

  const _TableErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: UC.brandRedBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: UC.brandRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: UC.brandRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: UC.brandRed,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// EMPTY STATE
// =============================================================================
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: UC.grayBg, shape: BoxShape.circle),
            child: const Icon(
              Icons.person_search_rounded,
              color: UC.textMuted,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Không tìm thấy người dùng nào',
            style: TextStyle(
              color: UC.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Thử điều chỉnh từ khoá tìm kiếm hoặc bộ lọc.',
            style: TextStyle(color: UC.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
