// lib/features/admin_panel/presentation/admin_post_editor_screen.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:disaster_response_app/core/database/app_database.dart';
import 'package:disaster_response_app/core/services/supabase/supabase_storage_service.dart';
import 'package:disaster_response_app/features/admin_panel/presentation/admin_event_detail_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// =============================================================================
// THEME (mirrors _DC in admin_event_detail_screen)
// =============================================================================
class _EC {
  static const Color bg = Color(0xFFF4F6F9);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color toolbarBg = Color(0xFFF9FAFB);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color brandRed = Color(0xFFDC2626);
  static const Color brandRedBg = Color(0xFFFEE2E2);
  static const Color green = Color(0xFF16A34A);
  static const Color amber = Color(0xFFD97706);
  static const Color amberBg = Color(0xFFFEF3C7);
  static const Color shadow = Color(0x0A000000);
}

// =============================================================================
// POST TYPE CONFIG
// =============================================================================
enum _PostType {
  news('news', 'Tin tức', Color(0xFF16A34A), Color(0xFFDCFCE7)),
  directive('directive', 'Công điện', Color(0xFFD97706), Color(0xFFFEF3C7));

  final String value;
  final String label;
  final Color color;
  final Color bg;

  const _PostType(this.value, this.label, this.color, this.bg);

  static _PostType fromValue(String v) =>
      values.firstWhere((t) => t.value == v, orElse: () => news);
}

// =============================================================================
// EDITOR SCREEN
// =============================================================================
class AdminPostEditorScreen extends ConsumerStatefulWidget {
  final DisasterEvent event;

  /// Truyền vào khi chỉnh sửa bài đã có; null khi tạo mới.
  final AdminPost? existingPost;

  const AdminPostEditorScreen({
    super.key,
    required this.event,
    this.existingPost,
  });

  @override
  ConsumerState<AdminPostEditorScreen> createState() =>
      _AdminPostEditorScreenState();
}

