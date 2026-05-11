// lib/features/admin_panel/presentation/admin_event_detail_screen.dart

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:disaster_response_app/core/database/app_database.dart';
import 'package:disaster_response_app/features/admin_panel/domain/event_controller.dart';
import 'package:disaster_response_app/features/admin_panel/domain/damage_stats_repository.dart';
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

  // Stat card accent colours
  static const Color sosOrange = Color(0xFFEA580C);
  static const Color sosOrangeBg = Color(0xFFFFF7ED);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueBg = Color(0xFFEFF6FF);
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
  final String? issuingLevel; // 'national' | 'regional' | 'local'

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
    this.issuingLevel,
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
      issuingLevel: d['issuingLevel'] as String?,
    );
  }

  AdminPost copyWith({
    String? title,
    String? contentJson,
    String? postType,
    String? issuingLevel,
  }) {
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
      issuingLevel: issuingLevel ?? this.issuingLevel,
    );
  }
}

// =============================================================================
// MODEL — thống kê SOS theo sự kiện
// =============================================================================

/// Tổng hợp số liệu SOS cho một sự kiện thiên tai.
class EventSosStats {
  /// Tổng số tín hiệu SOS nhận được.
  final int totalSos;

  /// Số tín hiệu SOS chưa được xử lý (isVerified == false).
  final int unverifiedSos;

  const EventSosStats({required this.totalSos, required this.unverifiedSos});

  const EventSosStats.empty() : totalSos = 0, unverifiedSos = 0;
}

// =============================================================================
// PROVIDERS
// =============================================================================

/// Stream realtime bài đăng (news/directive) theo eventId.
/// Dùng .family để mỗi eventId có state riêng biệt.
final adminPostsProvider =
    StreamNotifierProvider.family<
      AdminPostsController,
      List<AdminPost>,
      String
    >(AdminPostsController.new);

/// Stream realtime thống kê SOS theo eventId.
///
/// Lắng nghe collection `posts` với:
///   • `eventId == arg`
///   • `postType == 'sos'`
///
/// Tự động tính lại `totalSos` / `unverifiedSos` mỗi khi Firestore thay đổi.
final eventSosStatsProvider = StreamProvider.family<EventSosStats, String>((
  ref,
  eventId,
) {
  return FirebaseFirestore.instance
      .collection('posts')
      .where('eventId', isEqualTo: eventId)
      .where('postType', isEqualTo: 'sos')
      .snapshots()
      .map((snap) {
        final total = snap.docs.length;
        final unverified = snap.docs
            .where((d) => (d.data()['isVerified'] as bool?) != true)
            .length;
        return EventSosStats(totalSos: total, unverifiedSos: unverified);
      });
});

