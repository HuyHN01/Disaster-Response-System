// lib/features/admin_panel/presentation/event_dashboard_screen.dart

import 'package:disaster_response_app/core/database/app_database.dart';
import 'package:disaster_response_app/features/admin_panel/domain/event_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// =============================================================================
// MOCK DATA MODEL (mirrors Drift's DisasterEvent data class)
// =============================================================================
class DisasterEventMock {
  final String id;
  final String title;
  final String eventType;
  final String status;
  final DateTime createdAt;
  final String createdBy;

  const DisasterEventMock({
    required this.id,
    required this.title,
    required this.eventType,
    required this.status,
    required this.createdAt,
    required this.createdBy,
  });
}

final List<DisasterEventMock> mockEvents = [
  DisasterEventMock(
    id: '1',
    title: 'Bão số 3 Yagi',
    eventType: 'typhoon',
    status: 'active',
    createdAt: DateTime(2026, 3, 4),
    createdBy: 'admin',
  ),
  DisasterEventMock(
    id: '2',
    title: 'Lũ lụt Trung Du',
    eventType: 'flood',
    status: 'active',
    createdAt: DateTime(2026, 3, 2),
    createdBy: 'admin',
  ),
  DisasterEventMock(
    id: '3',
    title: 'Bão ven biển miền Trung',
    eventType: 'storm',
    status: 'resolved',
    createdAt: DateTime(2026, 2, 28),
    createdBy: 'admin',
  ),
  DisasterEventMock(
    id: '4',
    title: 'Cháy rừng Tây Nguyên',
    eventType: 'wildfire',
    status: 'resolved',
    createdAt: DateTime(2026, 2, 20),
    createdBy: 'admin',
  ),
  DisasterEventMock(
    id: '5',
    title: 'Lũ ống lưu vực sông',
    eventType: 'flood',
    status: 'resolved',
    createdAt: DateTime(2026, 2, 15),
    createdBy: 'admin',
  ),
];

// =============================================================================
// THEME TOKENS — swap these for Dark Mode support later
// =============================================================================
class AppColors {
  // Backgrounds
  static const Color scaffoldBg = Color(0xFFF4F6F9);
  static const Color sidebarBg = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color tableBg = Color(0xFFFFFFFF);
  static const Color tableRowHover = Color(0xFFF9FAFB);

  // Text
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  // Accents
  static const Color brandRed = Color(0xFFDC2626);
  static const Color activeRed = Color(0xFFDC2626);
  static const Color resolvedGreen = Color(0xFF16A34A);
  static const Color activeRedBg = Color(0xFFFEE2E2);
  static const Color resolvedGreenBg = Color(0xFFDCFCE7);

  // Borders & dividers
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);

  // Sidebar selected
  static const Color sidebarSelected = Color(0xFFFEE2E2);
  static const Color sidebarSelectedText = Color(0xFFDC2626);

  // Stat card icon bg
  static const Color statIconRedBg = Color(0xFFFEE2E2);
  static const Color statIconGreenBg = Color(0xFFDCFCE7);
  static const Color statIconOrangeBg = Color(0xFFFEF3C7);
}

// =============================================================================
// MAIN SCREEN
// =============================================================================
class EventDashboardScreen extends StatefulWidget {
  const EventDashboardScreen({super.key});

  @override
  State<EventDashboardScreen> createState() => _EventDashboardScreenState();
}

