// lib/features/citizen_news/domain/citizen_news_controller.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// =============================================================================
// MODEL
// =============================================================================
class CitizenNewsPost {
  final String id;
  final String title;
  final String contentJson; // Quill Delta JSON string
  final String postType;    // 'news' | 'directive'
  final DateTime createdAt;
  final String? attachmentUrl;
  final String? attachmentName;

  const CitizenNewsPost({
    required this.id,
    required this.title,
    required this.contentJson,
    required this.postType,
    required this.createdAt,
    this.attachmentUrl,
    this.attachmentName,
  });

  bool get isDirective => postType == 'directive';

  factory CitizenNewsPost.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final rawTs = d['createdAt'];
    return CitizenNewsPost(
      id: doc.id,
      title: (d['title'] as String?) ?? '(Không có tiêu đề)',
      contentJson:
          (d['content'] as String?) ?? '{"ops":[{"insert":"\\n"}]}',
      postType: (d['postType'] as String?) ?? 'news',
      createdAt:
          rawTs is Timestamp ? rawTs.toDate() : DateTime.now(),
      attachmentUrl: d['attachmentUrl'] as String?,
      attachmentName: d['attachmentName'] as String?,
    );
  }
}

// =============================================================================
// PROVIDER
// =============================================================================

/// Stream realtime tất cả bài đăng loại 'news' và 'directive',
/// sắp xếp mới nhất lên đầu.
///
/// Dùng StreamProvider để UI tự rebuild khi Firestore có dữ liệu mới.
final citizenNewsProvider =
    StreamProvider.autoDispose<List<CitizenNewsPost>>((ref) {
  return FirebaseFirestore.instance
      .collection('posts')
      .where('postType', whereIn: ['news', 'directive'])
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map(_safeParse)
          .whereType<CitizenNewsPost>()
          .toList());
});

/// Lấy 1 bài viết theo id để phục vụ deep-link / push-notification.
Future<CitizenNewsPost?> fetchCitizenNewsPostById(String postId) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .get();

    if (!doc.exists) return null;
    return CitizenNewsPost.fromFirestore(doc);
  } catch (_) {
    return null;
  }
}

/// Parse từng document an toàn — document lỗi không làm crash toàn stream.
CitizenNewsPost? _safeParse(
    DocumentSnapshot<Map<String, dynamic>> doc) {
  try {
    return CitizenNewsPost.fromFirestore(doc);
  } catch (_) {
    return null;
  }
}