// =============================================================================
// CONTROLLER — bài đăng news/directive
// =============================================================================
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
    String? issuingLevel,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await _db.collection('posts').doc(id).set({
      'id': id,
      'eventId': arg,
      'userId': 'admin',
      'postType': postType,
      'title': title,
      'content': contentJson,
      'attachmentUrl': attachmentUrl,
      'attachmentName': attachmentName,
      'isVerified': true,
      'syncStatus': 'synced',
      'createdAt': FieldValue.serverTimestamp(),
      'issuingLevel': issuingLevel,
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
    String? issuingLevel,
  }) async {
    await _db.collection('posts').doc(postId).update({
      'title': title,
      'postType': postType,
      'content': contentJson,
      'attachmentUrl': attachmentUrl,
      'attachmentName': attachmentName,
      'issuingLevel': issuingLevel,
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
          // ── Header (tên sự kiện, trạng thái, nút đóng) ──────────────────
          _Header(event: event, ref: ref),

          // ── Damage stats ────────────────────────────────────────────────
          _DamageStatsSection(event: event),

          Expanded(
            child: postsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
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
// DAMAGE STATS SECTION — hiển thị thống kê thiệt hại mới nhất
// =============================================================================
class _DamageStatsSection extends ConsumerWidget {
  final DisasterEvent event;
  const _DamageStatsSection({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statAsync = ref.watch(latestDamageStatProvider(event.id));

    return Container(
      decoration: const BoxDecoration(
        color: _DC.cardBg,
        border: Border(bottom: BorderSide(color: _DC.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Tiêu đề + Action buttons ──────────────────────────────────
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _DC.brandRedBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.assessment_rounded,
                    color: _DC.brandRed, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Thống kê thiệt hại',
                style: TextStyle(
                  color: _DC.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              // Nút xem lịch sử
              if (statAsync.value != null)
                _ActionButton(
                  icon: Icons.history_rounded,
                  label: 'Lịch sử',
                  onTap: () => _showHistory(context, event.id),
                ),
              const SizedBox(width: 6),
              // Nút cập nhật
              _ActionButton(
                icon: Icons.add_chart_rounded,
                label: 'Cập nhật',
                onTap: () => _showInputDialog(context, ref, event.id, statAsync.value),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Nội dung stats ─────────────────────────────────────────────
          statAsync.when(
            loading: () => const SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Text('Lỗi: $e',
                style: const TextStyle(color: _DC.brandRed, fontSize: 12)),
            data: (stat) => stat == null
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Chưa có dữ liệu thống kê. Nhấn "Cập nhật" để thêm.',
                      style: TextStyle(color: _DC.textMuted, fontSize: 13),
                    ),
                  )
                : _DamageStatsGrid(stat: stat),
          ),
        ],
      ),
    );
  }

  void _showInputDialog(BuildContext context, WidgetRef ref, String eventId, EventDamageStat? latestStat) {
    showDialog(
      context: context,
      builder: (_) => _DamageStatsInputDialog(
        eventId: eventId,
        ref: ref,
        initialStat: latestStat,
      ),
    );
  }

  void _showHistory(BuildContext context, String eventId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DamageStatsHistorySheet(eventId: eventId),
    );
  }
}

// =============================================================================
// DAMAGE STATS GRID — 2×3 grid hiển thị 6 chỉ số
// =============================================================================
class _DamageStatsGrid extends StatelessWidget {
  final EventDamageStat stat;
  const _DamageStatsGrid({required this.stat});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'vi_VN');
    final fmtD = NumberFormat('#,##0.0', 'vi_VN');
    final dateStr = DateFormat('HH:mm – dd/MM/yyyy').format(stat.reportedAt.toLocal());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MiniStat(icon: Icons.person_off_rounded, label: 'Tử vong',
                value: fmt.format(stat.deaths), color: _DC.brandRed),
            _MiniStat(icon: Icons.search_off_rounded, label: 'Mất tích',
                value: fmt.format(stat.missing), color: _DC.amber),
            _MiniStat(icon: Icons.personal_injury_rounded, label: 'Bị thương',
                value: fmt.format(stat.injured), color: _DC.sosOrange),
            _MiniStat(icon: Icons.roofing_rounded, label: 'Nhà hư hại',
                value: fmt.format(stat.damagedHouses), color: _DC.blue),
            _MiniStat(icon: Icons.attach_money_rounded, label: 'Tài sản (tỷ đ)',
                value: fmtD.format(stat.propertyDamage), color: _DC.green),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Cập nhật lúc $dateStr',
          style: const TextStyle(color: _DC.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.icon, required this.label,
      required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _DC.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _DC.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(
                  color: _DC.textPrimary, fontSize: 15,
                  fontWeight: FontWeight.w800)),
                Text(label, style: const TextStyle(
                  color: _DC.textSecondary, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// DAMAGE STATS INPUT DIALOG — Form nhập thống kê thiệt hại (Insert-Only)
// =============================================================================
class _DamageStatsInputDialog extends StatefulWidget {
  final String eventId;
  final WidgetRef ref;
  final EventDamageStat? initialStat;

  const _DamageStatsInputDialog({
    required this.eventId,
    required this.ref,
    this.initialStat,
  });

  @override
  State<_DamageStatsInputDialog> createState() => _DamageStatsInputDialogState();
}

class _DamageStatsInputDialogState extends State<_DamageStatsInputDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _deathsC;
  late final TextEditingController _missingC;
  late final TextEditingController _injuredC;
  late final TextEditingController _housesC;
  late final TextEditingController _propertyC;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final s = widget.initialStat;
    _deathsC = TextEditingController(text: '${s?.deaths ?? 0}');
    _missingC = TextEditingController(text: '${s?.missing ?? 0}');
    _injuredC = TextEditingController(text: '${s?.injured ?? 0}');
    _housesC = TextEditingController(text: '${s?.damagedHouses ?? 0}');
    _propertyC = TextEditingController(text: '${s?.propertyDamage ?? 0.0}');
  }

  @override
  void dispose() {
    _deathsC.dispose(); _missingC.dispose(); _injuredC.dispose();
    _housesC.dispose(); _propertyC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.add_chart_rounded, color: _DC.brandRed, size: 22),
          SizedBox(width: 8),
          Text('Cập nhật Thống kê Thiệt hại',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Mỗi lần cập nhật sẽ tạo một bản ghi mới (không ghi đè dữ liệu cũ).',
                  style: TextStyle(color: _DC.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                _buildField(_deathsC, 'Số người tử vong', Icons.person_off_rounded),
                _buildField(_missingC, 'Số người mất tích', Icons.search_off_rounded),
                _buildField(_injuredC, 'Số người bị thương', Icons.personal_injury_rounded),
                _buildField(_housesC, 'Số nhà hư hại/tốc mái', Icons.roofing_rounded),
                _buildDoubleField(_propertyC, 'Tổng tài sản thiệt hại (tỷ đồng)', Icons.attach_money_rounded),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Huỷ', style: TextStyle(color: _DC.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _DC.brandRed, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _submitting
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Lưu thống kê', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildField(TextEditingController c, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: _DC.textSecondary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Bắt buộc';
          if (int.tryParse(v) == null) return 'Phải là số nguyên';
          return null;
        },
      ),
    );
  }

  Widget _buildDoubleField(TextEditingController c, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: _DC.textSecondary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Bắt buộc';
          if (double.tryParse(v) == null) return 'Phải là số';
          return null;
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await widget.ref.read(damageStatsRepositoryProvider).insertStat(
        eventId: widget.eventId,
        deaths: int.parse(_deathsC.text),
        missing: int.parse(_missingC.text),
        injured: int.parse(_injuredC.text),
        damagedHouses: int.parse(_housesC.text),
        propertyDamage: double.parse(_propertyC.text),
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã lưu thống kê thiệt hại thành công'),
          backgroundColor: _DC.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: _DC.brandRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

// =============================================================================
// DAMAGE STATS HISTORY SHEET — Timeline toàn bộ lịch sử cập nhật
// =============================================================================
class _DamageStatsHistorySheet extends ConsumerWidget {
  final String eventId;
  const _DamageStatsHistorySheet({required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(damageStatHistoryProvider(eventId));
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      height: screenH * 0.75,
      decoration: const BoxDecoration(
        color: _DC.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Handle bar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: _DC.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // ── Title ───────────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.timeline_rounded, color: _DC.brandRed, size: 22),
                SizedBox(width: 8),
                Text('Lịch sử cập nhật thiệt hại',
                  style: TextStyle(
                    color: _DC.textPrimary, fontSize: 16,
                    fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Divider(height: 1, color: _DC.border),
          // ── List ────────────────────────────────────────────────────────
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Lỗi: $e')),
              data: (stats) => stats.isEmpty
                  ? const Center(child: Text('Chưa có lịch sử',
                      style: TextStyle(color: _DC.textMuted)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: stats.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 0),
                      itemBuilder: (_, i) => _TimelineItem(
                        stat: stats[i], isFirst: i == 0, isLast: i == stats.length - 1),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final EventDamageStat stat;
  final bool isFirst;
  final bool isLast;
  const _TimelineItem({required this.stat, required this.isFirst, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('HH:mm – dd/MM/yyyy').format(stat.reportedAt.toLocal());
    final fmt = NumberFormat('#,##0', 'vi_VN');
    final fmtD = NumberFormat('#,##0.0', 'vi_VN');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Timeline line + dot ───────────────────────────────────────
          SizedBox(
            width: 28,
            child: Column(
              children: [
                if (!isFirst) Expanded(child: Container(width: 2, color: _DC.border)),
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    color: isFirst ? _DC.brandRed : _DC.textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast) Expanded(child: Container(width: 2, color: _DC.border)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // ── Content card ──────────────────────────────────────────────
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isFirst ? const Color(0xFFFFF5F5) : _DC.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isFirst ? const Color(0xFFFCA5A5) : _DC.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 14,
                          color: isFirst ? _DC.brandRed : _DC.textMuted),
                      const SizedBox(width: 4),
                      Text(dateStr, style: TextStyle(
                        color: isFirst ? _DC.brandRed : _DC.textSecondary,
                        fontSize: 12, fontWeight: FontWeight.w600)),
                      if (isFirst) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: _DC.brandRedBg,
                            borderRadius: BorderRadius.circular(4)),
                          child: const Text('Mới nhất',
                            style: TextStyle(color: _DC.brandRed,
                                fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12, runSpacing: 4,
                    children: [
                      _inlineLabel('Tử vong', fmt.format(stat.deaths)),
                      _inlineLabel('Mất tích', fmt.format(stat.missing)),
                      _inlineLabel('Bị thương', fmt.format(stat.injured)),
                      _inlineLabel('Nhà hư hại', fmt.format(stat.damagedHouses)),
                      _inlineLabel('Tài sản (tỷ đ)', fmtD.format(stat.propertyDamage)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inlineLabel(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12, fontFamily: 'Roboto'),
        children: [
          TextSpan(text: '$label: ',
              style: const TextStyle(color: _DC.textSecondary)),
          TextSpan(text: value,
              style: const TextStyle(
                  color: _DC.textPrimary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// =============================================================================
// STATS ROW
// =============================================================================

/// Hàng 3 thẻ thống kê: Tổng SOS — SOS chờ — Bài đăng.
///
/// Dùng [ConsumerStatefulWidget] để [AnimationController] sống đúng vòng đời
/// widget mà không bị huỷ/tạo lại mỗi khi Riverpod rebuild.
class _EventStatsRow extends ConsumerStatefulWidget {
  final DisasterEvent event;
  const _EventStatsRow({required this.event});

  @override
  ConsumerState<_EventStatsRow> createState() => _EventStatsRowState();
}

class _EventStatsRowState extends ConsumerState<_EventStatsRow>
    with SingleTickerProviderStateMixin {
  // Pulse animation — chỉ chạy khi có SOS chưa xử lý
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sosAsync = ref.watch(eventSosStatsProvider(widget.event.id));
    final postsAsync = ref.watch(adminPostsProvider(widget.event.id));

    // Dùng valueOrNull để hiển thị "–" khi đang loading, không block UI
    final stats = sosAsync.value ?? const EventSosStats.empty();
    final postCount = postsAsync.value?.length ?? 0;
    final isLoading = sosAsync.isLoading || postsAsync.isLoading;
    final hasUnverified = stats.unverifiedSos > 0;

    return Container(
      // Tách bằng đường kẻ nhẹ phía dưới để phân biệt với danh sách bài
      decoration: const BoxDecoration(
        color: _DC.cardBg,
        border: Border(bottom: BorderSide(color: _DC.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      child: Row(
        children: [
          // ── Thẻ 1: Tổng SOS nhận được ───────────────────────────────────
          Expanded(
            child: _StatCard(
              icon: Icons.sos_rounded,
              iconColor: _DC.sosOrange,
              iconBg: _DC.sosOrangeBg,
              label: 'Tổng SOS\nnhận được',
              value: isLoading ? '–' : '${stats.totalSos}',
            ),
          ),
          const SizedBox(width: 12),

          // ── Thẻ 2: SOS đang chờ (nhấp nháy khi > 0) ────────────────────
          Expanded(
            child: _PulsingStatCard(
              pulseAnim: _pulseAnim,
              isPulsing: hasUnverified,
              icon: Icons.warning_rounded,
              iconColor: _DC.brandRed,
              iconBg: _DC.brandRedBg,
              label: 'SOS đang\nchờ xử lý',
              value: isLoading ? '–' : '${stats.unverifiedSos}',
              valueColor: hasUnverified ? _DC.brandRed : _DC.textPrimary,
            ),
          ),
          const SizedBox(width: 12),

          // ── Thẻ 3: Bản tin & Công điện ──────────────────────────────────
          Expanded(
            child: _StatCard(
              icon: Icons.article_rounded,
              iconColor: _DC.blue,
              iconBg: _DC.blueBg,
              label: 'Bản tin &\nCông điện',
              value: isLoading ? '–' : '$postCount',
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// STAT CARD — tĩnh
// =============================================================================
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final Color? valueColor;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _DC.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _DC.border),
        boxShadow: const [
          BoxShadow(color: _DC.shadow, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon badge
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),

          // Số liệu lớn
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? _DC.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),

          // Nhãn mô tả
          Text(
            label,
            style: const TextStyle(
              color: _DC.textSecondary,
              fontSize: 11,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PULSING STAT CARD — nhấp nháy khi isPulsing == true
// =============================================================================

/// Wrapper quanh cùng layout với [_StatCard], nhưng khi [isPulsing] == true:
///   • Viền và nền đổi sang tông đỏ nhạt.
///   • Icon container dao động scale + opacity theo [pulseAnim].
/// Khi [isPulsing] == false widget render hoàn toàn tĩnh (AnimatedBuilder
/// trả về child ngay, không tính toán transform thừa).
class _PulsingStatCard extends StatelessWidget {
  final Animation<double> pulseAnim;
  final bool isPulsing;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final Color? valueColor;

  const _PulsingStatCard({
    required this.pulseAnim,
    required this.isPulsing,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isPulsing ? const Color(0xFFFFF5F5) : _DC.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPulsing ? const Color(0xFFFCA5A5) : _DC.border,
          width: isPulsing ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isPulsing ? _DC.brandRed.withOpacity(0.08) : _DC.shadow,
            blurRadius: isPulsing ? 10 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon badge — nhấp nháy scale + opacity khi có SOS chờ
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (_, child) {
              if (!isPulsing) return child!; // tĩnh hoàn toàn khi = 0
              return Transform.scale(
                scale: 0.92 + 0.08 * pulseAnim.value,
                child: Opacity(
                  opacity: 0.72 + 0.28 * pulseAnim.value,
                  child: child,
                ),
              );
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
          ),
          const SizedBox(height: 12),

          // Số liệu lớn
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? _DC.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),

          // Nhãn mô tả
          Text(
            label,
            style: const TextStyle(
              color: _DC.textSecondary,
              fontSize: 11,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: _DC.textSecondary,
              ),
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
            child: const Icon(
              Icons.warning_amber_rounded,
              color: _DC.brandRed,
              size: 22,
            ),
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
                        horizontal: 8,
                        vertical: 2,
                      ),
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
              icon: const Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: _DC.textSecondary,
              ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Đóng sự kiện?',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Sự kiện "${event.title}" sẽ được chuyển sang trạng thái "Đã kết thúc". '
          'Hành động này không thể hoàn tác.',
          style: const TextStyle(color: _DC.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Huỷ',
              style: TextStyle(color: _DC.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await FirebaseFirestore.instance
                    .collection('disaster_events')
                    .doc(event.id)
                    .update({'status': 'resolved'});
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
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Đóng sự kiện',
              style: TextStyle(color: Colors.white),
            ),
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
    final dateStr = DateFormat(
      'HH:mm – dd/MM/yyyy',
    ).format(post.createdAt.toLocal());

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
                      horizontal: 8,
                      vertical: 3,
                    ),
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
                  if (post.issuingLevel != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        // Dùng màu đỏ nhạt cho nổi bật
                        color: _DC.brandRedBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _DC.brandRed.withOpacity(0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        // Hàm này Tú có thể viết helper hoặc map nhanh tại đây
                        post.issuingLevel!.toUpperCase(),
                        style: const TextStyle(
                          color: _DC.brandRed,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),

                  // Attachment icon
                  if (post.attachmentUrl != null) ...[
                    const Icon(
                      Icons.attach_file_rounded,
                      size: 15,
                      color: _DC.textMuted,
                    ),
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
                    style: const TextStyle(color: _DC.textMuted, fontSize: 11),
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
    Navigator.of(ctx).push(
      MaterialPageRoute(
        builder: (_) => AdminPostEditorScreen(event: event, existingPost: post),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Xoá bài đăng?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text(
          'Bài đăng "${post.title}" sẽ bị xoá vĩnh viễn.',
          style: const TextStyle(color: _DC.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Huỷ',
              style: TextStyle(color: _DC.textSecondary),
            ),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lỗi xoá bài: $e'),
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
                borderRadius: BorderRadius.circular(8),
              ),
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
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AdminPostEditorScreen(event: event),
          ),
        );
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
            decoration: const BoxDecoration(
              color: _DC.brandRedBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.article_outlined,
              color: _DC.brandRed,
              size: 36,
            ),
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
      child: Text(
        'Lỗi: $message',
        style: const TextStyle(color: _DC.brandRed, fontSize: 14),
      ),
    );
  }
}