class _EventDashboardScreenState extends State<EventDashboardScreen> {
  int _selectedNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Row(
        children: [
          // ── Left Navigation Sidebar ──────────────────────────────────────
          _Sidebar(
            selectedIndex: _selectedNavIndex,
            onItemSelected: (i) => setState(() => _selectedNavIndex = i),
          ),
          // ── Main Content Area ────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                _TopBar(),
                Expanded(child: const _DashboardContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SIDEBAR
// =============================================================================
class _Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const _Sidebar({required this.selectedIndex, required this.onItemSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBg,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Brand — height must match _TopBar (60px) so the dividers align
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.brandRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'OmniDisaster',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),

          // Nav Items
          _NavItem(
            icon: Icons.dashboard_rounded,
            label: 'Bảng điều khiển',
            isSelected: selectedIndex == 0,
            onTap: () => onItemSelected(0),
          ),
          _NavItem(
            icon: Icons.map_rounded,
            label: 'Bản đồ sự kiện',
            isSelected: selectedIndex == 1,
            onTap: () => onItemSelected(1),
          ),
          _NavItem(
            icon: Icons.notifications_active_rounded,
            label: 'Cảnh báo SOS',
            isSelected: selectedIndex == 2,
            onTap: () => onItemSelected(2),
          ),
          _NavItem(
            icon: Icons.people_rounded,
            label: 'Người dùng',
            isSelected: selectedIndex == 3,
            onTap: () => onItemSelected(3),
          ),

          const Spacer(),
          const Divider(color: AppColors.border, height: 1),

          // Admin user footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.brandRed,
                  child: const Text(
                    'AD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Quản trị viên',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'admin@omnidisaster.org',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.sidebarSelected : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? AppColors.sidebarSelectedText
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.sidebarSelectedText
                      : AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// TOP BAR
// =============================================================================
class _TopBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBg,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.scaffoldBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm sự kiện, địa điểm, người dùng...',
                  hintStyle: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minHeight: 32,
                    minWidth: 40,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 8,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Bell icon
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {},
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.brandRed,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),

          // New Event Button
          ElevatedButton.icon(
            onPressed: () => _showCreateEventDialog(context, ref),
            icon: const Icon(Icons.add, size: 16, color: Colors.white),
            label: const Text(
              'Sự kiện mới',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandRed,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// DASHBOARD CONTENT
// =============================================================================
class _DashboardContent extends ConsumerWidget {
  const _DashboardContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEvents = ref.watch(eventControllerProvider);

    return asyncEvents.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'Lỗi: $err',
            style: const TextStyle(color: AppColors.brandRed),
          ),
        ),
      ),
      data: (events) {
        final activeCount = events.where((e) => e.status == 'active').length;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page title
              const Text(
                'Bảng điều khiển',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Theo dõi thiên tai và phản ứng khẩn cấp đang hoạt động',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 28),

              // Stat Cards Row
              LayoutBuilder(
                builder: (context, constraints) {
                  return Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          label: 'Sự kiện đang hoạt động',
                          value: activeCount.toString(),
                          icon: Icons.warning_amber_rounded,
                          iconBgColor: AppColors.statIconRedBg,
                          iconColor: AppColors.brandRed,
                          valueColor: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: StatCard(
                          label: 'SOS chưa xử lý',
                          value: '14',
                          icon: Icons.crisis_alert_rounded,
                          iconBgColor: AppColors.statIconRedBg,
                          iconColor: AppColors.brandRed,
                          valueColor: AppColors.brandRed,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: StatCard(
                          label: 'Tổng số nơi trú ẩn',
                          value: '45',
                          icon: Icons.home_rounded,
                          iconBgColor: AppColors.statIconGreenBg,
                          iconColor: AppColors.resolvedGreen,
                          valueColor: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 28),

              // Events Table
              EventTable(events: events),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// STAT CARD WIDGET
// =============================================================================
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final Color valueColor;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
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
                const SizedBox(height: 12),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// EVENT TABLE WIDGET
// =============================================================================
class EventTable extends StatelessWidget {
  final List<DisasterEvent> events;

  const EventTable({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.tableBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: const [
                Text(
                  'Sự kiện gần đây',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: AppColors.border, height: 1),

          // Column Headers
          _TableRow(
            isHeader: true,
            cells: const [
              'Tên sự kiện',
              'Loại',
              'Trạng thái',
              'Ngày tạo',
              'Thao tác',
            ],
            event: null,
          ),

          const Divider(color: AppColors.border, height: 1),

          // Data Rows
          ...events.asMap().entries.map((entry) {
            final idx = entry.key;
            final event = entry.value;
            return Column(
              children: [
                _TableRow(isHeader: false, cells: const [], event: event),
                if (idx < events.length - 1)
                  const Divider(
                    color: AppColors.divider,
                    height: 1,
                    indent: 20,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// =============================================================================
// TABLE ROW WIDGET
// =============================================================================
class _TableRow extends StatefulWidget {
  final bool isHeader;
  final List<String> cells;
  final DisasterEvent? event;

  const _TableRow({
    required this.isHeader,
    required this.cells,
    required this.event,
  });

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _isHovered = false;

  String _localizeEventType(String type) {
    const map = {
      'typhoon': '🌀 Bão',
      'flood': '🌊 Lũ lụt',
      'storm': '⛈️ Dông bão',
      'wildfire': '🔥 Cháy rừng',
      'earthquake': '🪨 Động đất',
      'landslide': '⛰️ Sạt lở',
    };
    return map[type] ?? type;
  }

  String _formatDate(DateTime dt) {
    const months = [
      '',
      'Th1',
      'Th2',
      'Th3',
      'Th4',
      'Th5',
      'Th6',
      'Th7',
      'Th8',
      'Th9',
      'Th10',
      'Th11',
      'Th12',
    ];
    return '${dt.day} ${months[dt.month]}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isHeader) {
      return Container(
        color: AppColors.scaffoldBg,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: widget.cells
              .asMap()
              .entries
              .map((e) => _headerCell(e.value, e.key))
              .toList(),
        ),
      );
    }

    final event = widget.event!;
    final isActive = event.status == 'active';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _isHovered ? AppColors.tableRowHover : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // Event Name
            Expanded(
              flex: 3,
              child: Text(
                event.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Type
            Expanded(
              flex: 2,
              child: Text(
                _localizeEventType(event.eventType),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            // Status
            Expanded(flex: 2, child: _StatusBadge(isActive: isActive)),
            // Date
            Expanded(
              flex: 2,
              child: Text(
                _formatDate(event.createdAt),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            // Actions
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  _ActionButton(
                    icon: Icons.visibility_outlined,
                    tooltip: 'Xem chi tiết',
                    onTap: () {},
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    icon: Icons.edit_outlined,
                    tooltip: 'Chỉnh sửa',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCell(String text, int index) {
    final flexes = [3, 2, 2, 2, 1];
    return Expanded(
      flex: flexes[index],
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// =============================================================================
// STATUS BADGE
// =============================================================================
class _StatusBadge extends StatelessWidget {
  final bool isActive;

  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.activeRedBg : AppColors.resolvedGreenBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? AppColors.activeRed : AppColors.resolvedGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Đang xảy ra' : 'Đã xử lý',
            style: TextStyle(
              color: isActive ? AppColors.activeRed : AppColors.resolvedGreen,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// ACTION BUTTON
// =============================================================================
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _isHovered ? AppColors.scaffoldBg : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: _isHovered ? Border.all(color: AppColors.border) : null,
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: _isHovered
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// DIALOG: TẠO SỰ KIỆN MỚI
// =============================================================================
void _showCreateEventDialog(BuildContext context, WidgetRef ref) {
  final titleController = TextEditingController();
  String selectedType = 'typhoon'; // Giá trị mặc định

  final types = [
    {'value': 'typhoon', 'label': '🌀 Bão'},
    {'value': 'flood', 'label': '🌊 Lũ lụt'},
    {'value': 'storm', 'label': '⛈️ Dông bão'},
    {'value': 'wildfire', 'label': '🔥 Cháy rừng'},
    {'value': 'landslide', 'label': '⛰️ Sạt lở'},
  ];

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.scaffoldBg,
            title: const Text(
              'Tạo sự kiện thiên tai mới',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tên sự kiện',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      hintText: 'VD: Bão số 3 Yagi...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Loại hình',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedType,
                        isExpanded: true,
                        items: types.map((type) {
                          return DropdownMenuItem<String>(
                            value: type['value']!,
                            child: Text(type['label']!),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => selectedType = value);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Hủy',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (titleController.text.trim().isNotEmpty) {
                    // Gọi hàm lưu vào Database thông qua Riverpod
                    ref
                        .read(eventControllerProvider.notifier)
                        .createNewEvent(
                          titleController.text.trim(),
                          selectedType,
                        );
                    Navigator.pop(context); // Đóng Dialog
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Tạo mới'),
              ),
            ],
          );
        },
      );
    },
  );
}
