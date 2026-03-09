// lib/core/services/firebase/sync_service.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:disaster_response_app/core/database/app_database.dart';
import 'package:disaster_response_app/core/database/db_provider.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// =============================================================================
// CONSTANTS — Firestore collection names
// =============================================================================
class _Collections {
  static const String posts = 'posts';
  static const String locations = 'locations';
  static const String disasterEvents = 'disaster_events';
}

// =============================================================================
// SYNC RESULT — a typed result instead of raw booleans
// =============================================================================
class SyncResult {
  final int syncedCount;
  final List<String> failedIds;
  final String? errorMessage;

  const SyncResult({
    this.syncedCount = 0,
    this.failedIds = const [],
    this.errorMessage,
  });

  bool get isSuccess => errorMessage == null;
  bool get hasPartialFailure => failedIds.isNotEmpty;

  @override
  String toString() =>
      'SyncResult(synced: $syncedCount, failed: ${failedIds.length}, '
      'error: $errorMessage)';
}

// =============================================================================
// SYNC SERVICE
// =============================================================================
class FirebaseSyncService {
  final AppDatabase _db;
  final FirebaseFirestore _firestore;
  final Connectivity _connectivity;

  // Keeps track of the active Firestore listener so we can cancel it cleanly.
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _eventsSubscription;

  FirebaseSyncService({
    required AppDatabase db,
    FirebaseFirestore? firestore,
    Connectivity? connectivity,
  })  : _db = db,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _connectivity = connectivity ?? Connectivity();

  // ---------------------------------------------------------------------------
  // PUBLIC API
  // ---------------------------------------------------------------------------

  /// Pushes every local SOS post with `syncStatus == 'pending'` up to
  /// Firestore, then marks them as `'synced'` in Drift.
  ///
  /// Returns a [SyncResult] describing how many records were synced and
  /// which ones (if any) failed.
  Future<SyncResult> syncPendingSOS() async {
    // ── 1. Check connectivity ──────────────────────────────────────────────
    final isOnline = await _isConnected();
    if (!isOnline) {
      return const SyncResult(
        errorMessage: 'Không có kết nối mạng — bỏ qua đồng bộ SOS.',
      );
    }

    // ── 2. Query pending SOS posts from Drift ──────────────────────────────
    final pendingPosts = await _queryPendingSOSPosts();
    if (pendingPosts.isEmpty) {
      return const SyncResult(); // nothing to do
    }

    // ── 3. Load associated locations (one query, keyed by postId) ──────────
    final postIds = pendingPosts.map((p) => p.id).toList();
    final locationsByPostId = await _loadLocationsByPostIds(postIds);

    // ── 4. Sync each post in its own Firestore batch ───────────────────────
    final List<String> failedIds = [];
    int syncedCount = 0;

    for (final post in pendingPosts) {
      try {
        await _syncSinglePost(
          post: post,
          location: locationsByPostId[post.id],
        );
        syncedCount++;
      } catch (e, st) {
        _log('Lỗi đồng bộ post ${post.id}: $e\n$st');
        failedIds.add(post.id);
        // Continue with the remaining posts rather than aborting everything.
      }
    }

    return SyncResult(
      syncedCount: syncedCount,
      failedIds: failedIds,
    );
  }

  /// Opens a **realtime** Firestore listener on the `disaster_events`
  /// collection and writes any new/updated documents straight into the
  /// local Drift [DisasterEvents] table.
  ///
  /// Call [stopListeningToAdminEvents] to tear down the subscription.
  void listenToAdminEvents({
    void Function(DisasterEvent event)? onNewEvent,
    void Function(Object error)? onError,
  }) {
    // Cancel any previously active subscription before opening a new one.
    _eventsSubscription?.cancel();

    final query = _firestore
        .collection(_Collections.disasterEvents)
        .orderBy('createdAt', descending: true);

    _eventsSubscription = query.snapshots().listen(
      (snapshot) => _handleEventSnapshot(
        snapshot,
        onNewEvent: onNewEvent,
      ),
      onError: (Object error, StackTrace st) {
        _log('Lỗi lắng nghe disaster_events: $error\n$st');
        onError?.call(error);
      },
      cancelOnError: false, // keep listening even after a transient error
    );
  }

  /// Cancels the active Firestore realtime listener (if any).
  Future<void> stopListeningToAdminEvents() async {
    await _eventsSubscription?.cancel();
    _eventsSubscription = null;
  }

  /// Convenience method: call once at app start to wire up both directions.
  Future<SyncResult> startSync() async {
    listenToAdminEvents();
    return syncPendingSOS();
  }

  /// Tears everything down — call when the user signs out or app disposes.
  Future<void> dispose() async {
    await stopListeningToAdminEvents();
  }

  // ---------------------------------------------------------------------------
  // PRIVATE — SOS sync helpers
  // ---------------------------------------------------------------------------

  Future<List<Post>> _queryPendingSOSPosts() async {
    return (_db.select(_db.posts)
          ..where(
            (p) =>
                p.postType.equals('sos') &
                p.syncStatus.equals('pending'),
          ))
        .get();
  }

  Future<Map<String, Location>> _loadLocationsByPostIds(
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) return {};

