// lib/features/citizen_news/presentation/citizen_news_detail_screen.dart

import 'dart:convert';

import 'package:disaster_response_app/features/citizen_news/domain/citizen_news_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// =============================================================================
// THEME
// =============================================================================
class _DC {
  static const Color bg = Color(0xFFF5F6FA);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFEEF0F4);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color brandRed = Color(0xFFDC2626);
  static const Color brandRedBg = Color(0xFFFEE2E2);
  static const Color news = Color(0xFF0EA5E9);
  static const Color newsBg = Color(0xFFE0F2FE);
  static const Color directive = Color(0xFFEA580C);
  static const Color directiveBg = Color(0xFFFFF7ED);
  static const Color directiveBorder = Color(0xFFFED7AA);
  static const Color attachBg = Color(0xFFEFF6FF);
  static const Color attachText = Color(0xFF1D4ED8);
  static const Color attachBorder = Color(0xFFBFDBFE);
  static const Color shadow = Color(0x0D000000);
}

// =============================================================================
// DETAIL SCREEN
// =============================================================================
class CitizenNewsDetailScreen extends StatefulWidget {
  final CitizenNewsPost? post;
  final String? postId;

  const CitizenNewsDetailScreen({
    super.key,
    this.post,
    this.postId,
  }) : assert(
          post != null || postId != null,
          'CitizenNewsDetailScreen requires either post or postId',
        );

  @override
  State<CitizenNewsDetailScreen> createState() =>
      _CitizenNewsDetailScreenState();
}

