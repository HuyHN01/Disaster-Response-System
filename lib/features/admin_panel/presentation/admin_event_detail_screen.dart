// lib/features/admin_panel/presentation/admin_event_detail_screen.dart

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:disaster_response_app/core/database/app_database.dart';
import 'package:disaster_response_app/features/admin_panel/domain/event_controller.dart';
import 'package:disaster_response_app/features/admin_panel/presentation/admin_post_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

// =============================================================================
// THEME TOKENS (local — mirrors AppColors)
// =============================================================================
class _DC {
  static const Color bg = Color(0xFFF4F6F9);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color brandRed = Color(0xFFDC2626);
  static const Color brandRedBg = Color(0xFFFEE2E2);
  static const Color green = Color(0xFF16A34A);
  static const Color greenBg = Color(0xFFDCFCE7);
  static const Color amber = Color(0xFFD97706);
  static const Color amberBg = Color(0xFFFEF3C7);
  static const Color shadow = Color(0x0A000000);
}

// =============================================================================
// MODEL — bài đăng được join từ Firestore
// =============================================================================
class AdminPost {
  final String id;
  final String eventId;
  final String postType; // 'news' | 'directive'
  final String title;
  final String contentJson; // Quill Delta JSON string
  final String? attachmentUrl;
  final String? attachmentName;
  final DateTime createdAt;
  final bool isVerified;

  const AdminPost({
    required this.id,
    required this.eventId,
    required this.postType,
    required this.title,
    required this.contentJson,
    this.attachmentUrl,
    this.attachmentName,
    required this.createdAt,
    required this.isVerified,
  });

  factory AdminPost.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final rawTs = d['createdAt'];
    return AdminPost(
      id: doc.id,
      eventId: (d['eventId'] as String?) ?? '',
      postType: (d['postType'] as String?) ?? 'news',
      title: (d['title'] as String?) ?? '(Không có tiêu đề)',
      contentJson: (d['content'] as String?) ?? '{"ops":[{"insert":"\\n"}]}',
      attachmentUrl: d['attachmentUrl'] as String?,
      attachmentName: d['attachmentName'] as String?,
      createdAt: rawTs is Timestamp ? rawTs.toDate() : DateTime.now(),
      isVerified: (d['isVerified'] as bool?) ?? false,
    );
  }

  AdminPost copyWith({String? title, String? contentJson, String? postType}) {
    return AdminPost(
      id: id,
      eventId: eventId,
      postType: postType ?? this.postType,
      title: title ?? this.title,
      contentJson: contentJson ?? this.contentJson,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      createdAt: createdAt,
      isVerified: isVerified,
    );
  }
}

// =============================================================================
// PROVIDER — stream realtime bài đăng theo eventId
// =============================================================================

/// Dùng .family để mỗi eventId có state riêng biệt
final adminPostsProvider = StreamNotifierProvider.family<
    AdminPostsController, List<AdminPost>, String>(
  AdminPostsController.new,
);

class AdminPostsController extends StreamNotifier<List<AdminPost>> {

