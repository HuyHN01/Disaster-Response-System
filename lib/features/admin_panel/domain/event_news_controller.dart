// lib/features/admin_panel/domain/event_news_controller.dart

import 'package:disaster_response_app/core/database/app_database.dart';
import 'package:disaster_response_app/core/database/db_provider.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// =============================================================================
// Lắng nghe danh sách Tin tức/Công điện của một Sự kiện cụ thể
// =============================================================================
final eventNewsProvider = StreamProvider.family<List<Post>, String>((ref, eventId) {
  final db = ref.watch(dbProvider);
  return (db.select(db.posts)
        ..where((p) => p.eventId.equals(eventId) & p.postType.isIn(['news', 'directive']))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch();
});

// =============================================================================
// Controller xử lý hành động (Thêm bài viết)
// =============================================================================
class EventNewsController {
  final AppDatabase db;
  EventNewsController(this.db);

  Future<void> createPost(String eventId, String content, String type) async {
    final postId = DateTime.now().millisecondsSinceEpoch.toString();
    
    await db.into(db.posts).insert(
      PostsCompanion.insert(
        id: postId,
        eventId: eventId,
        userId: 'admin',
        postType: type, // 'news' hoặc 'directive'
        content: content,
        createdAt: DateTime.now(),
        syncStatus: const Value('pending'), // Lưu ý: pending để Sync Service đẩy lên Firebase
      )
    );
  }
  
  // Hàm đóng sự kiện (Đổi status -> resolved)
  Future<void> resolveEvent(String eventId) async {
    await (db.update(db.disasterEvents)..where((e) => e.id.equals(eventId)))
        .write(const DisasterEventsCompanion(status: Value('resolved')));
  }
}

final eventNewsActionProvider = Provider<EventNewsController>((ref) {
  return EventNewsController(ref.watch(dbProvider));
});