class _CitizenNewsDetailScreenState
    extends State<CitizenNewsDetailScreen> {
  QuillController? _quillCtrl;
  CitizenNewsPost? _loadedPost;
  bool _isLoadingPost = false;
  bool _isLaunching = false;

  @override
  void initState() {
    super.initState();

    if (widget.post != null) {
      _loadedPost = widget.post;
      _quillCtrl = _buildController(widget.post!.contentJson);
    } else {
      _loadPostById();
    }
  }

  @override
  void dispose() {
    _quillCtrl?.dispose();
    super.dispose();
  }

  Future<void> _loadPostById() async {
    final id = widget.postId;
    if (id == null) return;

    setState(() => _isLoadingPost = true);

    final post = await fetchCitizenNewsPostById(id);
    if (!mounted) return;

    _quillCtrl?.dispose();

    setState(() {
      _loadedPost = post;
      _quillCtrl = post == null ? null : _buildController(post.contentJson);
      _isLoadingPost = false;
    });
  }

  // ---------------------------------------------------------------------------
  // CONTROLLER FACTORY
  // ---------------------------------------------------------------------------

  /// Khởi tạo QuillController từ JSON string.
  /// Fallback về document rỗng nếu JSON không hợp lệ.
  QuillController _buildController(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final delta = Delta.fromJson(decoded['ops'] as List<dynamic>);
      return QuillController(
        document: Document.fromDelta(delta),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true, // ← không cho chỉnh sửa, không hiện bàn phím
      );
    } catch (_) {
      // content không phải JSON Quill hợp lệ → hiển thị text thô
      final fallback = Document()..insert(0, jsonStr);
      return QuillController(
        document: fallback,
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // ATTACHMENT LAUNCHER
  // ---------------------------------------------------------------------------

  Future<void> _openAttachment() async {
    final urlStr = _loadedPost?.attachmentUrl;
    if (urlStr == null) return;

    setState(() => _isLaunching = true);
    try {
      final uri = Uri.parse(urlStr);
      
      // Bỏ qua bước canLaunchUrl rườm rà. Ép hệ điều hành mở trình duyệt ngoài.
      // Nếu máy thực sự không có trình duyệt (rất hiếm), nó sẽ quăng Exception.
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Could not launch url');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Không thể mở tài liệu. Vui lòng thử lại.'),
            backgroundColor: _DC.brandRed,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPost) {
      return const Scaffold(
        backgroundColor: _DC.bg,
        body: Center(
          child: CircularProgressIndicator(color: _DC.brandRed),
        ),
      );
    }

    final post = _loadedPost;
    if (post == null || _quillCtrl == null) {
      return Scaffold(
        backgroundColor: _DC.bg,
        appBar: AppBar(
          backgroundColor: _DC.brandRed,
          foregroundColor: Colors.white,
          title: const Text('Không tìm thấy bài viết'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.article_outlined,
                  size: 56,
                  color: _DC.textMuted,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bài viết không còn tồn tại hoặc đã bị xoá.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _DC.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Quay lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isDirective = post.isDirective;
    final accentColor = isDirective ? _DC.directive : _DC.news;

    return Scaffold(
      backgroundColor: _DC.bg,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ───────────────────────────────────────────────────
          _DetailAppBar(
            isDirective: isDirective,
            accentColor: accentColor,
          ),

          // ── Content ───────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Meta card (badge + title + date) ─────────────────
                  _MetaCard(post: post, accentColor: accentColor),
                  const SizedBox(height: 14),

                  // ── Content card (Quill reader) ───────────────────────
                  _ContentCard(controller: _quillCtrl!),

                  // ── Attachment card ───────────────────────────────────
                  if (post.attachmentUrl != null) ...[
                    const SizedBox(height: 14),
                    _AttachmentCard(
                      name: post.attachmentName,
                      onOpen: _openAttachment,
                      isLoading: _isLaunching,
                    ),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SLIVER APP BAR
// =============================================================================
class _DetailAppBar extends StatelessWidget {
  final bool isDirective;
  final Color accentColor;

  const _DetailAppBar(
      {required this.isDirective, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final topColor =
        isDirective ? _DC.directive : const Color(0xFF0284C7);

    return SliverAppBar(
      expandedHeight: 80,
      pinned: true,
      backgroundColor: topColor,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child:
              const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
        ),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                topColor,
                topColor.withOpacity(0.85),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// META CARD
// =============================================================================
class _MetaCard extends StatelessWidget {
  final CitizenNewsPost post;
  final Color accentColor;

  static final _dateFmt = DateFormat('HH:mm  –  dd/MM/yyyy');

  const _MetaCard({required this.post, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final isDirective = post.isDirective;

    return Container(
      margin: const EdgeInsets.only(top: 0),
      decoration: BoxDecoration(
        color: _DC.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDirective ? _DC.directiveBorder : _DC.border,
          width: isDirective ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(color: _DC.shadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Directive banner
          if (isDirective)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: const BoxDecoration(
                color: _DC.directive,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.campaign_rounded,
                      color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'CÔNG ĐIỆN KHẨN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _NewsBadge(),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  post.title,
                  style: TextStyle(
                    color: isDirective
                        ? _DC.directive
                        : _DC.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),

                // Date + divider
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _DC.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 13, color: accentColor),
                      const SizedBox(width: 6),
                      Text(
                        _dateFmt.format(post.createdAt.toLocal()),
                        style: const TextStyle(
                          color: _DC.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// CONTENT CARD (Quill reader)
// =============================================================================
class _ContentCard extends StatelessWidget {
  final QuillController controller;

  const _ContentCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _DC.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _DC.border),
        boxShadow: const [
          BoxShadow(color: _DC.shadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _DC.brandRed,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Nội dung',
                  style: TextStyle(
                    color: _DC.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFF3F4F6), height: 1),
            const SizedBox(height: 16),

            // QuillEditor — readOnly, no toolbar, no keyboard
            QuillEditor(
              controller: controller,
              focusNode: FocusNode(canRequestFocus: false),
              scrollController: ScrollController(),
              config: QuillEditorConfig(
                // readOnly đã set trên controller — đây là fallback config
                showCursor: false,
                autoFocus: false,
                expands: false,
                scrollable: false,
                padding: EdgeInsets.zero,
                // Hiển thị ảnh embed Admin đã chèn
                embedBuilders: FlutterQuillEmbeds.editorBuilders(
                  imageEmbedConfig: QuillEditorImageEmbedConfig(
                    imageProviderBuilder: (context, imageUrl) {
                      if (imageUrl.startsWith('http://') ||
                          imageUrl.startsWith('https://')) {
                        return NetworkImage(imageUrl);
                      }
                      return NetworkImage(imageUrl);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ATTACHMENT CARD
// =============================================================================
class _AttachmentCard extends StatelessWidget {
  final String? name;
  final VoidCallback onOpen;
  final bool isLoading;

  const _AttachmentCard({
    this.name,
    required this.onOpen,
    required this.isLoading,
  });

  IconData _iconForFile(String? n) {
    if (n == null) return Icons.insert_drive_file_rounded;
    final ext = n.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => Icons.picture_as_pdf_rounded,
      'doc' || 'docx' => Icons.description_rounded,
      'xls' || 'xlsx' => Icons.table_chart_rounded,
      'png' || 'jpg' || 'jpeg' || 'webp' =>
        Icons.image_rounded,
      _ => Icons.insert_drive_file_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _DC.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _DC.attachBorder),
        boxShadow: const [
          BoxShadow(color: _DC.shadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: _DC.attachText,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Tệp đính kèm',
                style: TextStyle(
                  color: _DC.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // File info box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _DC.attachBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _DC.attachBorder),
            ),
            child: Row(
              children: [
                // File type icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _DC.attachBorder),
                  ),
                  child: Icon(
                    _iconForFile(name),
                    color: _DC.attachText,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),

                // File name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name ?? 'Tài liệu đính kèm',
                        style: const TextStyle(
                          color: _DC.attachText,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Nhấn để xem hoặc tải xuống',
                        style: TextStyle(
                          color: _DC.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Download button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onOpen,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.open_in_new_rounded,
                      size: 16, color: Colors.white),
              label: Text(
                isLoading
                    ? 'Đang mở...'
                    : 'Tải xuống / Xem tài liệu',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _DC.attachText,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SHARED SMALL WIDGETS
// =============================================================================
class _NewsBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _DC.newsBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.article_rounded, size: 12, color: _DC.news),
          SizedBox(width: 4),
          Text(
            'TIN TỨC',
            style: TextStyle(
              color: _DC.news,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}