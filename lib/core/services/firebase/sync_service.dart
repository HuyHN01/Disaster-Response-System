// lib/core/services/firebase/sync_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:disaster_response_app/core/database/app_database.dart';
import 'package:disaster_response_app/core/database/db_provider.dart';
import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';

// =============================================================================
// CONSTANTS — Firestore collection names
// =============================================================================
class _Collections {
  static const String posts = 'posts';
  static const String locations = 'locations';
  static const String disasterEvents = 'disaster_events';
  static const String rescueStations = 'rescue_stations';
  static const String users = 'users';
  static const String communityReports = 'community_reports';
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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _eventsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _rescueStationsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _communityReportsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _sosReportsSubscription;
  StreamSubscription<dynamic>? _usersSubscription;

  FirebaseSyncService({
    required AppDatabase db,
    FirebaseFirestore? firestore,
    Connectivity? connectivity,
  }) : _db = db,
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
        await _syncSinglePost(post: post, location: locationsByPostId[post.id]);
        syncedCount++;
      } catch (e, st) {
        _log('Lỗi đồng bộ post ${post.id}: $e\n$st');
        failedIds.add(post.id);
        // Continue with the remaining posts rather than aborting everything.
      }
    }

    return SyncResult(syncedCount: syncedCount, failedIds: failedIds);
  }

  /// Pushes every local rescue station with `syncStatus == 'pending'`
  /// up to Firestore and marks it as synced in Drift.
  Future<SyncResult> syncPendingRescueStations() async {
    final isOnline = await _isConnected();
    if (!isOnline) {
      return const SyncResult(
        errorMessage: 'Không có kết nối mạng — bỏ qua đồng bộ trạm cứu trợ.',
      );
    }

    final pendingStations = await (_db.select(
      _db.rescueStations,
    )..where((s) => s.syncStatus.equals('pending'))).get();

    if (pendingStations.isEmpty) {
      return const SyncResult();
    }

    final failedIds = <String>[];
    var syncedCount = 0;

    for (final station in pendingStations) {
      try {
        await _syncSingleRescueStation(station);
        syncedCount++;
      } catch (e, st) {
        _log('Lỗi đồng bộ rescue_station ${station.id}: $e\n$st');
        failedIds.add(station.id);
      }
    }

    return SyncResult(syncedCount: syncedCount, failedIds: failedIds);
  }

  /// Pushes every local check-in log with `syncStatus == 'pending'`
  /// up to Firestore and marks it as synced in Drift.
  Future<SyncResult> syncPendingCheckInLogs() async {
    final isOnline = await _isConnected();
    if (!isOnline) {
      return const SyncResult(
        errorMessage: 'Không có kết nối mạng — bỏ qua đồng bộ logs.',
      );
    }

    final pendingLogs = await (_db.select(
      _db.checkInLogs,
    )..where((s) => s.syncStatus.equals('pending'))).get();

    if (pendingLogs.isEmpty) {
      return const SyncResult();
    }

    final failedIds = <String>[];
    var syncedCount = 0;

    for (final log in pendingLogs) {
      try {
        await _syncSingleCheckInLog(log);
        syncedCount++;
      } catch (e, st) {
        _log('Lỗi đồng bộ check_in_log ${log.id}: $e\n$st');
        failedIds.add(log.id);
      }
    }

    return SyncResult(syncedCount: syncedCount, failedIds: failedIds);
  }

  /// Pushes every local community report with `syncStatus == 'pending'`
  /// up to Firestore and marks it as synced in Drift.
  Future<SyncResult> syncPendingCommunityReports() async {
    final isOnline = await _isConnected();
    if (!isOnline) {
      return const SyncResult(
        errorMessage: 'Không có kết nối mạng — bỏ qua đồng bộ báo cáo cộng đồng.',
      );
    }

    final pendingReports = await (_db.select(
      _db.communityReports,
    )..where((s) => s.syncStatus.equals('pending'))).get();

    if (pendingReports.isEmpty) {
      return const SyncResult();
    }

    final failedIds = <String>[];
    var syncedCount = 0;

    for (final report in pendingReports) {
      try {
        await _syncSingleCommunityReport(report);
        syncedCount++;
      } catch (e, st) {
        _log('Lỗi đồng bộ community_report ${report.id}: $e\\n$st');
        failedIds.add(report.id);
      }
    }

    return SyncResult(syncedCount: syncedCount, failedIds: failedIds);
  }

  Future<SyncResult> syncPendingEventDamageStats() async {
    final isOnline = await _isConnected();
    if (!isOnline) {
      return const SyncResult(
        errorMessage: 'Không có kết nối mạng — bỏ qua đồng bộ event_damage_stats.',
      );
    }

    final pendingStats = await (_db.select(
      _db.eventDamageStats,
    )..where((s) => s.syncStatus.equals('pending'))).get();

    if (pendingStats.isEmpty) {
      return const SyncResult();
    }

    final failedIds = <String>[];
    var syncedCount = 0;

    for (final stat in pendingStats) {
      try {
        await _syncSingleEventDamageStat(stat);
        syncedCount++;
      } catch (e, st) {
        _log('Lỗi đồng bộ damage_stat ${stat.id}: $e\n$st');
        failedIds.add(stat.id);
      }
    }

    return SyncResult(syncedCount: syncedCount, failedIds: failedIds);
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
      (snapshot) => _handleEventSnapshot(snapshot, onNewEvent: onNewEvent),
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

  /// Opens a realtime Firestore listener on `rescue_stations`.
  ///
  /// The handler applies last-write-wins using `updatedAt` and keeps Drift
  /// as the local source for offline features.
  void listenToRescueStations({
    void Function(RescueStation station)? onUpsert,
    void Function(Object error)? onError,
  }) {
    _rescueStationsSubscription?.cancel();

    final query = _firestore.collection(_Collections.rescueStations);

    _rescueStationsSubscription = query.snapshots().listen(
      (snapshot) => _handleRescueStationSnapshot(snapshot, onUpsert: onUpsert),
      onError: (Object error, StackTrace st) {
        _log('Lỗi lắng nghe rescue_stations: $error\n$st');
        onError?.call(error);
      },
      cancelOnError: false,
    );
  }

  Future<void> stopListeningToRescueStations() async {
    await _rescueStationsSubscription?.cancel();
    _rescueStationsSubscription = null;
  }

  /// Opens a realtime Firestore listener on `community_reports`.
  void listenToCommunityReports({
    void Function(CommunityReport report)? onUpsert,
    void Function(Object error)? onError,
  }) {
    _communityReportsSubscription?.cancel();

    final query = _firestore.collection(_Collections.communityReports);

    _communityReportsSubscription = query.snapshots().listen(
      (snapshot) => _handleCommunityReportSnapshot(snapshot, onUpsert: onUpsert),
      onError: (Object error, StackTrace st) {
        _log('Lỗi lắng nghe community_reports: $error\\n$st');
        onError?.call(error);
      },
      cancelOnError: false,
    );
  }

  Future<void> stopListeningToCommunityReports() async {
    await _communityReportsSubscription?.cancel();
    _communityReportsSubscription = null;
  }

  /// Opens a realtime Firestore listener on `posts` where postType == 'sos'.
  void listenToSOSReports({
    void Function(Post post, Location? location)? onUpsert,
    void Function(Object error)? onError,
  }) {
    _sosReportsSubscription?.cancel();

    final query = _firestore
        .collection(_Collections.posts)
        .where('postType', isEqualTo: 'sos');

    _sosReportsSubscription = query.snapshots().listen(
      (snapshot) => _handleSOSReportSnapshot(snapshot, onUpsert: onUpsert),
      onError: (Object error, StackTrace st) {
        _log('Lỗi lắng nghe SOS reports: $error\n$st');
        onError?.call(error);
      },
      cancelOnError: false,
    );
  }

  Future<void> stopListeningToSOSReports() async {
    await _sosReportsSubscription?.cancel();
    _sosReportsSubscription = null;
  }

  /// Opens a realtime Firestore listener on `users`.
  ///
  /// This keeps local account metadata aligned for offline reads.
  void listenToUsers({
    void Function(User user)? onUpsert,
    void Function(Object error)? onError,
  }) {
    _usersSubscription?.cancel();

    final currentUser = fb_auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _log('Bỏ lắng nghe users: chưa có phiên đăng nhập.');
      return;
    }

    final docRef = _firestore.collection(_Collections.users).doc(currentUser.uid);

    _usersSubscription = docRef.snapshots().listen(
      (snapshot) async {
        try {
          if (!snapshot.exists) {
            await (_db.delete(_db.users)
                  ..where((u) => u.id.equals(currentUser.uid)))
                .go();
            return;
          }

          final data = snapshot.data();
          if (data == null) return;

          final incoming = _firestoreToUserCompanion(
            docId: snapshot.id,
            data: data,
          );

          await _db.into(_db.users).insertOnConflictUpdate(incoming);

          if (onUpsert != null) {
            final inserted = await (_db.select(
              _db.users,
            )..where((u) => u.id.equals(snapshot.id))).getSingleOrNull();
            if (inserted != null) onUpsert(inserted);
          }
        } catch (e, st) {
          _log('Lỗi xử lý user ${snapshot.id}: $e\n$st');
        }
      },
      onError: (Object error, StackTrace st) {
        _log('Lỗi lắng nghe users: $error\n$st');
        onError?.call(error);
      },
      cancelOnError: false,
    );
  }

  Future<void> stopListeningToUsers() async {
    await _usersSubscription?.cancel();
    _usersSubscription = null;
  }

  /// Convenience method: call once at app start to wire up both directions.
  Future<SyncResult> startSync() async {
    listenToAdminEvents();
    listenToRescueStations();
    listenToCommunityReports();
    listenToSOSReports();
    listenToUsers();

    final sosResult = await syncPendingSOS();
    final stationResult = await syncPendingRescueStations();
    final logResult = await syncPendingCheckInLogs();
    final communityResult = await syncPendingCommunityReports();
    final damageStatResult = await syncPendingEventDamageStats();

    if (!stationResult.isSuccess || stationResult.hasPartialFailure) {
      _log('Rescue station sync result: $stationResult');
    }
    if (!logResult.isSuccess || logResult.hasPartialFailure) {
      _log('Check-in log sync result: $logResult');
    }
    if (!communityResult.isSuccess || communityResult.hasPartialFailure) {
      _log('Community reports sync result: $communityResult');
    }
    if (!damageStatResult.isSuccess || damageStatResult.hasPartialFailure) {
      _log('Event damage stat sync result: $damageStatResult');
    }

    return sosResult;
  }

  /// Completes a 3-step migration for an anonymous user logging in:
  /// 1. Transfers local 'pending' records ownership to [realUid].
  /// 2. Pulls old data owned by [realUid] from Firestore and hydrates local DB.
  /// 3. Pushes newly claimed pending data to Firestore.
  Future<void> migrateAndSyncUserData(String realUid) async {
    _log('Migrating anonymous data to real Uid: $realUid');
    // Step 1: Local Ownership Transfer
    final tempUids = const ['citizen_01', 'anonymous', 'null', ''];

    // Update Posts - gỡ điều kiện pending, force lại thành pending để kích hoạt update lên Firebase
    await (_db.update(_db.posts)..where((t) => t.userId.isIn(tempUids)))
        .write(PostsCompanion(userId: Value(realUid), syncStatus: const Value('pending')));

    // Update CommunityReports
    await (_db.update(_db.communityReports)..where((t) => t.reportedBy.isIn(tempUids)))
        .write(CommunityReportsCompanion(reportedBy: Value(realUid), syncStatus: const Value('pending')));

    // Update CheckInLogs
    await (_db.update(_db.checkInLogs)..where((t) => t.userId.isIn(tempUids)))
        .write(CheckInLogsCompanion(userId: Value(realUid), syncStatus: const Value('pending')));

    if (!await _isConnected()) {
      _log('No connection during migration. Steps 2 & 3 skipped.');
      return;
    }

    // Step 2: Pull & Hydrate (Old Data)
    try {
      // Pull and hydrate posts and associated locations
      final postsSnapshot = await _firestore.collection(_Collections.posts).where('userId', isEqualTo: realUid).get();
      for (final doc in postsSnapshot.docs) {
        final data = doc.data();
        await _db.into(_db.posts).insertOnConflictUpdate(_firestoreToPostCompanion(doc.id, data));
        
        // Also fetch location if exists
        final locSnapshot = await _firestore.collection(_Collections.locations).where('postId', isEqualTo: doc.id).limit(1).get();
        if (locSnapshot.docs.isNotEmpty) {
          final locDoc = locSnapshot.docs.first;
          await _db.into(_db.locations).insertOnConflictUpdate(_firestoreToLocationCompanion(locDoc.id, locDoc.data(), doc.id));
        }
      }

      // Pull and hydrate community reports
      final reportsSnapshot = await _firestore.collection(_Collections.communityReports).where('reportedBy', isEqualTo: realUid).get();
      for (final doc in reportsSnapshot.docs) {
        await _db.into(_db.communityReports).insertOnConflictUpdate(_firestoreToCommunityReportCompanion(docId: doc.id, data: doc.data()));
      }

      // Pull and hydrate check-in logs
      final logsSnapshot = await _firestore.collection('check_in_logs').where('userId', isEqualTo: realUid).get();
      for (final doc in logsSnapshot.docs) {
        await _db.into(_db.checkInLogs).insertOnConflictUpdate(_firestoreToCheckInLogCompanion(doc.id, doc.data()));
      }
    } catch (e, st) {
      _log('Migration Step 2 (Hydrate) error: $e\n$st');
    }

    // Step 3: Push & Append (New Data)
    await syncPendingSOS();
    await syncPendingCommunityReports();
    await syncPendingCheckInLogs();
    
    _log('Migration complete for Uid: $realUid');
  }

  /// Tears everything down — call when the user signs out or app disposes.
  Future<void> dispose() async {
    await stopListeningToAdminEvents();
    await stopListeningToRescueStations();
    await stopListeningToCommunityReports();
    await stopListeningToUsers();
  }

  Future<void> _syncSingleCheckInLog(CheckInLog log) async {
    final docRef = _firestore.collection('check_in_logs').doc(log.id);
    await docRef.set(_checkInLogToFirestore(log), SetOptions(merge: true));

    await (_db.update(_db.checkInLogs)..where((l) => l.id.equals(log.id))).write(
      const CheckInLogsCompanion(syncStatus: Value('synced')),
    );
  }

  Future<void> _syncSingleCommunityReport(CommunityReport report) async {
    final ref = _firestore
        .collection(_Collections.communityReports)
        .doc(report.id);
    await ref.set(_communityReportToFirestore(report), SetOptions(merge: true));

    await (_db.update(
      _db.communityReports,
    )..where((s) => s.id.equals(report.id))).write(
      const CommunityReportsCompanion(
        syncStatus: Value('synced'),
      ),
    );
  }

  Future<void> _syncSingleEventDamageStat(EventDamageStat stat) async {
    final ref = _firestore
        .collection(_Collections.disasterEvents)
        .doc(stat.eventId)
        .collection('damage_stats')
        .doc(stat.id);
    await ref.set(_eventDamageStatsToFirestore(stat), SetOptions(merge: true));

    await (_db.update(_db.eventDamageStats)
          ..where((s) => s.id.equals(stat.id)))
        .write(const EventDamageStatsCompanion(syncStatus: Value('synced')));
  }

  // ---------------------------------------------------------------------------
  // PRIVATE — SOS sync helpers
  // ---------------------------------------------------------------------------

  Future<List<Post>> _queryPendingSOSPosts() async {
    return (_db.select(_db.posts)..where(
          (p) => p.postType.equals('sos') & p.syncStatus.equals('pending'),
        ))
        .get();
  }

  Future<Map<String, Location>> _loadLocationsByPostIds(
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) return {};

    final locations = await (_db.select(
      _db.locations,
    )..where((l) => l.postId.isIn(postIds))).get();

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
    final postRef = _firestore.collection(_Collections.posts).doc(post.id);
    batch.set(postRef, _postToFirestore(post), SetOptions(merge: true));

    // ── Write location document (if available) ───────────────────────────
    if (location != null) {
      final locRef = _firestore
          .collection(_Collections.locations)
          .doc(location.id);
      batch.set(
        locRef,
        _locationToFirestore(location),
        SetOptions(merge: true),
      );
    }

    // Commit — will throw if Firestore rejects the write.
    await batch.commit();

    // ── Mark as synced in Drift ──────────────────────────────────────────
    await (_db.update(_db.posts)..where((p) => p.id.equals(post.id))).write(
      const PostsCompanion(syncStatus: Value('synced')),
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
        await _db.into(_db.disasterEvents).insertOnConflictUpdate(companion);
        
        await _pullDamageStatsForEvent(change.doc.id);

        // Notify caller (e.g. to refresh a Riverpod provider).
        if (onNewEvent != null) {
          final inserted = await (_db.select(
            _db.disasterEvents,
          )..where((e) => e.id.equals(change.doc.id))).getSingleOrNull();
          if (inserted != null) onNewEvent(inserted);
        }
      } catch (e, st) {
        _log('Lỗi xử lý disaster_event ${change.doc.id}: $e\n$st');
        // Skip this document and continue with the rest.
      }
    }
  }

  Future<void> _pullDamageStatsForEvent(String eventId) async {
    final query = _firestore
        .collection(_Collections.disasterEvents)
        .doc(eventId)
        .collection('damage_stats');
    
    final snapshot = await query.get();
    for (final doc in snapshot.docs) {
      try {
        final companion = _firestoreToEventDamageStatsCompanion(
          docId: doc.id,
          eventId: eventId,
          data: doc.data(),
        );
        await _db.into(_db.eventDamageStats).insertOnConflictUpdate(companion);
      } catch (e, st) {
        _log('Error processing damage_stats ${doc.id}: $e\n$st');
      }
    }
  }

  Future<void> _handleRescueStationSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    void Function(RescueStation station)? onUpsert,
  }) async {
    for (final change in snapshot.docChanges) {
      try {
        if (change.type == DocumentChangeType.removed) {
          await (_db.delete(
            _db.rescueStations,
          )..where((s) => s.id.equals(change.doc.id))).go();
          continue;
        }

        final data = change.doc.data();
        if (data == null) continue;

        final incoming = _firestoreToRescueStationCompanion(
          docId: change.doc.id,
          data: data,
        );

        final existing = await (_db.select(
          _db.rescueStations,
        )..where((s) => s.id.equals(change.doc.id))).getSingleOrNull();

        if (existing != null &&
            existing.syncStatus == 'pending' &&
            !_isIncomingStationNewer(existing, incoming)) {
          // Local pending change is newer than incoming remote snapshot.
          continue;
        }

        await _db.into(_db.rescueStations).insertOnConflictUpdate(incoming);

        if (onUpsert != null) {
          final inserted = await (_db.select(
            _db.rescueStations,
          )..where((s) => s.id.equals(change.doc.id))).getSingleOrNull();
          if (inserted != null) onUpsert(inserted);
        }
      } catch (e, st) {
        _log('Lỗi xử lý rescue_station ${change.doc.id}: $e\n$st');
      }
    }
  }

  Future<void> _handleCommunityReportSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    void Function(CommunityReport report)? onUpsert,
  }) async {
    for (final change in snapshot.docChanges) {
      try {
        if (change.type == DocumentChangeType.removed) {
          await (_db.delete(
            _db.communityReports,
          )..where((s) => s.id.equals(change.doc.id))).go();
          continue;
        }

        final data = change.doc.data();
        if (data == null) continue;

        final incoming = _firestoreToCommunityReportCompanion(
          docId: change.doc.id,
          data: data,
        );

        await _db.into(_db.communityReports).insertOnConflictUpdate(incoming);

        if (onUpsert != null) {
          final inserted = await (_db.select(
            _db.communityReports,
          )..where((s) => s.id.equals(change.doc.id))).getSingleOrNull();
          if (inserted != null) onUpsert(inserted);
        }
      } catch (e, st) {
        _log('Lỗi xử lý community_report ${change.doc.id}: $e\n$st');
      }
    }
  }

  Future<void> _handleSOSReportSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    void Function(Post post, Location? location)? onUpsert,
  }) async {
    for (final change in snapshot.docChanges) {
      try {
        if (change.type == DocumentChangeType.removed) {
          await _db.transaction(() async {
            await (_db.delete(_db.posts)..where((p) => p.id.equals(change.doc.id))).go();
            await (_db.delete(_db.locations)..where((l) => l.postId.equals(change.doc.id))).go();
          });
          continue;
        }

        final data = change.doc.data();
        if (data == null) continue;

        final incomingPost = _firestoreToPostCompanion(
          change.doc.id,
          data,
        );

        await _db.into(_db.posts).insertOnConflictUpdate(incomingPost);

        Location? insertedLoc;
        final rawLat = data['latitude'];
        final rawLng = data['longitude'];

        if (rawLat != null && rawLng != null) {
          final incomingLoc = LocationsCompanion.insert(
            id: 'loc_${change.doc.id}',
            postId: change.doc.id,
            latitude: (rawLat as num).toDouble(),
            longitude: (rawLng as num).toDouble(),
          );
          await _db.into(_db.locations).insertOnConflictUpdate(incomingLoc);
          insertedLoc = await (_db.select(_db.locations)..where((l) => l.postId.equals(change.doc.id))).getSingleOrNull();
        } else {
          final locDoc = await _firestore.collection(_Collections.locations)
              .where('postId', isEqualTo: change.doc.id)
              .limit(1)
              .get();

          if (locDoc.docs.isNotEmpty) {
            final locData = locDoc.docs.first.data();
            final incomingLoc = _firestoreToLocationCompanion(locDoc.docs.first.id, locData, change.doc.id);
            await _db.into(_db.locations).insertOnConflictUpdate(incomingLoc);
            insertedLoc = await (_db.select(_db.locations)..where((l) => l.id.equals(locDoc.docs.first.id))).getSingleOrNull();
          }
        }

        if (onUpsert != null) {
          final insertedPost = await (_db.select(
            _db.posts,
          )..where((p) => p.id.equals(change.doc.id))).getSingleOrNull();
          if (insertedPost != null) onUpsert(insertedPost, insertedLoc);
        }
      } catch (e, st) {
        _log('Lỗi xử lý sos_report ${change.doc.id}: $e\n$st');
      }
    }
  }

  Future<void> _handleUsersSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot, {
    void Function(User user)? onUpsert,
  }) async {
    for (final change in snapshot.docChanges) {
      try {
        if (change.type == DocumentChangeType.removed) {
          await (_db.delete(_db.users)..where((u) => u.id.equals(change.doc.id)))
              .go();
          continue;
        }

        final data = change.doc.data();
        if (data == null) continue;

        final incoming = _firestoreToUserCompanion(
          docId: change.doc.id,
          data: data,
        );

        await _db.into(_db.users).insertOnConflictUpdate(incoming);

        if (onUpsert != null) {
          final inserted = await (_db.select(
            _db.users,
          )..where((u) => u.id.equals(change.doc.id))).getSingleOrNull();
          if (inserted != null) onUpsert(inserted);
        }
      } catch (e, st) {
        _log('Lỗi xử lý user ${change.doc.id}: $e\n$st');
      }
    }
  }

  bool _isIncomingStationNewer(
    RescueStation local,
    RescueStationsCompanion incoming,
  ) {
    final localUpdatedAt = local.updatedAt ?? local.createdAt;
    final incomingUpdatedAt =
        incoming.updatedAt.present && incoming.updatedAt.value != null
        ? incoming.updatedAt.value!
        : incoming.createdAt.value;
    return !incomingUpdatedAt.isBefore(localUpdatedAt);
  }

  Future<void> _syncSingleRescueStation(RescueStation station) async {
    final ref = _firestore
        .collection(_Collections.rescueStations)
        .doc(station.id);
    await ref.set(_rescueStationToFirestore(station), SetOptions(merge: true));

    await (_db.update(
      _db.rescueStations,
    )..where((s) => s.id.equals(station.id))).write(
      RescueStationsCompanion(
        syncStatus: const Value('synced'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PRIVATE — Serialisation helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _checkInLogToFirestore(CheckInLog log) => {
    'id': log.id,
    'stationId': log.stationId,
    'userId': log.userId,
    'type': log.type,
    'timestamp': Timestamp.fromDate(log.timestamp),
    'syncStatus': 'synced',
    'uploadedAt': FieldValue.serverTimestamp(),
  };

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

  Map<String, dynamic> _rescueStationToFirestore(RescueStation s) => {
    'id': s.id,
    'name': s.name,
    'latitude': s.latitude,
    'longitude': s.longitude,
    'address': s.address,
    'contactPhone': s.contactPhone,
    'capacity': s.capacity,
    'occupancy': s.occupancy,
    'resourcesJson': s.resourcesJson,
    'status': s.status,
    'createdAt': Timestamp.fromDate(s.createdAt),
    'updatedAt': Timestamp.fromDate(s.updatedAt ?? s.createdAt),
    'deletedAt': s.deletedAt == null ? null : Timestamp.fromDate(s.deletedAt!),
    'syncStatus': 'synced',
  };

  Map<String, dynamic> _communityReportToFirestore(CommunityReport r) => {
    'id': r.id,
    'type': r.type,
    'customTypeName': r.customTypeName,
    'latitude': r.latitude,
    'longitude': r.longitude,
    'description': r.description,
    'reportedBy': r.reportedBy,
    'createdAt': Timestamp.fromDate(r.createdAt),
    'syncStatus': 'synced',
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

  RescueStationsCompanion _firestoreToRescueStationCompanion({
    required String docId,
    required Map<String, dynamic> data,
  }) {
    final now = DateTime.now();

    final rawCreatedAt = data['createdAt'];
    final rawUpdatedAt = data['updatedAt'];
    final rawDeletedAt = data['deletedAt'];

    final createdAt = rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : now;
    final updatedAt = rawUpdatedAt is Timestamp
        ? rawUpdatedAt.toDate()
        : createdAt;
    final deletedAt = rawDeletedAt is Timestamp ? rawDeletedAt.toDate() : null;

    final rawLat = data['latitude'];
    final rawLng = data['longitude'];
    if (rawLat is! num || rawLng is! num) {
      throw const FormatException(
        'Rescue station thiếu latitude/longitude hợp lệ.',
      );
    }

    final rawResources = data['resourcesJson'];
    String resourcesJson;
    if (rawResources == null) {
      resourcesJson = '{}';
    } else if (rawResources is String) {
      resourcesJson = rawResources;
    } else {
      resourcesJson = jsonEncode(rawResources);
    }

    return RescueStationsCompanion.insert(
      id: docId,
      name: ((data['name'] as String?)?.trim().isNotEmpty ?? false)
          ? (data['name'] as String).trim()
          : '(Chưa đặt tên trạm)',
      latitude: rawLat.toDouble(),
      longitude: rawLng.toDouble(),
      address: Value((data['address'] as String?)?.trim()),
      contactPhone: Value((data['contactPhone'] as String?)?.trim()),
      capacity: Value((data['capacity'] as num?)?.toInt()),
      occupancy: Value((data['occupancy'] as num?)?.toInt() ?? 0),
      resourcesJson: Value(resourcesJson),
      status: Value(
        ((data['status'] as String?)?.trim().isNotEmpty ?? false)
            ? (data['status'] as String).trim()
            : 'active',
      ),
      createdAt: createdAt,
      updatedAt: Value(updatedAt),
      deletedAt: Value(deletedAt),
      syncStatus: const Value('synced'),
    );
  }

  CommunityReportsCompanion _firestoreToCommunityReportCompanion({
    required String docId,
    required Map<String, dynamic> data,
  }) {
    final now = DateTime.now();

    final rawCreatedAt = data['createdAt'];
    final createdAt = rawCreatedAt is Timestamp ? rawCreatedAt.toDate() : now;

    final rawLat = data['latitude'];
    final rawLng = data['longitude'];
    if (rawLat is! num || rawLng is! num) {
      throw const FormatException(
        'CommunityReport thiếu latitude/longitude hợp lệ.',
      );
    }

    return CommunityReportsCompanion.insert(
      id: docId,
      type: (data['type'] as String?)?.trim() ?? 'other',
      customTypeName: Value((data['customTypeName'] as String?)?.trim()),
      latitude: rawLat.toDouble(),
      longitude: rawLng.toDouble(),
      description: Value((data['description'] as String?)?.trim()),
      reportedBy: (data['reportedBy'] as String?)?.trim() ?? '',
      createdAt: createdAt,
      syncStatus: const Value('synced'),
    );
  }

  UsersCompanion _firestoreToUserCompanion({
    required String docId,
    required Map<String, dynamic> data,
  }) {
    final uid = ((data['uid'] as String?)?.trim().isNotEmpty ?? false)
        ? (data['uid'] as String).trim()
        : docId;

    final createdAt = _asDateTime(data['createdAt']) ?? DateTime.now();
    final updatedAt = _asDateTime(data['updatedAt']) ?? createdAt;
    final lastLoginAt = _asDateTime(data['lastLoginAt']);
    final resolvedPhotoUrl = (data['photoUrl'] as String?)?.trim();

    return UsersCompanion.insert(
      id: uid,
      uid: uid,
      email: ((data['email'] as String?) ?? '').trim(),
      displayName: ((data['displayName'] as String?) ?? '').trim(),
      photoUrl: Value(resolvedPhotoUrl),
      role: _asInt(data['role'], 3),
      status: _asInt(data['status'], 2),
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: Value((data['createdBy'] as String?)?.trim()),
      lastLoginAt: Value(lastLoginAt),
      mfaEnabled: Value((data['mfaEnabled'] as bool?) ?? false),
    );
  }

  PostsCompanion _firestoreToPostCompanion(String docId, Map<String, dynamic> data) {
    final createdAt = _asDateTime(data['createdAt']) ?? DateTime.now();

    return PostsCompanion.insert(
      id: docId,
      eventId: (data['eventId'] as String?) ?? '',
      userId: (data['userId'] as String?) ?? '',
      postType: (data['postType'] as String?) ?? 'sos',
      title: Value((data['title'] as String?)?.trim()),
      attachmentUrl: Value((data['attachmentUrl'] as String?)?.trim()),
      attachmentName: Value((data['attachmentName'] as String?)?.trim()),
      content: (data['content'] as String?) ?? '',
      isVerified: Value((data['isVerified'] as bool?) ?? false),
      createdAt: createdAt,
      syncStatus: const Value('synced'),
    );
  }

  LocationsCompanion _firestoreToLocationCompanion(String docId, Map<String, dynamic> data, String postId) {
    final rawLat = data['latitude'];
    final rawLng = data['longitude'];

    return LocationsCompanion.insert(
      id: docId,
      postId: (data['postId'] as String?) ?? postId,
      latitude: (rawLat as num?)?.toDouble() ?? 0.0,
      longitude: (rawLng as num?)?.toDouble() ?? 0.0,
      addressText: Value((data['addressText'] as String?)?.trim()),
    );
  }

  CheckInLogsCompanion _firestoreToCheckInLogCompanion(String docId, Map<String, dynamic> data) {
    final timestamp = _asDateTime(data['timestamp']) ?? DateTime.now();

    return CheckInLogsCompanion.insert(
      id: docId,
      stationId: (data['stationId'] as String?) ?? '',
      userId: (data['userId'] as String?) ?? '',
      type: (data['type'] as String?) ?? 'in',
      timestamp: timestamp,
      syncStatus: const Value('synced'),
    );
  }

  Map<String, dynamic> _eventDamageStatsToFirestore(EventDamageStat stat) => {
        'id': stat.id,
        'eventId': stat.eventId,
        'deaths': stat.deaths,
        'missing': stat.missing,
        'injured': stat.injured,
        'damagedHouses': stat.damagedHouses,
        'propertyDamage': stat.propertyDamage,
        'reportedAt': Timestamp.fromDate(stat.reportedAt),
        'reportedBy': stat.reportedBy,
        'syncStatus': 'synced',
      };

  EventDamageStatsCompanion _firestoreToEventDamageStatsCompanion({
    required String docId,
    required String eventId,
    required Map<String, dynamic> data,
  }) {
    final reportedAt = _asDateTime(data['reportedAt']) ?? DateTime.now();

    return EventDamageStatsCompanion.insert(
      id: docId,
      eventId: eventId,
      deaths: Value(_asInt(data['deaths'], 0)),
      missing: Value(_asInt(data['missing'], 0)),
      injured: Value(_asInt(data['injured'], 0)),
      damagedHouses: Value(_asInt(data['damagedHouses'], 0)),
      propertyDamage: Value((data['propertyDamage'] as num?)?.toDouble() ?? 0.0),
      reportedAt: reportedAt,
      reportedBy: (data['reportedBy'] as String?) ?? '',
      syncStatus: const Value('synced'),
    );
  }

  // ---------------------------------------------------------------------------
  // PRIVATE — Utilities
  // ---------------------------------------------------------------------------

  Future<bool> _isConnected() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String && value.trim().isNotEmpty) {
      return int.tryParse(value.trim()) ?? fallback;
    }
    return fallback;
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
  return service.startSync();
});
