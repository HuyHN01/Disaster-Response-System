import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/db_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/firebase/sync_service.dart';

final damageStatsRepositoryProvider = Provider<DamageStatsRepository>((ref) {
  final db = ref.watch(dbProvider);
  final syncService = ref.watch(firebaseSyncServiceProvider);
  return DamageStatsRepository(db, syncService);
});

final latestDamageStatProvider = StreamProvider.family<EventDamageStat?, String>((ref, eventId) {
  final repo = ref.watch(damageStatsRepositoryProvider);
  return repo.watchLatestStat(eventId);
});

final damageStatHistoryProvider = StreamProvider.family<List<EventDamageStat>, String>((ref, eventId) {
  final repo = ref.watch(damageStatsRepositoryProvider);
  return repo.watchStatHistory(eventId);
});

class DamageStatsRepository {
  final AppDatabase _db;
  final FirebaseSyncService _sync;
  final _uuid = const Uuid();

  DamageStatsRepository(this._db, this._sync);

  Stream<EventDamageStat?> watchLatestStat(String eventId) {
    return (_db.select(_db.eventDamageStats)
          ..where((s) => s.eventId.equals(eventId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.reportedAt, mode: OrderingMode.desc)
          ])
          ..limit(1))
        .watchSingleOrNull();
  }

  Stream<List<EventDamageStat>> watchStatHistory(String eventId) {
    return (_db.select(_db.eventDamageStats)
          ..where((s) => s.eventId.equals(eventId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.reportedAt, mode: OrderingMode.desc)
          ]))
        .watch();
  }

  Future<void> insertStat({
    required String eventId,
    required int deaths,
    required int missing,
    required int injured,
    required int damagedHouses,
    required double propertyDamage,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Unauthenticated user cannot report damage stats');
    }

    final newStat = EventDamageStatsCompanion.insert(
      id: _uuid.v4(),
      eventId: eventId,
      deaths: Value(deaths),
      missing: Value(missing),
      injured: Value(injured),
      damagedHouses: Value(damagedHouses),
      propertyDamage: Value(propertyDamage),
      reportedAt: DateTime.now(),
      reportedBy: user.uid,
      syncStatus: const Value('pending'),
    );

    // Insert to drift
    await _db.into(_db.eventDamageStats).insert(newStat);

    // Trigger sync
    _sync.syncPendingEventDamageStats();
  }
}
