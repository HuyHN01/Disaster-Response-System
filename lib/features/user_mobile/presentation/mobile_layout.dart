// lib/features/user_mobile/presentation/mobile_layout.dart
//
// ShellRoute layout for the Mobile app.
//
// Provides the BottomNavigationBar shell that wraps every mobile citizen screen.
// Individual mobile screens (MobileHomeScreen, MobileProfileScreen) are injected
// as [child] by GoRouter — they have no navbar knowledge of their own.
//
// Architecture:
//   ShellRoute
//     └── MobileLayout (this file)
//           ├── child         — injected by GoRouter ShellRoute
//           └── BottomNavigationBar   — persistent navigation

import 'package:disaster_response_app/core/routes/route_names.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// =============================================================================
// NAV DESTINATION MODEL
// =============================================================================
class _MobileNavDestination {
  final IconData icon;
  final String label;
  final String route;

  const _MobileNavDestination({
    required this.icon,
    required this.label,
    required this.route,
  });
}

// ── Nav destinations list ─────────────────────────────────────────────────
const List<_MobileNavDestination> _kMobileNavDestinations = [
  _MobileNavDestination(
    icon: Icons.home_rounded,
    label: 'Trang chủ',
    route: RouteNames.home,
  ),
  _MobileNavDestination(
    icon: Icons.person_rounded,
    label: 'Cá nhân',
    route: RouteNames.profile,
  ),
];

// =============================================================================
// MOBILE LAYOUT — ShellRoute builder widget
// =============================================================================
class MobileLayout extends StatefulWidget {
  /// The currently active child page provided by GoRouter.
  final Widget child;

  const MobileLayout({super.key, required this.child});

  @override
  State<MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<MobileLayout> {
  /// Checks if the current location is one of the main tabs.
  bool _isMainTab(String location) {
    final segments = location.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return true;

    final firstSegment = '/${segments.first}';
    return firstSegment == RouteNames.home || firstSegment == RouteNames.profile;
  }

  /// Derives the selected nav index from the current GoRouter location.
  int _selectedIndex(String location) {
    // Get the first path segment
    final segments = location.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return 0;

    final firstSegment = '/${segments.first}';

    if (firstSegment == RouteNames.profile) return 1;
    // Default: Home (includes /home, /news, /map, /ai)
    return 0;
  }

  void _onNavTapped(int index) {
    final route = _kMobileNavDestinations[index].route;
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final selectedIdx = _selectedIndex(location);
    final showBottomNav = _isMainTab(location);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: showBottomNav
          ? BottomNavigationBar(
              currentIndex: selectedIdx,
              onTap: _onNavTapped,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              selectedItemColor: const Color(0xFFDC2626),
              unselectedItemColor: const Color(0xFF9CA3AF),
              selectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              items: _kMobileNavDestinations
                  .map(
                    (dest) => BottomNavigationBarItem(
                      icon: Icon(dest.icon),
                      label: dest.label,
                    ),
                  )
                  .toList(),
            )
          : null,
    );
  }
}
