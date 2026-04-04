// lib/features/rescue_stations/domain/rescue_station_repository.dart

import 'package:disaster_response_app/core/database/app_database.dart';
import 'package:disaster_response_app/core/database/db_provider.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RescueStationRepository {
  final AppDatabase _db;
  RescueStationRepository(this._db);

  Future<List<RescueStation>> getAllStations({bool includeDeleted = false}) {
    final query = _db.select(_db.rescueStations)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);

    if (!includeDeleted) {
      query.where((t) => t.deletedAt.isNull());
    }

    return query.get();
  }

  Stream<List<RescueStation>> watchAllStations({bool includeDeleted = false}) {
    final query = _db.select(_db.rescueStations)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);

    if (!includeDeleted) {
      query.where((t) => t.deletedAt.isNull());
    }

    return query.watch();
  }

  Stream<List<RescueStation>> watchActiveStations() {
    return (_db.select(_db.rescueStations)
          ..where((t) => t.deletedAt.isNull() & t.status.equals('active'))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Future<RescueStation?> getById(String id) {
    return (_db.select(
      _db.rescueStations,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsert(RescueStationsCompanion station) async {
    await _db.into(_db.rescueStations).insertOnConflictUpdate(station);
  }

  Future<void> markSynced(String id, DateTime updatedAt) async {
    await (_db.update(_db.rescueStations)..where((t) => t.id.equals(id))).write(
      RescueStationsCompanion(
        syncStatus: const Value('synced'),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  Future<void> softDeletePending(String id, DateTime now) async {
    await (_db.update(_db.rescueStations)..where((t) => t.id.equals(id))).write(
      RescueStationsCompanion(
        status: const Value('inactive'),
        deletedAt: Value(now),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ),
    );
  }
}

final rescueStationRepositoryProvider = Provider<RescueStationRepository>((
  ref,
) {
  return RescueStationRepository(ref.watch(dbProvider));
});
