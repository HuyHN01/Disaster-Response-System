// lib/features/admin_panel/presentation/event_dashboard_screen.dart

import 'package:disaster_response_app/core/database/app_database.dart';
import 'package:disaster_response_app/core/routes/route_names.dart';
import 'package:disaster_response_app/features/admin_panel/domain/admin_sos_controller.dart';
import 'package:disaster_response_app/features/admin_panel/domain/event_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:disaster_response_app/features/admin_panel/presentation/admin_event_detail_screen.dart';

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
/// Dashboard content page. Sidebar and TopBar are provided by AdminLayout
/// (ShellRoute in admin_layout.dart) — this widget renders only the content area.
class EventDashboardScreen extends StatelessWidget {
  const EventDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => const _DashboardContent();
}

// NOTE: AdminSidebar, AdminNavItem, AdminTopBar, and
// showAdminCreateEventDialog have been extracted to admin_layout.dart.

// =============================================================================
// DASHBOARD CONTENT
// =============================================================================
class _DashboardContent extends ConsumerWidget {
  const _DashboardContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEvents = ref.watch(eventControllerProvider);
    // Watch derived provider — only rebuilds this widget when the *count*
    // changes, not on every SOS document field update.
    final sosCountAsync = ref.watch(unverifiedSosCountProvider);

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
            'Lỗi tải sự kiện: $err',
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
              // ── Page title ───────────────────────────────────────────────
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

              // ── Stat Cards Row ───────────────────────────────────────────
              Row(
                children: [
                  // 1. Active events (from Drift via eventControllerProvider)
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

                  // 2. Unverified SOS count (live from Firestore)
                  Expanded(
                    child: _SosStatCard(sosCountAsync: sosCountAsync),
                  ),
                  const SizedBox(width: 16),

                  // 3. Shelters (static for now)
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
              ),

              const SizedBox(height: 28),

              // ── Events Table ─────────────────────────────────────────────
              EventTable(events: events),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// SOS STAT CARD
// Handles loading / error states inline so the rest of the dashboard
// is never blocked by a Firestore hiccup.
// =============================================================================
class _SosStatCard extends StatelessWidget {
  final AsyncValue<int> sosCountAsync;

  const _SosStatCard({required this.sosCountAsync});

  @override
  Widget build(BuildContext context) {
    // Resolve display value + optional pulsing indicator
    final (String displayValue, bool isLoading) = switch (sosCountAsync) {
      AsyncData(:final value) => (value.toString(), false),
      AsyncLoading() => ('—', true),
      AsyncError() => ('!', false),
      _ => ('—', false),
    };

    return StatCard(
      label: 'SOS chưa xử lý',
      value: displayValue,
      icon: Icons.crisis_alert_rounded,
      iconBgColor: AppColors.statIconRedBg,
      iconColor: AppColors.brandRed,
      valueColor: AppColors.brandRed,
      // Pass loading flag so StatCard can show a subtle shimmer if desired.
      isLoading: isLoading,
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
  /// When true, shows a small loading indicator instead of [value].
  final bool isLoading;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.valueColor,
    this.isLoading = false,
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
                isLoading
                    ? SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: valueColor,
                        ),
                      )
                    : Text(
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
                    onTap: () => context.pushNamed(
                      RouteNames.nameAdminEventDetail,
                      pathParameters: {RouteNames.paramEventId: event.id},
                      extra: event,
                    ),
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

// NOTE: showAdminCreateEventDialog has been moved to admin_layout.dart.
