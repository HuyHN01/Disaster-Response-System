import 'package:disaster_response_app/core/database/app_database.dart';
import 'package:disaster_response_app/core/database/db_provider.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// =============================================================================
// REPOSITORY (Làm việc trực tiếp với Drift)
// =============================================================================
class EventRepository {
  final AppDatabase _db;
  EventRepository(this._db);

  // Lấy toàn bộ sự kiện theo thứ tự mới nhất
  Future<List<DisasterEvent>> getAllEvents() async {
    return await (_db.select(
      _db.disasterEvents,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  }

  // Thêm một sự kiện mới (Hàm này dùng cho nút "+ Sự kiện mới" sau này)
  Future<int> addEvent(DisasterEventsCompanion event) async {
    return await _db.into(_db.disasterEvents).insert(event);
  }
}

// Cung cấp Repository
final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(ref.watch(dbProvider));
});

// =============================================================================
// CONTROLLER (Quản lý trạng thái cho UI) — dùng AsyncNotifier (Riverpod 3)
// =============================================================================
class EventController extends AsyncNotifier<List<DisasterEvent>> {
  @override
  Future<List<DisasterEvent>> build() async {
    final repo = ref.read(eventRepositoryProvider);
    final events = await repo.getAllEvents();
    if (events.isEmpty) {
      await _seedDummyData(repo);
      return await repo.getAllEvents();
    }
    return events;
  }

  /// Gọi từ UI khi cần refresh danh sách sự kiện
  Future<void> loadEvents() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(eventRepositoryProvider);
      final events = await repo.getAllEvents();
      if (events.isEmpty) {
        await _seedDummyData(repo);
        return await repo.getAllEvents();
      }
      return events;
    });
  }

  Future<void> createNewEvent(String title, String eventType) async {
    try {
      final repo = ref.read(eventRepositoryProvider);

      // Dùng timestamp làm ID tạm thời để đơn giản hóa
      final newId = DateTime.now().millisecondsSinceEpoch.toString();

      await repo.addEvent(
        DisasterEventsCompanion.insert(
          id: newId,
          title: title,
          eventType: eventType,
          status: 'active', // Mặc định sự kiện mới là Đang hoạt động
          createdAt: DateTime.now(),
          createdBy: 'admin',
        ),
      );

      // Load lại danh sách sau khi thêm thành công
      await loadEvents();
    } catch (e) {
      // Trong thực tế sẽ show Snackbar báo lỗi, tạm thời print ra console
      print("Lỗi khi tạo sự kiện: $e");
    }
  }

  // Hàm tạo dữ liệu giả để test (chỉ chạy 1 lần khi DB trống)
  Future<void> _seedDummyData(EventRepository repo) async {
    final now = DateTime.now();
    await repo.addEvent(
      DisasterEventsCompanion.insert(
        id: '1',
        title: 'Bão số 3 Yagi',
        eventType: 'typhoon',
        status: 'active',
        createdAt: now,
        createdBy: 'admin',
      ),
    );
    await repo.addEvent(
      DisasterEventsCompanion.insert(
        id: '2',
        title: 'Lũ lụt miền Trung',
        eventType: 'flood',
        status: 'active',
        createdAt: now.subtract(const Duration(days: 1)),
        createdBy: 'admin',
      ),
    );
    await repo.addEvent(
      DisasterEventsCompanion.insert(
        id: '3',
        title: 'Sạt lở tại Tây Bắc',
        eventType: 'landslide',
        status: 'resolved',
        createdAt: now.subtract(const Duration(days: 3)),
        createdBy: 'admin',
      ),
    );
  }
}

// Cung cấp Controller ra UI
final eventControllerProvider =
    AsyncNotifierProvider<EventController, List<DisasterEvent>>(
      EventController.new,
    );
