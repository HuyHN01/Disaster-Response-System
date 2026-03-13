// lib/features/admin_panel/presentation/admin_layout.dart
//
// ShellRoute layout for the Admin panel.
//
// Provides the Sidebar + TopBar shell that wraps every admin page.
// Individual admin screens (EventDashboardScreen, AdminMapScreen) are injected
// as [child] by GoRouter — they have no sidebar knowledge of their own.
//
// Architecture:
//   ShellRoute
//     └── AdminLayout (this file)
//           ├── AdminSidebar   — animated collapsible nav rail
//           └── Column
//                 ├── AdminTopBar   — search bar + notifications + "Sự kiện mới"
//                 └── child         — injected by GoRouter ShellRoute

import 'package:disaster_response_app/core/routes/route_names.dart';
import 'package:disaster_response_app/features/admin_panel/domain/event_controller.dart';
import 'package:disaster_response_app/features/admin_panel/presentation/event_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ── Sidebar animation constants ───────────────────────────────────────────────
const Duration kAdminSidebarDuration = Duration(milliseconds: 220);
const Curve kAdminSidebarCurve = Curves.easeInOut;
const double kAdminSidebarExpanded = 240;
const double kAdminSidebarCollapsed = 72;

// ── Nav destination model ─────────────────────────────────────────────────────
class _AdminNavDestination {
  final IconData icon;
  final String label;
  final String route;
  final bool enabled;

  const _AdminNavDestination({
    required this.icon,
    required this.label,
    required this.route,
    this.enabled = true,
  });
}

// ── Nav destinations list ─────────────────────────────────────────────────────
const List<_AdminNavDestination> _kNavDestinations = [
  _AdminNavDestination(
    icon: Icons.dashboard_rounded,
    label: 'Bảng điều khiển',
    route: RouteNames.adminDashboard,
  ),
  _AdminNavDestination(
    icon: Icons.map_rounded,
    label: 'Bản đồ sự kiện',
    route: RouteNames.adminMap,
  ),
  _AdminNavDestination(
    icon: Icons.notifications_active_rounded,
    label: 'Cảnh báo SOS',
    route: RouteNames.adminDashboard, // placeholder — future route
    enabled: false,
  ),
  _AdminNavDestination(
    icon: Icons.people_rounded,
    label: 'Người dùng',
    route: RouteNames.adminDashboard, // placeholder — future route
    enabled: false,
  ),
];

// =============================================================================
// ADMIN LAYOUT — ShellRoute builder widget
// =============================================================================
class AdminLayout extends StatefulWidget {
  /// The currently active child page provided by GoRouter.
  final Widget child;

  const AdminLayout({super.key, required this.child});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  /// false = sidebar expanded (240 px), true = sidebar collapsed (72 px)
  bool _isSidebarCollapsed = false;

  /// Derives the selected nav index from the current GoRouter location.
  int _selectedIndex(String location) {
    if (location.startsWith(RouteNames.adminMap)) return 1;
    // Future branches: add cases here as new admin routes are registered.
    return 0; // default: dashboard
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final selectedIdx = _selectedIndex(location);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: Row(
        children: [
          // ── Left Navigation Sidebar ──────────────────────────────────
          AdminSidebar(
            selectedIndex: selectedIdx,
            isCollapsed: _isSidebarCollapsed,
            onItemSelected: (i) {
              final dest = _kNavDestinations[i];
              if (dest.enabled) context.go(dest.route);
            },
            onToggleCollapse: () =>
                setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
          ),

          // ── Main Content Area ─────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                const AdminTopBar(),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// ADMIN SIDEBAR
// =============================================================================
class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final bool isCollapsed;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onToggleCollapse;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.isCollapsed,
    required this.onItemSelected,
    required this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: kAdminSidebarDuration,
      curve: kAdminSidebarCurve,
      width: isCollapsed ? kAdminSidebarCollapsed : kAdminSidebarExpanded,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBg,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: ClipRect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Brand Header ──────────────────────────────────────────
            SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: isCollapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  SizedBox(width: isCollapsed ? 0 : 20),
                  // Brand icon
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
                  // App name — slides in/out with sidebar
                  AnimatedSize(
                    duration: kAdminSidebarDuration,
                    curve: kAdminSidebarCurve,
                    child: isCollapsed
                        ? const SizedBox.shrink()
                        : const Padding(
                            padding: EdgeInsets.only(left: 10),
                            child: Text(
                              'OmniDisaster',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),

            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),

            // ── 2. Nav items ─────────────────────────────────────────────
            ..._kNavDestinations.asMap().entries.map(
              (entry) => AdminNavItem(
                icon: entry.value.icon,
                label: entry.value.label,
                isSelected: selectedIndex == entry.key,
                isCollapsed: isCollapsed,
                onTap: () => onItemSelected(entry.key),
              ),
            ),

            const Spacer(),

            // ── 3. Toggle button ─────────────────────────────────────────
            InkWell(
              onTap: onToggleCollapse,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: isCollapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    SizedBox(width: isCollapsed ? 0 : 20),
                    Icon(
                      isCollapsed
                          ? Icons.keyboard_double_arrow_right_rounded
                          : Icons.keyboard_double_arrow_left_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    if (!isCollapsed)
                      const Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: Text(
                          'Thu gọn',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const Divider(color: AppColors.border, height: 1),

            // ── 4. User footer ────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isCollapsed ? 0 : 16,
                vertical: 14,
              ),
              child: Row(
                mainAxisAlignment: isCollapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.brandRed,
                    child: Text(
                      'AD',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: kAdminSidebarDuration,
                    curve: kAdminSidebarCurve,
                    child: isCollapsed
                        ? const SizedBox.shrink()
                        : const Padding(
                            padding: EdgeInsets.only(left: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ADMIN NAV ITEM
// =============================================================================
class AdminNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;

  const AdminNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor =
        isSelected ? AppColors.sidebarSelectedText : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Tooltip(
        // Tooltip is only meaningful when collapsed; label is visible when expanded
        message: isCollapsed ? label : '',
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 300),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: kAdminSidebarDuration,
            curve: kAdminSidebarCurve,
            padding: EdgeInsets.symmetric(
              // When collapsed: symmetric padding to center the icon
              horizontal: isCollapsed ? 10 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color:
                  isSelected ? AppColors.sidebarSelected : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: [
                Icon(icon, size: 20, color: iconColor),
                // Label — slides in/out via AnimatedSize
                // ClipRect on the parent Sidebar prevents overflow
                AnimatedSize(
                  duration: kAdminSidebarDuration,
                  curve: kAdminSidebarCurve,
                  child: isCollapsed
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: iconColor,
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                            // Never wrap to a second line
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                          ),
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

// =============================================================================
// ADMIN TOP BAR
// =============================================================================
class AdminTopBar extends ConsumerWidget {
  const AdminTopBar({super.key});

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
                  prefixIconConstraints: BoxConstraints(
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
            onPressed: () => showAdminCreateEventDialog(context, ref),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
// DIALOG: TẠO SỰ KIỆN MỚI
// =============================================================================

/// Shows the "Create new disaster event" dialog.
/// Called from [AdminTopBar].
void showAdminCreateEventDialog(BuildContext context, WidgetRef ref) {
  final titleController = TextEditingController();
  String selectedType = 'typhoon'; // Default value

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
                    ref
                        .read(eventControllerProvider.notifier)
                        .createNewEvent(
                          titleController.text.trim(),
                          selectedType,
                        );
                    Navigator.pop(context);
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
