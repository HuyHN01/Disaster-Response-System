// lib/features/admin_panel/rescue_stations/domain/rescue_station_controller.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:disaster_response_app/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'rescue_station_repository.dart';

class RescueStationController extends AsyncNotifier<List<RescueStation>> {
  RescueStationRepository get _repo =>
      ref.read(rescueStationRepositoryProvider);
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  @override
  Future<List<RescueStation>> build() {
    return _repo.getAllStations();
  }

  Future<void> loadStations() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repo.getAllStations);
  }

  Future<void> createStation({
    required String name,
    required double latitude,
    required double longitude,
    String? address,
    String? contactPhone,
    int? capacity,
    String resourcesJson = '{}',
    String status = 'active',
  }) async {
    final now = DateTime.now();
    final id = DateTime.now().microsecondsSinceEpoch.toString();

    await _repo.upsert(
      RescueStationsCompanion.insert(
        id: id,
        name: name,
        latitude: latitude,
        longitude: longitude,
        address: Value(address),
        contactPhone: Value(contactPhone),
        capacity: Value(capacity),
        resourcesJson: Value(resourcesJson),
        status: Value(status),
        createdAt: now,
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ),
    );

    await loadStations();

    try {
      final local = await _repo.getById(id);
      if (local != null) {
        await _pushStationToFirestore(local);
        await _repo.markSynced(id, DateTime.now());
        await loadStations();
      }
    } catch (e) {
      throw Exception('Đã lưu offline, sẽ đồng bộ khi có mạng. ($e)');
    }
  }

  Future<void> updateStation({
    required String id,
    required String name,
    required double latitude,
    required double longitude,
    String? address,
    String? contactPhone,
    int? capacity,
    String resourcesJson = '{}',
    String status = 'active',
  }) async {
    final now = DateTime.now();
    final existing = await _repo.getById(id);

    if (existing == null) {
      throw Exception('Không tìm thấy trạm cứu hộ để cập nhật.');
    }

    await _repo.upsert(
      RescueStationsCompanion(
        id: Value(id),
        name: Value(name),
        latitude: Value(latitude),
        longitude: Value(longitude),
        address: Value(address),
        contactPhone: Value(contactPhone),
        capacity: Value(capacity),
        resourcesJson: Value(resourcesJson),
        status: Value(status),
        createdAt: Value(existing.createdAt),
        updatedAt: Value(now),
        syncStatus: const Value('pending'),
      ),
    );

    await loadStations();

    try {
      final local = await _repo.getById(id);
      if (local != null) {
        await _pushStationToFirestore(local);
        await _repo.markSynced(id, DateTime.now());
        await loadStations();
      }
    } catch (e) {
      throw Exception('Đã cập nhật offline, sẽ đồng bộ khi có mạng. ($e)');
    }
  }

  Future<void> softDeleteStation(String id) async {
    final now = DateTime.now();

    await _repo.softDeletePending(id, now);
    await loadStations();

    try {
      await _firestore.collection('rescue_stations').doc(id).set({
        'status': 'inactive',
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _repo.markSynced(id, DateTime.now());
      await loadStations();
    } catch (e) {
      throw Exception('Đã đánh dấu xóa offline, sẽ đồng bộ khi có mạng. ($e)');
    }
  }

  Future<void> _pushStationToFirestore(RescueStation station) {
    return _firestore.collection('rescue_stations').doc(station.id).set({
      'id': station.id,
      'name': station.name,
      'latitude': station.latitude,
      'longitude': station.longitude,
      'address': station.address,
      'contactPhone': station.contactPhone,
      'capacity': station.capacity,
      'resourcesJson': station.resourcesJson,
      'status': station.status,
      'createdAt': Timestamp.fromDate(station.createdAt),
      'updatedAt': Timestamp.fromDate(station.updatedAt ?? station.createdAt),
      'deletedAt': station.deletedAt == null
          ? null
          : Timestamp.fromDate(station.deletedAt!),
      'syncStatus': 'synced',
    }, SetOptions(merge: true));
  }
}

final rescueStationControllerProvider =
    AsyncNotifierProvider<RescueStationController, List<RescueStation>>(
      RescueStationController.new,
    );

final activeRescueStationCountProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(rescueStationRepositoryProvider);
  return repo.watchActiveStations().map((rows) => rows.length);
});
