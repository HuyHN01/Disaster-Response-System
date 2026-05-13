// lib/features/admin_panel/domain/event_controller.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:disaster_response_app/core/database/app_database.dart';
import 'package:disaster_response_app/core/database/db_provider.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// =============================================================================
// REPOSITORY — làm việc trực tiếp với Drift (Local DB)
// =============================================================================
class EventRepository {
  final AppDatabase _db;
  EventRepository(this._db);

  /// Lấy toàn bộ sự kiện, mới nhất lên trước
  Future<List<DisasterEvent>> getAllEvents() async {
    return (_db.select(_db.disasterEvents)
          ..where(
            (t) =>
                t.status.equals('inactive').not() &
                t.status.equals('unactive').not(),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Thêm / cập nhật một sự kiện vào local DB
  Future<void> addEvent(DisasterEventsCompanion event) async {
    await _db
        .into(_db.disasterEvents)
        .insertOnConflictUpdate(event);
  }

  Future<void> updateEventFields({
    required String eventId,
    required String title,
    required String eventType,
  }) async {
    await (_db.update(_db.disasterEvents)..where((e) => e.id.equals(eventId)))
        .write(
      DisasterEventsCompanion(
        title: Value(title),
        eventType: Value(eventType),
      ),
    );
  }

  Future<void> updateEventStatus({
    required String eventId,
    required String status,
  }) async {
    await (_db.update(_db.disasterEvents)..where((e) => e.id.equals(eventId)))
        .write(
      DisasterEventsCompanion(
        status: Value(status),
      ),
    );
  }
}

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(ref.watch(dbProvider));
});

// =============================================================================
// CONTROLLER — quản lý trạng thái cho UI
// =============================================================================
class EventController extends AsyncNotifier<List<DisasterEvent>> {
  // Lazy getter — tránh gọi ref.read bên ngoài lifecycle của notifier
  EventRepository get _repository => ref.read(eventRepositoryProvider);
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static const String _statusActive = 'active';
  static const String _statusInactive = 'inactive';

  // ---------------------------------------------------------------------------
  // INIT
  // ---------------------------------------------------------------------------
  @override
  Future<List<DisasterEvent>> build() async {
    return _repository.getAllEvents();
  }

  // ---------------------------------------------------------------------------
  // LOAD / REFRESH
  // ---------------------------------------------------------------------------

  /// Refresh danh sách từ local DB (source of truth).
  /// Gọi sau mỗi thao tác write để UI phản ánh state mới nhất.
  Future<void> loadEvents() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repository.getAllEvents);
  }

  // ---------------------------------------------------------------------------
  // CREATE — offline-first + Firebase sync
  // ---------------------------------------------------------------------------

  /// Tạo một sự kiện thiên tai mới:
  /// 1. Ghi lên Firestore (source of truth cho admin web).
  /// 2. Ghi vào Drift local DB (offline-first, mobile app đọc từ đây).
  /// 3. Refresh UI.
  ///
  /// Nếu Firestore thất bại, local write vẫn được thực hiện (pending sync).
  /// Nếu local write thất bại, ném exception để UI xử lý.
  Future<void> createNewEvent(String title, String eventType) async {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();

    // ── Bước 1: Firestore (best-effort — không block local write nếu lỗi) ──
    String? firestoreError;
    try {
      await _firestore
          .collection('disaster_events')
          .doc(newId)
          .set({
        'id': newId,
        'title': title,
        'eventType': eventType,
        'status': _statusActive,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': 'admin',
      });
    } catch (e) {
      // Ghi chú lỗi nhưng tiếp tục — offline-first
      firestoreError = e.toString();
      _log('Firestore write failed (will retry via sync): $firestoreError');
    }

    // ── Bước 2: Local DB — bắt buộc phải thành công ─────────────────────
    await _repository.addEvent(
      DisasterEventsCompanion.insert(
        id: newId,
        title: title,
        eventType: eventType,
        status: _statusActive,
        createdAt: now,
        createdBy: 'admin',
      ),
    );

    // ── Bước 3: Cập nhật UI ──────────────────────────────────────────────
    await loadEvents();

    // Nếu Firestore lỗi, ném exception để UI hiển thị cảnh báo offline
    if (firestoreError != null) {
      throw Exception(
        'Đã lưu offline. Sẽ đồng bộ khi có kết nối.\n($firestoreError)',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // UPDATE
  // ---------------------------------------------------------------------------

  Future<void> updateEvent({
    required String eventId,
    required String title,
    required String eventType,
  }) async {
    await _firestore.collection('disaster_events').doc(eventId).update({
      'title': title,
      'eventType': eventType,
    });

    await _repository.updateEventFields(
      eventId: eventId,
      title: title,
      eventType: eventType,
    );

    await loadEvents();
  }

  // ---------------------------------------------------------------------------
  // SOFT DELETE
  // ---------------------------------------------------------------------------

  Future<void> softDeleteEvent(String eventId) async {
    await _firestore.collection('disaster_events').doc(eventId).update({
      'status': _statusInactive,
    });

    await _repository.updateEventStatus(
      eventId: eventId,
      status: _statusInactive,
    );

    await loadEvents();
  }

  // ignore: avoid_print
  void _log(String msg) => print('[EventController] $msg');
}

// =============================================================================
// PROVIDERS
// =============================================================================

final eventControllerProvider =
    AsyncNotifierProvider<EventController, List<DisasterEvent>>(
  EventController.new,
);