// lib/features/admin_panel/rescue_stations/domain/rescue_station_repository.dart

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
          ..where(
            (t) =>
                t.deletedAt.isNull() &
                (t.status.equals('active') | t.status.equals('full')),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Stream<List<RescueStation>> watchActiveStationsByEvent(String eventId) {
    return (_db.select(_db.rescueStations)
          ..where(
            (t) =>
                t.deletedAt.isNull() &
                (t.status.equals('active') | t.status.equals('full')) &
                t.eventId.equals(eventId),
          )
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

  Future<void> updateOccupancy(String id, int delta) async {
    final station = await getById(id);
    if (station == null) return;
    
    final currentOccupancy = station.occupancy;
    final newOccupancy = (currentOccupancy + delta) < 0 ? 0 : (currentOccupancy + delta);
    
    String newStatus = station.status;
    if (station.capacity != null && newOccupancy >= station.capacity!) {
      newStatus = 'full';
    } else if (station.capacity != null && newOccupancy < station.capacity! && station.status == 'full') {
      newStatus = 'active'; // Revert back to active if it's below capacity
    }

    await (_db.update(_db.rescueStations)..where((t) => t.id.equals(id))).write(
      RescueStationsCompanion(
        occupancy: Value(newOccupancy),
        status: Value(newStatus),
        syncStatus: const Value('pending'),
        updatedAt: Value(DateTime.now()),
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

  Future<CheckInLog> insertCheckInLog({
    required String stationId,
    required String userId,
    required String type,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final log = CheckInLog(
      id: id,
      stationId: stationId,
      userId: userId,
      type: type,
      timestamp: DateTime.now(),
      syncStatus: 'pending',
    );
    await _db.into(_db.checkInLogs).insert(log);
    return log;
  }

  Future<CheckInLog?> getLatestCheckInLog() {
    return (_db.select(_db.checkInLogs)
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> markLogSynced(String logId) async {
    await (_db.update(_db.checkInLogs)..where((l) => l.id.equals(logId))).write(
      const CheckInLogsCompanion(syncStatus: Value('synced')),
    );
  }
}

final rescueStationRepositoryProvider = Provider<RescueStationRepository>((
  ref,
) {
  return RescueStationRepository(ref.watch(dbProvider));
});