    final locations = await (_db.select(_db.locations)
          ..where((l) => l.postId.isIn(postIds)))
        .get();

    return {for (final loc in locations) loc.postId: loc};
  }

  /// Writes a single post + its location to Firestore in one batch, then
  /// marks the post as `'synced'` in Drift.
  Future<void> _syncSinglePost({
    required Post post,
    required Location? location,
  }) async {
    final batch = _firestore.batch();

    // ── Write post document ──────────────────────────────────────────────
    final postRef =
        _firestore.collection(_Collections.posts).doc(post.id);
    batch.set(postRef, _postToFirestore(post), SetOptions(merge: true));

    // ── Write location document (if available) ───────────────────────────
    if (location != null) {
      final locRef =
          _firestore.collection(_Collections.locations).doc(location.id);
      batch.set(locRef, _locationToFirestore(location),
          SetOptions(merge: true));
    }

    // Commit — will throw if Firestore rejects the write.
    await batch.commit();

    // ── Mark as synced in Drift ──────────────────────────────────────────
    await (_db.update(_db.posts)
          ..where((p) => p.id.equals(post.id)))
        .write(
      const PostsCompanion(
        syncStatus: Value('synced'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PRIVATE — Firestore → Drift helpers
  // ---------------------------------------------------------------------------

  Future<void> _handleEventSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    void Function(DisasterEvent event)? onNewEvent,
  }) async {
    // Process only document additions and modifications — ignore removals
    // so we keep a local cache even if admin deletes from Firestore.
    final relevantChanges = snapshot.docChanges.where(
      (c) =>
          c.type == DocumentChangeType.added ||
          c.type == DocumentChangeType.modified,
    );

    for (final change in relevantChanges) {
      try {
        final data = change.doc.data();
        if (data == null) continue;

        final companion = _firestoreToDisasterEventCompanion(
          docId: change.doc.id,
          data: data,
        );

        // Upsert — insert or replace if the record already exists locally.
        await _db
            .into(_db.disasterEvents)
            .insertOnConflictUpdate(companion);

        // Notify caller (e.g. to refresh a Riverpod provider).
        if (onNewEvent != null) {
          final inserted = await (_db.select(_db.disasterEvents)
                ..where((e) => e.id.equals(change.doc.id)))
              .getSingleOrNull();
          if (inserted != null) onNewEvent(inserted);
        }
      } catch (e, st) {
        _log(
          'Lỗi xử lý disaster_event ${change.doc.id}: $e\n$st',
        );
        // Skip this document and continue with the rest.
      }
    }
  }

  // ---------------------------------------------------------------------------
  // PRIVATE — Serialisation helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _postToFirestore(Post post) => {
        'id': post.id,
        'eventId': post.eventId,
        'userId': post.userId,
        'postType': post.postType,
        'content': post.content,
        'isVerified': post.isVerified,
        'createdAt': Timestamp.fromDate(post.createdAt),
        'syncStatus': 'synced',
        'uploadedAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> _locationToFirestore(Location loc) => {
        'id': loc.id,
        'postId': loc.postId,
        'latitude': loc.latitude,
        'longitude': loc.longitude,
        'addressText': loc.addressText,
      };

  DisasterEventsCompanion _firestoreToDisasterEventCompanion({
    required String docId,
    required Map<String, dynamic> data,
  }) {
    final rawCreatedAt = data['createdAt'];
    final createdAt = rawCreatedAt is Timestamp
        ? rawCreatedAt.toDate()
        : DateTime.now();

    return DisasterEventsCompanion.insert(
      id: docId,
      title: (data['title'] as String?) ?? '(Không có tiêu đề)',
      eventType: (data['eventType'] as String?) ?? 'unknown',
      status: (data['status'] as String?) ?? 'active',
      createdAt: createdAt,
      createdBy: (data['createdBy'] as String?) ?? 'admin',
    );
  }

  // ---------------------------------------------------------------------------
  // PRIVATE — Utilities
  // ---------------------------------------------------------------------------

  Future<bool> _isConnected() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any(
        (r) => r != ConnectivityResult.none,
      );
    } catch (_) {
      return false;
    }
  }

  void _log(String message) {
    // In production, replace with a proper logger (e.g. `logger` package).
    // ignore: avoid_print
    print('[FirebaseSyncService] $message');
  }
}

// =============================================================================
// RIVERPOD PROVIDERS
// =============================================================================

/// Provides the singleton [FirebaseSyncService].
/// Automatically disposes the Firestore listener when the provider is
/// destroyed (e.g. on sign-out).
final firebaseSyncServiceProvider = Provider<FirebaseSyncService>((ref) {
  final db = ref.watch(dbProvider);

  final service = FirebaseSyncService(db: db);

  ref.onDispose(service.dispose);

  return service;
});

/// A fire-and-forget [FutureProvider] that kicks off the initial SOS sync.
/// Useful to call in a top-level `ProviderScope` override or in
/// `main()` after Firebase is initialised.
final initialSyncProvider = FutureProvider<SyncResult>((ref) async {
  final service = ref.watch(firebaseSyncServiceProvider);
  return service.syncPendingSOS();
});