class _AdminPostEditorScreenState
    extends ConsumerState<AdminPostEditorScreen> {
  // ── Form state ─────────────────────────────────────────────────────────────
  late final TextEditingController _titleCtrl;
  late _PostType _selectedType;

  // ── Quill ──────────────────────────────────────────────────────────────────
  late final QuillController _quillCtrl;
  final FocusNode _quillFocus = FocusNode();

  // ── Attachment ─────────────────────────────────────────────────────────────
  String? _attachmentName;
  Uint8List? _attachmentBytes;

  // ── UI ─────────────────────────────────────────────────────────────────────
  bool _publishing = false;

  bool get _isEditing => widget.existingPost != null;

  // ---------------------------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    final post = widget.existingPost;
    _titleCtrl = TextEditingController(text: post?.title ?? '');
    _selectedType =
        _PostType.fromValue(post?.postType ?? _PostType.news.value);

    // Khởi tạo QuillController từ JSON đã lưu (nếu có)
    if (post != null) {
      try {
        final json =
            jsonDecode(post.contentJson) as Map<String, dynamic>;
        final delta = Delta.fromJson(json['ops'] as List<dynamic>);
        _quillCtrl = QuillController(
          document: Document.fromDelta(delta),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (_) {
        _quillCtrl = QuillController.basic();
      }
    } else {
      _quillCtrl = QuillController.basic();
    }

    _attachmentName = post?.attachmentName;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _quillCtrl.dispose();
    _quillFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // ACTIONS
  // ---------------------------------------------------------------------------

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xlsx', 'png', 'jpg'],
      withData: true,
    );
    if (result == null) return;
    final file = result.files.single;
    setState(() {
      _attachmentName = file.name;
      _attachmentBytes = file.bytes;
    });
  }

  void _removeAttachment() {
    setState(() {
      _attachmentName = null;
      _attachmentBytes = null;
    });
  }

  Future<void> _publish() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _showError('Vui lòng nhập tiêu đề bài đăng.');
      return;
    }

    // Validate editor has some content
    final plainText = _quillCtrl.document.toPlainText().trim();
    if (plainText.isEmpty) {
      _showError('Nội dung bài đăng không được để trống.');
      return;
    }

    setState(() => _publishing = true);

    // ── Serialize Quill Delta → JSON string ──────────────────────────────
    final deltaJson = _quillCtrl.document.toDelta().toJson();
    final contentJson = jsonEncode({'ops': deltaJson});

    // ── XỬ LÝ UPLOAD LÊN SUPABASE TRƯỚC KHI LƯU VÀO FIRESTORE ───────────
    String? finalAttachmentUrl = widget.existingPost?.attachmentUrl;

    try {
      // Nếu có file mới được chọn (có bytes)
      if (_attachmentBytes != null && _attachmentName != null) {
        // Gọi Supabase Storage Service
        finalAttachmentUrl = await SupabaseStorageService.uploadAttachment(
          _attachmentName!,
          _attachmentBytes!,
        );
      }

      final notifier = ref.read(adminPostsProvider(widget.event.id).notifier);

      if (_isEditing) {
        await notifier.updatePost(
          postId: widget.existingPost!.id,
          title: title,
          postType: _selectedType.value,
          contentJson: contentJson,
          attachmentUrl: finalAttachmentUrl, // URL từ Supabase
          attachmentName: _attachmentName ?? widget.existingPost?.attachmentName,
        );
      } else {
        await notifier.createPost(
          title: title,
          postType: _selectedType.value,
          contentJson: contentJson,
          attachmentUrl: finalAttachmentUrl, // URL từ Supabase
          attachmentName: _attachmentName,
        );
      }

      if (mounted) {
        _showSuccess(_isEditing ? 'Đã cập nhật bài đăng!' : 'Đã xuất bản!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) _showError('Lỗi xuất bản: $e');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _EC.bg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Main editor area ────────────────────────────────────
                Expanded(
                  flex: 3,
                  child: _buildEditorPanel(),
                ),

                // ── Right sidebar: meta options ─────────────────────────
                SizedBox(
                  width: 280,
                  child: _buildSidebar(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── HEADER ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: _EC.cardBg,
        border: Border(bottom: BorderSide(color: _EC.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Back
          InkWell(
            onTap: _publishing ? null : () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: const Icon(Icons.arrow_back_rounded,
                  size: 20, color: _EC.textSecondary),
            ),
          ),
          const SizedBox(width: 12),

          // Breadcrumb
          Text(
            widget.event.title,
            style: const TextStyle(color: _EC.textMuted, fontSize: 13),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.chevron_right_rounded,
                size: 16, color: _EC.textMuted),
          ),
          Text(
            _isEditing ? 'Chỉnh sửa bài đăng' : 'Bài đăng mới',
            style: const TextStyle(
              color: _EC.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),

          const Spacer(),

          // Save draft (TODO)
          OutlinedButton(
            onPressed: _publishing ? null : () {},
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _EC.border),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Lưu nháp',
              style: TextStyle(
                color: _EC.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Publish
          ElevatedButton.icon(
            onPressed: _publishing ? null : _publish,
            icon: _publishing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded,
                    size: 16, color: Colors.white),
            label: Text(
              _publishing
                  ? 'Đang xuất bản...'
                  : _isEditing
                      ? 'Cập nhật'
                      : 'Xuất bản',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _EC.brandRed,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // ── EDITOR PANEL ────────────────────────────────────────────────────────────
  Widget _buildEditorPanel() {
    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _EC.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _EC.border),
        boxShadow: const [
          BoxShadow(color: _EC.shadow, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Title input ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: TextField(
              controller: _titleCtrl,
              style: const TextStyle(
                color: _EC.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
              decoration: InputDecoration(
                hintText: 'Tiêu đề bài đăng...',
                hintStyle: TextStyle(
                  color: _EC.textMuted,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              maxLines: 2,
              minLines: 1,
              textInputAction: TextInputAction.next,
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(24, 14, 24, 0),
            child: Divider(color: _EC.border, height: 1),
          ),

          // ── Quill Toolbar ─────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: _EC.toolbarBg,
              border:
                  Border(bottom: BorderSide(color: _EC.border)),
            ),
            child: QuillSimpleToolbar(
              controller: _quillCtrl,
              config: QuillSimpleToolbarConfig(
                showDividers: true,
                showFontFamily: false,
                showFontSize: true,
                showBoldButton: true,
                showItalicButton: true,
                showUnderLineButton: true,
                showStrikeThrough: false,
                showInlineCode: false,
                showColorButton: true,
                showBackgroundColorButton: false,
                showClearFormat: true,
                showAlignmentButtons: true,
                showLeftAlignment: true,
                showCenterAlignment: true,
                showRightAlignment: true,
                showJustifyAlignment: false,
                showHeaderStyle: true,
                showListNumbers: true,
                showListBullets: true,
                showListCheck: false,
                showCodeBlock: false,
                showQuote: true,
                showIndent: true,
                showLink: true,
                showSearchButton: false,
                showSubscript: false,
                showSuperscript: false,
                buttonOptions: const QuillSimpleToolbarButtonOptions(),
              ),
            ),
          ),

          // ── Quill Editor ──────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: QuillEditor(
                controller: _quillCtrl,
                focusNode: _quillFocus,
                config: QuillEditorConfig(
                  placeholder: 'Bắt đầu soạn thảo nội dung...',
                  padding: EdgeInsets.zero,
                  autoFocus: !_isEditing,
                  expands: true,
                  scrollable: true,
                ),
                scrollController: ScrollController(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── RIGHT SIDEBAR ───────────────────────────────────────────────────────────
  Widget _buildSidebar() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 24, 24, 24),
      child: Column(
        children: [
          // ── Post type ─────────────────────────────────────────────────
          _SideCard(
            title: 'Loại bài đăng',
            child: Column(
              children: _PostType.values.map((type) {
                final isSelected = _selectedType == type;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? type.bg : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? type.color : _EC.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: type.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          type.label,
                          style: TextStyle(
                            color: isSelected
                                ? type.color
                                : _EC.textSecondary,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                        const Spacer(),
                        if (isSelected)
                          Icon(Icons.check_circle_rounded,
                              size: 16, color: type.color),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 14),

          // ── Attachment ────────────────────────────────────────────────
          _SideCard(
            title: 'Tệp đính kèm',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Current attachment display
                if (_attachmentName != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.insert_drive_file_rounded,
                            size: 18, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _attachmentName!,
                            style: const TextStyle(
                              color: Color(0xFF1E40AF),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: _removeAttachment,
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(Icons.close_rounded,
                                size: 14, color: Color(0xFF6B7280)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Pick file button
                OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.attach_file_rounded,
                      size: 16, color: _EC.textSecondary),
                  label: Text(
                    _attachmentName != null
                        ? 'Đổi tệp đính kèm'
                        : 'Đính kèm PDF / Word',
                    style: const TextStyle(
                      color: _EC.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _EC.border),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Hỗ trợ: PDF, Word, Excel, PNG, JPG',
                  style: TextStyle(color: _EC.textMuted, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Publishing info ───────────────────────────────────────────
          _SideCard(
            title: 'Thông tin xuất bản',
            child: Column(
              children: [
                _InfoRow(
                  label: 'Sự kiện',
                  value: widget.event.title,
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  label: 'Tác giả',
                  value: 'Quản trị viên',
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  label: 'Trạng thái',
                  value: _isEditing ? 'Cập nhật' : 'Xuất bản ngay',
                  valueColor: _EC.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SNACKBAR HELPERS
  // ---------------------------------------------------------------------------

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Text(msg,
                style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: _EC.brandRed,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
      backgroundColor: _EC.green,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

// =============================================================================
// SIDEBAR WIDGETS
// =============================================================================

class _SideCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SideCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _EC.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _EC.border),
        boxShadow: const [
          BoxShadow(color: _EC.shadow, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: _EC.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: _EC.border, height: 1),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(color: _EC.textMuted, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? _EC.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}