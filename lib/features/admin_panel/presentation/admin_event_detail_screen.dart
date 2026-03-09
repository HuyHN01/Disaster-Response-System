// lib/features/admin_panel/presentation/admin_event_detail_screen.dart

import 'package:disaster_response_app/core/database/app_database.dart';
import 'package:disaster_response_app/core/services/firebase/sync_service.dart';
import 'package:disaster_response_app/features/admin_panel/domain/event_news_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

// Tái sử dụng bảng màu
class _C {
  static const Color scaffoldBg = Color(0xFFF4F6F9);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  static const Color brandRed = Color(0xFFDC2626);
  static const Color directiveOrange = Color(0xFFD97706);
  static const Color newsBlue = Color(0xFF2563EB);
  static const Color resolvedGreen = Color(0xFF16A34A);
}

class AdminEventDetailScreen extends ConsumerStatefulWidget {
  final DisasterEvent event;
  const AdminEventDetailScreen({super.key, required this.event});

  @override
  ConsumerState<AdminEventDetailScreen> createState() => _AdminEventDetailScreenState();
}

class _AdminEventDetailScreenState extends ConsumerState<AdminEventDetailScreen> {
  final _contentCtrl = TextEditingController();
  String _selectedType = 'news';

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  void _submitPost() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) return;

    // Lưu vào Local Drift
    await ref.read(eventNewsActionProvider).createPost(widget.event.id, content, _selectedType);
    
    // Gọi SyncService đẩy dữ liệu lên Firebase ngay lập tức
    // (Vì hàm syncPendingSOS() trong sync_service thực ra đang query syncStatus == 'pending', 
    // bạn có thể đổi tên hàm đó thành syncPendingPosts cho tổng quát, ở đây ta mượn tạm)
    ref.read(firebaseSyncServiceProvider).syncPendingSOS();

    _contentCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã đăng bản tin thành công!'), backgroundColor: _C.resolvedGreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final newsAsync = ref.watch(eventNewsProvider(widget.event.id));

    return Scaffold(
      backgroundColor: _C.scaffoldBg,
      appBar: AppBar(
        backgroundColor: _C.cardBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: _C.textPrimary),
        title: Row(
          children: [
            Text(
              widget.event.title,
              style: const TextStyle(color: _C.textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(width: 12),
            _StatusBadge(isActive: widget.event.status == 'active'),
          ],
        ),
        actions: [
          if (widget.event.status == 'active')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await ref.read(eventNewsActionProvider).resolveEvent(widget.event.id);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                label: const Text('Đóng sự kiện', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.resolvedGreen,
                  elevation: 0,
                ),
              ),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: _C.border, height: 1),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cột trái: Form đăng tin ──────────────────────────────────────────
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _C.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Ban hành Thông báo / Chỉ đạo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _C.textPrimary)),
                    const SizedBox(height: 6),
                    const Text('Nội dung này sẽ được hiển thị trực tiếp trên ứng dụng của người dân.', style: TextStyle(fontSize: 13, color: _C.textSecondary)),
                    const SizedBox(height: 24),
                    
                    const Text('Loại bản tin', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(border: Border.all(color: _C.border), borderRadius: BorderRadius.circular(8)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedType,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'news', child: Text('Tin tức cập nhật 📰')),
                            DropdownMenuItem(value: 'directive', child: Text('Công điện / Chỉ đạo khẩn ⚠️')),
                          ],
                          onChanged: (val) => setState(() => _selectedType = val!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('Nội dung chi tiết', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _contentCtrl,
                      maxLines: 8,
                      decoration: InputDecoration(
                        hintText: 'Nhập nội dung chỉ đạo, cảnh báo sơ tán...',
                        hintStyle: const TextStyle(color: _C.textSecondary, fontSize: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _C.border)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _submitPost,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedType == 'directive' ? _C.directiveOrange : _C.newsBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: const Text('Đăng bản tin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(width: 24),

            // ── Cột phải: Lịch sử bản tin ──────────────────────────────────────────
            Expanded(
              flex: 6,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _C.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _C.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Lịch sử ban hành', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _C.textPrimary)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: newsAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('Lỗi: $e')),
                        data: (posts) {
                          if (posts.isEmpty) {
                            return const Center(
                              child: Text('Chưa có bản tin nào được đăng.', style: TextStyle(color: _C.textSecondary)),
                            );
                          }
                          return ListView.separated(
                            itemCount: posts.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final p = posts[index];
                              final isDirective = p.postType == 'directive';
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDirective ? const Color(0xFFFFFBEB) : const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isDirective ? const Color(0xFFFDE68A) : const Color(0xFFBFDBFE)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isDirective ? _C.directiveOrange : _C.newsBlue,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            isDirective ? 'CÔNG ĐIỆN' : 'TIN TỨC',
                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          DateFormat('HH:mm - dd/MM/yyyy').format(p.createdAt),
                                          style: const TextStyle(color: _C.textSecondary, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(p.content, style: const TextStyle(color: _C.textPrimary, fontSize: 14, height: 1.5)),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Đang xảy ra' : 'Đã xử lý',
        style: TextStyle(color: isActive ? _C.brandRed : _C.resolvedGreen, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}