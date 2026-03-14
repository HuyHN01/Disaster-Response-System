// lib/core/routes/app_router.dart

import 'package:flutter/foundation.dart'
    show
        TargetPlatform,
        defaultTargetPlatform,
        kIsWeb,
        kReleaseMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:disaster_response_app/core/database/app_database.dart';
import 'package:disaster_response_app/features/admin_panel/presentation/admin_event_detail_screen.dart';
import 'package:disaster_response_app/features/admin_panel/presentation/admin_layout.dart';
import 'package:disaster_response_app/features/admin_panel/presentation/admin_map_screen.dart';
import 'package:disaster_response_app/features/admin_panel/presentation/admin_post_editor_screen.dart';
import 'package:disaster_response_app/features/admin_panel/presentation/event_dashboard_screen.dart';
import 'package:disaster_response_app/features/ai_assistant/presentation/ai_chat_screen.dart';
import 'package:disaster_response_app/features/citizen_news/domain/citizen_news_controller.dart';
import 'package:disaster_response_app/features/citizen_news/presentation/citizen_news_detail_screen.dart';
import 'package:disaster_response_app/features/citizen_news/presentation/citizen_news_screen.dart';
import 'package:disaster_response_app/features/event_map/presentation/event_map_screen.dart';
import 'package:disaster_response_app/features/user_mobile/presentation/mobile_home_screen.dart';

import 'route_names.dart';

/// Router factory for the Disaster Response application.
///
/// Call [AppRouter.createRouter] once — typically at the widget-tree root —
/// to obtain a fully configured [GoRouter] instance.
///
/// ## Usage
/// ```dart
/// final _router = AppRouter.createRouter();
///
/// @override
/// Widget build(BuildContext context) =>
///     MaterialApp.router(routerConfig: _router);
/// ```
///
/// ## Platform dispatch
/// ```
/// AppRouter.createRouter()
///   ├─ kIsWeb == true              → _webRouter()     (initial: /admin)
///   ├─ Android / iOS               → _mobileRouter()  (initial: /home)
///   └─ macOS / Windows / Linux     → _desktopRouter() (initial: /admin)
/// ```
///
/// ## Admin ShellRoute architecture
/// ```
/// ShellRoute (AdminLayout — sidebar + topbar)
///   ├─ /admin        → EventDashboardScreen  (content only)
///   └─ /admin/map    → AdminMapScreen         (content only)
///
/// Outside shell (full-screen — no sidebar):
///   /admin/events/:eventId                → AdminEventDetailScreen
///     ├─ posts/new                         → AdminPostEditorScreen (create)
///     └─ posts/:postId/edit                → AdminPostEditorScreen (edit)
/// ```
///
/// ## Navigation extras contract
///
/// | Route                       | `extra` type                                            |
/// |-----------------------------|---------------------------------------------------------|
/// | [RouteNames.adminEventDetail] | `DisasterEvent`                                       |
/// | [RouteNames.adminPostCreate]  | `DisasterEvent`                                       |
/// | [RouteNames.adminPostEdit]    | `Map<String, dynamic>{'event': DisasterEvent, 'post': AdminPost}` |
/// | [RouteNames.newsDetail]       | `CitizenNewsPost`                                     |
abstract final class AppRouter {
  AppRouter._();

