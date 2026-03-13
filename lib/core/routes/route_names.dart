// lib/core/routes/route_names.dart

/// Central repository of every route constant for the Disaster Response app.
///
/// Three groups of constants are provided:
///
/// 1. **Full paths** — absolute paths starting with `/`.
///    Use for [GoRouter.initialLocation] and `context.go(...)` /
///    `context.push(...)` calls.
///
/// 2. **Nested segments** — relative sub-path segments with no leading `/`.
///    Use directly as [GoRoute.path] inside a parent route's `routes` list.
///
/// 3. **Named route identifiers** — unique string names for
///    `context.goNamed(...)` / `context.pushNamed(...)` so callers are fully
///    decoupled from path strings.
///
/// A fourth group of **URL parameter key names** provides the string keys
/// used when reading `GoRouterState.pathParameters`.
abstract final class RouteNames {
  RouteNames._();

  // ─────────────────────────────────────────────────────────────────────────
  // 1. Full paths  (include leading '/')
  //    Safe to pass to context.go(), context.push(), and initialLocation.
  // ─────────────────────────────────────────────────────────────────────────

  /// Application root — always redirected; never rendered directly.
  static const String root = '/';

  // ── Citizen / Mobile ──────────────────────────────────────────────────────

  /// Citizen home screen ([MobileHomeScreen]).
  static const String home = '/home';

  /// Citizen news and directives list ([CitizenNewsScreen]).
  static const String news = '/news';

  /// Single news / directive detail ([CitizenNewsDetailScreen]).
  /// Requires a [paramPostId] path parameter and a [CitizenNewsPost] via `extra`.
  static const String newsDetail = '/news/:postId';

  /// Disaster event map for citizens ([EventMapScreen]).
  static const String eventMap = '/map';

  /// AI assistant chat ([AiChatScreen]).
  static const String aiChat = '/ai';

  // ── Admin / Web ───────────────────────────────────────────────────────────

  /// Admin dashboard ([EventDashboardScreen]) — rendered inside the admin ShellRoute.
  static const String adminDashboard = '/admin';

  /// Admin SOS map ([AdminMapScreen]) — rendered inside the admin ShellRoute.
  static const String adminMap = '/admin/map';

  /// Admin event detail ([AdminEventDetailScreen]).
  /// Requires a [paramEventId] path parameter and a [DisasterEvent] via `extra`.
  static const String adminEventDetail = '/admin/events/:eventId';

  /// New post editor inside an event ([AdminPostEditorScreen] — create mode).
  /// Requires a [paramEventId] path parameter and a [DisasterEvent] via `extra`.
  static const String adminPostCreate = '/admin/events/:eventId/posts/new';

  /// Edit post editor inside an event ([AdminPostEditorScreen] — edit mode).
  /// Requires [paramEventId] + [paramPostId] path parameters and a
  /// `Map<String, dynamic>{'event': DisasterEvent, 'post': AdminPost}` via `extra`.
  static const String adminPostEdit =
      '/admin/events/:eventId/posts/:postId/edit';

  // ─────────────────────────────────────────────────────────────────────────
  // 2. Nested segments  (no leading '/')
  //    Use as GoRoute.path when registering child routes inside a parent.
  // ─────────────────────────────────────────────────────────────────────────

  static const String segNewsDetail = ':postId';
  static const String segAdminMap = 'map';
  static const String segAdminEventDetail = 'events/:eventId';
  static const String segAdminPostCreate = 'posts/new';
  static const String segAdminPostEdit = 'posts/:postId/edit';

  // ─────────────────────────────────────────────────────────────────────────
  // 3. URL parameter key names
  //    Use with GoRouterState.pathParameters[RouteNames.paramXxx].
  // ─────────────────────────────────────────────────────────────────────────

  static const String paramPostId = 'postId';
  static const String paramEventId = 'eventId';

  // ─────────────────────────────────────────────────────────────────────────
  // 4. Named route identifiers
  //    Use with context.goNamed(...) / context.pushNamed(...).
  // ─────────────────────────────────────────────────────────────────────────

  static const String nameHome = 'home';
  static const String nameNews = 'news';
  static const String nameNewsDetail = 'news-detail';
  static const String nameEventMap = 'event-map';
  static const String nameAiChat = 'ai-chat';
  static const String nameAdminDashboard = 'admin-dashboard';
  static const String nameAdminMap = 'admin-map';
  static const String nameAdminEventDetail = 'admin-event-detail';
  static const String nameAdminPostCreate = 'admin-post-create';
  static const String nameAdminPostEdit = 'admin-post-edit';
}