  AdminPostsController(this.arg);
  final String arg;

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  @override
  Stream<List<AdminPost>> build() {
    return _db
        .collection('posts')
        .where('eventId', isEqualTo: arg)
        .where('postType', whereIn: ['news', 'directive'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(AdminPost.fromFirestore).toList());
  }

  // ── Create ────────────────────────────────────────────────────────────────
  Future<void> createPost({
    required String title,
    required String postType,
    required String contentJson,
    String? attachmentUrl,
    String? attachmentName,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await _db.collection('posts').doc(id).set({
      'id': id,
      'eventId': arg, // arg = eventId từ .family
      'userId': 'admin',
      'postType': postType,
      'title': title,
      'content': contentJson,
      'attachmentUrl': attachmentUrl,
      'attachmentName': attachmentName,
      'isVerified': true,
      'syncStatus': 'synced',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Update ────────────────────────────────────────────────────────────────
  Future<void> updatePost({
    required String postId,
    required String title,
    required String postType,
    required String contentJson,
    String? attachmentUrl,
    String? attachmentName,
  }) async {
    await _db.collection('posts').doc(postId).update({
      'title': title,
      'postType': postType,
      'content': contentJson,
      'attachmentUrl': attachmentUrl,
      'attachmentName': attachmentName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  Future<void> deletePost(String postId) async {
    await _db.collection('posts').doc(postId).delete();
  }
}

// =============================================================================
// UTILITY — parse Quill Delta JSON sang plain text ngắn gọn
// =============================================================================

/// Trích xuất văn bản thuần từ Delta JSON của Quill.
/// Mỗi op `{"insert": "..."}` đóng góp text; image embed hiện là "[Ảnh]".
String quillJsonToPlainText(String jsonStr, {int maxChars = 120}) {
  try {
    final delta = jsonDecode(jsonStr) as Map<String, dynamic>;
    final ops = delta['ops'] as List<dynamic>? ?? [];
    final buffer = StringBuffer();
    for (final op in ops) {
      if (op is Map) {
        final insert = op['insert'];
        if (insert is String) {
          buffer.write(insert);
        } else if (insert is Map) {
          buffer.write('[Ảnh] ');
        }
      }
    }
    final text = buffer.toString().replaceAll('\n', ' ').trim();
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars)}...';
  } catch (_) {
    // content không phải JSON hợp lệ — hiển thị thô
    final raw = jsonStr.replaceAll('\n', ' ').trim();
    return raw.length > maxChars ? '${raw.substring(0, maxChars)}...' : raw;
  }
}

// =============================================================================
// MAIN SCREEN
// =============================================================================
class AdminEventDetailScreen extends ConsumerWidget {
  final DisasterEvent event;

  const AdminEventDetailScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(adminPostsProvider(event.id));

    return Scaffold(
      backgroundColor: _DC.bg,
      body: Column(
        children: [
          _Header(event: event, ref: ref),
          Expanded(
            child: postsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (e, _) => _ErrorState(message: e.toString()),
              data: (posts) => posts.isEmpty
                  ? const _EmptyState()
                  : _PostList(posts: posts, event: event),
            ),
          ),
        ],
      ),
      floatingActionButton: _WriteFab(event: event),
    );
  }
}

// =============================================================================
// HEADER
// =============================================================================
class _Header extends StatelessWidget {
  final DisasterEvent event;
  final WidgetRef ref;

  const _Header({required this.event, required this.ref});

  String get _statusLabel =>
      event.status == 'active' ? 'Đang hoạt động' : 'Đã kết thúc';

  Color get _statusColor =>
      event.status == 'active' ? _DC.brandRed : _DC.textMuted;

  Color get _statusBg =>
      event.status == 'active' ? _DC.brandRedBg : const Color(0xFFF3F4F6);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _DC.cardBg,
        border: Border(bottom: BorderSide(color: _DC.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Row(
        children: [
          // Back button
          InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: const Icon(Icons.arrow_back_rounded,
                  size: 20, color: _DC.textSecondary),
            ),
          ),
          const SizedBox(width: 12),

          // Event icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _DC.brandRedBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: _DC.brandRed, size: 22),
          ),
          const SizedBox(width: 14),

          // Title + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    color: _DC.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabel,
                        style: TextStyle(
                          color: _statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ID: ${event.id}',
                      style: const TextStyle(
                        color: _DC.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Close event button (only if active)
          if (event.status == 'active')
            OutlinedButton.icon(
              onPressed: () => _confirmCloseEvent(context, ref),
              icon: const Icon(Icons.lock_outline_rounded,
                  size: 16, color: _DC.textSecondary),
              label: const Text(
                'Đóng sự kiện',
                style: TextStyle(
                  color: _DC.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _DC.border),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmCloseEvent(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đóng sự kiện?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'Sự kiện "${event.title}" sẽ được chuyển sang trạng thái "Đã kết thúc". '
          'Hành động này không thể hoàn tác.',
          style: const TextStyle(color: _DC.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Huỷ',
                style: TextStyle(color: _DC.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await FirebaseFirestore.instance
                    .collection('disaster_events')
                    .doc(event.id)
                    .update({'status': 'resolved'});
                // Also refresh local event list
                await ref.read(eventControllerProvider.notifier).loadEvents();
                if (context.mounted) Navigator.of(context).maybePop();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi: $e'),
                      backgroundColor: _DC.brandRed,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _DC.brandRed,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Đóng sự kiện',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// POST LIST
// =============================================================================
class _PostList extends StatelessWidget {
  final List<AdminPost> posts;
  final DisasterEvent event;

  const _PostList({required this.posts, required this.event});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(28),
      itemCount: posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _PostCard(post: posts[i], event: event),
    );
  }
}

// =============================================================================
// POST CARD
// =============================================================================
class _PostCard extends ConsumerWidget {
  final AdminPost post;
  final DisasterEvent event;

  const _PostCard({required this.post, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDirective = post.postType == 'directive';
    final badgeColor = isDirective ? _DC.amber : _DC.green;
    final badgeBg = isDirective ? _DC.amberBg : _DC.greenBg;
    final badgeLabel = isDirective ? 'Công điện' : 'Tin tức';
    final snippet = quillJsonToPlainText(post.contentJson);
    final dateStr =
        DateFormat('HH:mm – dd/MM/yyyy').format(post.createdAt.toLocal());

    return Container(
      decoration: BoxDecoration(
        color: _DC.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _DC.border),
        boxShadow: const [
          BoxShadow(color: _DC.shadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openEditor(context, ref, post),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row 1: Badge + Attachment icon + Actions ─────────────
              Row(
                children: [
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Attachment icon
                  if (post.attachmentUrl != null) ...[
                    const Icon(Icons.attach_file_rounded,
                        size: 15, color: _DC.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      post.attachmentName ?? 'Tệp đính kèm',
                      style: const TextStyle(
                        color: _DC.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  const Spacer(),

                  // Date
                  Text(
                    dateStr,
                    style: const TextStyle(
                      color: _DC.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Action buttons
                  _ActionButton(
                    icon: Icons.edit_rounded,
                    label: 'Chỉnh sửa',
                    onTap: () => _openEditor(context, ref, post),
                  ),
                  const SizedBox(width: 6),
                  _ActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: 'Xóa',
                    isDestructive: true,
                    onTap: () => _confirmDelete(context, ref),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Row 2: Title ──────────────────────────────────────────
              Text(
                post.title,
                style: const TextStyle(
                  color: _DC.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              // ── Row 3: Content snippet ────────────────────────────────
              Text(
                snippet.isEmpty ? '(Chưa có nội dung)' : snippet,
                style: const TextStyle(
                  color: _DC.textSecondary,
                  fontSize: 13,
                  height: 1.55,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openEditor(BuildContext ctx, WidgetRef ref, AdminPost post) {
    Navigator.of(ctx).push(MaterialPageRoute(
      builder: (_) => AdminPostEditorScreen(
        event: event,
        existingPost: post,
      ),
    ));
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xoá bài đăng?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(
          'Bài đăng "${post.title}" sẽ bị xoá vĩnh viễn.',
          style: const TextStyle(color: _DC.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Huỷ',
                style: TextStyle(color: _DC.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ref
                    .read(adminPostsProvider(post.eventId).notifier)
                    .deletePost(post.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Lỗi xoá bài: $e'),
                    backgroundColor: _DC.brandRed,
                  ));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _DC.brandRed,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Xoá', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// WRITE FAB
// =============================================================================
class _WriteFab extends StatelessWidget {
  final DisasterEvent event;
  const _WriteFab({required this.event});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AdminPostEditorScreen(event: event),
        ));
      },
      backgroundColor: _DC.brandRed,
      icon: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 22),
      label: const Text(
        'Viết bản tin / Công điện',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 4,
    );
  }
}

// =============================================================================
// HELPERS
// =============================================================================
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? _DC.brandRed : _DC.textSecondary;
    final bg = isDestructive ? _DC.brandRedBg : const Color(0xFFF3F4F6);

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _DC.brandRedBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.article_outlined,
                color: _DC.brandRed, size: 36),
          ),
          const SizedBox(height: 20),
          const Text(
            'Chưa có bản tin nào',
            style: TextStyle(
              color: _DC.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nhấn nút "+ Viết bản tin" để tạo thông báo đầu tiên.',
            style: TextStyle(color: _DC.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Lỗi: $message',
          style: const TextStyle(color: _DC.brandRed, fontSize: 14)),
    );
  }
}