  // ─────────────────────────────────────────────────────────────────────────
  // Public factory
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns a [GoRouter] configured for the currently running platform.
  static GoRouter createRouter() {
    if (kIsWeb) return _webRouter();

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return _mobileRouter();
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return _desktopRouter();
      default:
        // Fuchsia / unknown — fall back to mobile experience.
        return _mobileRouter();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Platform-specific router builders
  // ─────────────────────────────────────────────────────────────────────────

  /// Web: lands on the admin dashboard.
  static GoRouter _webRouter() => GoRouter(
        initialLocation: RouteNames.adminDashboard,
        debugLogDiagnostics: !kReleaseMode,
        errorBuilder: _errorPage,
        routes: [
          _rootRedirect(to: RouteNames.adminDashboard),
          ..._adminShellRoutes(),
          ..._adminDetailRoutes(),
          ..._citizenRoutes(),
        ],
      );

  /// Mobile (Android / iOS): lands on the citizen home screen.
  static GoRouter _mobileRouter() => GoRouter(
        initialLocation: RouteNames.home,
        debugLogDiagnostics: !kReleaseMode,
        errorBuilder: _errorPage,
        routes: [
          _rootRedirect(to: RouteNames.home),
          ..._citizenRoutes(),
          ..._adminShellRoutes(),
          ..._adminDetailRoutes(),
        ],
      );

  /// Desktop (macOS / Windows / Linux): mirrors the web experience.
  static GoRouter _desktopRouter() => GoRouter(
        initialLocation: RouteNames.adminDashboard,
        debugLogDiagnostics: !kReleaseMode,
        errorBuilder: _errorPage,
        routes: [
          _rootRedirect(to: RouteNames.adminDashboard),
          ..._adminShellRoutes(),
          ..._adminDetailRoutes(),
          ..._citizenRoutes(),
        ],
      );

  // ─────────────────────────────────────────────────────────────────────────
  // Admin route definitions
  // ─────────────────────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────────────────────────────────
  // Admin ShellRoute — pages rendered INSIDE the sidebar layout
  // ─────────────────────────────────────────────────────────────────────────

  /// Admin shell route subtree.
  ///
  /// Wrapped in a [ShellRoute] that injects [AdminLayout] (sidebar + topbar).
  ///
  /// Routes inside this shell get the sidebar; navigating away from the shell
  /// (e.g., to [RouteNames.adminEventDetail]) shows a full-screen page.
  static List<RouteBase> _adminShellRoutes() => [
        ShellRoute(
          builder: (context, state, child) => AdminLayout(child: child),
          routes: [
            GoRoute(
              path: RouteNames.adminDashboard,
              name: RouteNames.nameAdminDashboard,
              builder: (context, state) => const EventDashboardScreen(),
            ),
            GoRoute(
              path: RouteNames.adminMap,
              name: RouteNames.nameAdminMap,
              builder: (context, state) => const AdminMapScreen(),
            ),
          ],
        ),
      ];

  // ─────────────────────────────────────────────────────────────────────────
  // Admin detail routes — OUTSIDE the shell (full screen, no sidebar)
  // ─────────────────────────────────────────────────────────────────────────

  /// Admin detail/editor routes that render WITHOUT the sidebar shell.
  ///
  /// These screens have their own full-screen layouts ([AdminEventDetailScreen],
  /// [AdminPostEditorScreen]) and must not be wrapped by [AdminLayout].
  static List<RouteBase> _adminDetailRoutes() => [
        GoRoute(
          path: RouteNames.adminEventDetail,
          name: RouteNames.nameAdminEventDetail,
          builder: (context, state) {
            final event = state.extra! as DisasterEvent;
            return AdminEventDetailScreen(event: event);
          },
          routes: [
            // ── Create a new post ──────────────────────────────────────────
            GoRoute(
              path: RouteNames.segAdminPostCreate,
              name: RouteNames.nameAdminPostCreate,
              builder: (context, state) {
                final event = state.extra! as DisasterEvent;
                return AdminPostEditorScreen(event: event);
              },
            ),
            // ── Edit an existing post ──────────────────────────────────────
            GoRoute(
              path: RouteNames.segAdminPostEdit,
              name: RouteNames.nameAdminPostEdit,
              builder: (context, state) {
                final extra = state.extra! as Map<String, dynamic>;
                return AdminPostEditorScreen(
                  event: extra['event'] as DisasterEvent,
                  existingPost: extra['post'] as AdminPost,
                );
              },
            ),
          ],
        ),
      ];

  // ─────────────────────────────────────────────────────────────────────────
  // Citizen / Mobile route definitions
  // ─────────────────────────────────────────────────────────────────────────

  /// Citizen-facing route subtree.
  ///
  /// ```
  /// /home           → MobileHomeScreen
  /// /news           → CitizenNewsScreen
  ///   └── :postId   → CitizenNewsDetailScreen   (pass CitizenNewsPost via extra)
  /// /map            → EventMapScreen
  /// /ai             → AiChatScreen
  /// ```
  static List<RouteBase> _citizenRoutes() => [
        GoRoute(
          path: RouteNames.home,
          name: RouteNames.nameHome,
          builder: (context, state) => const MobileHomeScreen(),
        ),
        GoRoute(
          path: RouteNames.news,
          name: RouteNames.nameNews,
          builder: (context, state) => const CitizenNewsScreen(),
          routes: [
            GoRoute(
              path: RouteNames.segNewsDetail,
              name: RouteNames.nameNewsDetail,
              builder: (context, state) {
                final post = state.extra is CitizenNewsPost
                    ? state.extra as CitizenNewsPost
                    : null;
                final postId =
                    state.pathParameters[RouteNames.paramPostId];

                return CitizenNewsDetailScreen(
                  post: post,
                  postId: postId,
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: RouteNames.eventMap,
          name: RouteNames.nameEventMap,
          builder: (context, state) => const EventMapScreen(),
        ),
        GoRoute(
          path: RouteNames.aiChat,
          name: RouteNames.nameAiChat,
          builder: (context, state) => const AiChatScreen(),
        ),
      ];

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates a transparent root (`/`) redirect route.
  /// No widget is ever rendered at `/`; the router always bounces to [to].
  static GoRoute _rootRedirect({required String to}) => GoRoute(
        path: RouteNames.root,
        redirect: (_, __) => to,
      );

  /// Fallback page rendered when no matching route is found.
  static Widget _errorPage(BuildContext context, GoRouterState state) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang không tìm thấy'),
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF4F6F9),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Color(0xFFDC2626),
              ),
              const SizedBox(height: 16),
              Text(
                'Không thể mở trang:\n${state.uri}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go(RouteNames.home),
                icon: const Icon(Icons.home_rounded),
                label: const Text('Về trang chủ'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
