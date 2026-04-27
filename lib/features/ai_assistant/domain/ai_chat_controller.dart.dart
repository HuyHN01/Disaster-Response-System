// lib/features/ai_assistant/domain/ai_chat_controller.dart
//
// RAG-powered AI Chat Controller cho OmniDisaster
// ─────────────────────────────────────────────────────────────────────────────
// Kiến trúc:
//   1. build() → fetch context từ Firestore (5 bài mới nhất)
//   2. Khởi tạo GenerativeModel với systemInstruction chứa context đó
//   3. startChat() → ChatSession duy trì lịch sử multi-turn
//   4. sendMessage() → thêm tin user vào state → gọi AI → thêm phản hồi
//
// Offline fallback:
//   Nếu Firestore không khả dụng → context rỗng → AI vẫn hoạt động
//   bằng kiến thức gốc của Gemini.
//
// Dependency cần thêm vào pubspec.yaml:
//   google_generative_ai: ^0.4.0   (hoặc version mới nhất)
//   cloud_firestore: (đã có)
//   flutter_riverpod: (đã có)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';

// =============================================================================
// ── API KEY CONFIG ────────────────────────────────────────────────────────────
// =============================================================================
// QUAN TRỌNG: Đừng hardcode key trong source code thật.
// Nên dùng --dart-define hoặc flutter_dotenv để inject lúc build:
//   flutter run --dart-define=GEMINI_API_KEY=AIza...
//
// Đọc trong code: const String.fromEnvironment('GEMINI_API_KEY')
final _kGeminiApiKey = String.fromEnvironment(
  'GEMINI_API_KEY',
  defaultValue: dotenv.get('GEMINI_API_KEY'),
);

// Model name — Flash cân bằng tốt giữa tốc độ và chất lượng
const _kModelName = 'gemini-2.5-flash-lite';

// Số bài viết tối đa đưa vào context
const _kMaxContextPosts = 5;

// Thời gian cache context — tránh gọi Firestore mỗi message
const _kContextCacheDuration = Duration(minutes: 5);

// =============================================================================
// ── CHAT MESSAGE MODEL ────────────────────────────────────────────────────────
// =============================================================================

/// Vai trò của người gửi tin nhắn trong cuộc trò chuyện.
enum ChatRole {
  user,
  ai,

  /// Tin nhắn hệ thống: lỗi, thông báo trạng thái (không gửi lên AI).
  system,
}

/// Đại diện một tin nhắn trong cuộc trò chuyện.
///
/// Immutable — mọi thay đổi state tạo list mới (Riverpod best practice).
class ChatMessage {
  final String id;
  final ChatRole role;
  final String text;
  final DateTime timestamp;

  /// true nếu đây là tin nhắn báo lỗi (hiển thị giao diện khác).
  final bool isError;

  /// true khi AI đang stream/typing (dùng để hiện typing indicator).
  final bool isTyping;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
    this.isError = false,
    this.isTyping = false,
  });

  /// Factory để tạo tin nhắn user.
  factory ChatMessage.fromUser(String text) => ChatMessage(
        id: 'usr_${DateTime.now().microsecondsSinceEpoch}',
        role: ChatRole.user,
        text: text.trim(),
        timestamp: DateTime.now(),
      );

  /// Factory để tạo tin nhắn AI.
  factory ChatMessage.fromAi(String text) => ChatMessage(
        id: 'ai_${DateTime.now().microsecondsSinceEpoch}',
        role: ChatRole.ai,
        text: text.trim(),
        timestamp: DateTime.now(),
      );

  /// Factory typing indicator — replace bằng phản hồi thật sau khi AI xong.
  factory ChatMessage.typing() => ChatMessage(
        id: 'typing',
        role: ChatRole.ai,
        text: '',
        timestamp: DateTime.now(),
        isTyping: true,
      );

  /// Factory tin nhắn lỗi.
  factory ChatMessage.error(String errorText) => ChatMessage(
        id: 'err_${DateTime.now().microsecondsSinceEpoch}',
        role: ChatRole.ai,
        text: errorText,
        timestamp: DateTime.now(),
        isError: true,
      );

  /// Factory tin nhắn hệ thống (welcome, separator...).
  factory ChatMessage.system(String text) => ChatMessage(
        id: 'sys_${DateTime.now().microsecondsSinceEpoch}',
        role: ChatRole.system,
        text: text,
        timestamp: DateTime.now(),
      );

  ChatMessage copyWith({String? text, bool? isTyping, bool? isError}) =>
      ChatMessage(
        id: id,
        role: role,
        text: text ?? this.text,
        timestamp: timestamp,
        isError: isError ?? this.isError,
        isTyping: isTyping ?? this.isTyping,
      );
}

// =============================================================================
// ── CONTEXT POST (internal model, không expose ra ngoài) ─────────────────────
// =============================================================================

class _ContextPost {
  final String title;
  final String postType; // 'news' | 'directive'
  final String contentText; // Plain text đã được parse từ Quill JSON
  final DateTime createdAt;

  const _ContextPost({
    required this.title,
    required this.postType,
    required this.contentText,
    required this.createdAt,
  });
}

// =============================================================================
// ── AI CHAT CONTROLLER ────────────────────────────────────────────────────────
// =============================================================================

/// Controller quản lý toàn bộ luồng chat AI.
///
/// State: `AsyncValue<List<ChatMessage>>`
///   • AsyncLoading — đang khởi tạo (fetch context + build model)
///   • AsyncData   — danh sách tin nhắn hiện tại
///   • AsyncError  — lỗi khởi tạo nghiêm trọng (hiếm gặp)
///
/// Vòng đời:
///   build() → fetch context → build model → state = [welcomeMessage]
///   sendMessage() → append user msg → call AI → replace typing → append AI msg
class AiChatController extends AsyncNotifier<List<ChatMessage>> {
  // ── Gemini session ──────────────────────────────────────────────────────────
  // ChatSession duy trì lịch sử multi-turn cho Gemini.
  // Được khởi tạo trong build() và tái tạo khi clearChat().
  ChatSession? _chatSession;

  // ── Context cache ───────────────────────────────────────────────────────────
  // Tránh fetch Firestore mỗi lần gửi message.
  String? _cachedContextString;
  DateTime? _contextFetchedAt;

  // ── Date formatter ──────────────────────────────────────────────────────────
  static final _dateFmt = DateFormat('HH:mm dd/MM/yyyy');

  // ---------------------------------------------------------------------------
  // BUILD — khởi tạo khi provider được watch lần đầu
  // ---------------------------------------------------------------------------

  @override
  Future<List<ChatMessage>> build() async {
    // Fetch context từ Firestore. Lỗi → bỏ qua, dùng context rỗng.
    final contextString = await _fetchLatestContext();

    // Khởi tạo Gemini model với system instruction có nhúng context
    _chatSession = _buildChatSession(contextString);

    // Tin nhắn chào mừng — hiển thị ngay khi màn hình mở
    final welcomeText = contextString.isEmpty
        ? 'Xin chào! Tôi là trợ lý AI của OmniDisaster. Tôi có thể giúp bạn về kỹ năng sinh tồn, sơ cấp cứu và ứng phó thiên tai. Bạn cần hỏi gì?'
        : 'Xin chào! Tôi là trợ lý AI của OmniDisaster. Tôi đã cập nhật thông tin mới nhất từ Ban Chỉ huy. Hãy hỏi tôi về tình hình hiện tại hoặc kỹ năng ứng phó thiên tai.';

    return [ChatMessage.fromAi(welcomeText)];
  }

  // ---------------------------------------------------------------------------
  // PUBLIC API
  // ---------------------------------------------------------------------------

  /// Gửi tin nhắn của người dùng và nhận phản hồi từ AI.
  ///
  /// Flow:
  ///   1. Append user message vào state
  ///   2. Append typing indicator
  ///   3. Gọi Gemini API
  ///   4. Replace typing indicator bằng phản hồi thật
  ///   5. Nếu lỗi → replace typing indicator bằng error message
  Future<void> sendMessage(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return;

    // Đảm bảo session đã sẵn sàng
    if (_chatSession == null) {
      final ctx = await _fetchLatestContext();
      _chatSession = _buildChatSession(ctx);
    }

    final currentMessages = state.value ?? [];

    // ── 1. Thêm tin nhắn user ────────────────────────────────────────────────
    final userMsg = ChatMessage.fromUser(trimmed);
    state = AsyncData([...currentMessages, userMsg]);

    // ── 2. Thêm typing indicator ─────────────────────────────────────────────
    final typingMsg = ChatMessage.typing();
    state = AsyncData([...currentMessages, userMsg, typingMsg]);

    // ── 3. Gọi Gemini API ────────────────────────────────────────────────────
    try {
      // Refresh context nếu cache hết hạn (mỗi 5 phút)
      await _refreshContextIfStale();

      final response = await _chatSession!.sendMessage(
        Content.text(trimmed),
      );

      final aiText = response.text?.trim();

      // ── 4. Replace typing indicator bằng phản hồi ─────────────────────────
      final aiMsg = (aiText != null && aiText.isNotEmpty)
          ? ChatMessage.fromAi(aiText)
          : ChatMessage.error(
              'Xin lỗi, tôi không thể trả lời lúc này. Vui lòng thử lại.');

      final withoutTyping = [...currentMessages, userMsg];
      state = AsyncData([...withoutTyping, aiMsg]);
    } on InvalidApiKey {
      _replaceTypingWithError(
        currentMessages,
        userMsg,
        '⚠️ API Key không hợp lệ. Vui lòng kiểm tra cấu hình ứng dụng.',
      );
    } on ServerException catch (e) {
      _replaceTypingWithError(
        currentMessages,
        userMsg,
        'Lỗi máy chủ AI (${e.message}). Vui lòng thử lại sau.',
      );
    } catch (e) {
      // Bao gồm lỗi mạng (SocketException, TimeoutException...)
      final isNetworkError = e.toString().toLowerCase().contains('socket') ||
          e.toString().toLowerCase().contains('connection') ||
          e.toString().toLowerCase().contains('timeout');

      _replaceTypingWithError(
        currentMessages,
        userMsg,
        isNetworkError
            ? '📡 Không có kết nối mạng. Vui lòng kiểm tra Internet và thử lại.'
            : 'Đã xảy ra lỗi: ${e.toString().substring(0, (e.toString().length).clamp(0, 80))}',
      );
    }
  }

  /// Xóa lịch sử chat và tạo session mới với context mới nhất.
  Future<void> clearChat() async {
    state = const AsyncLoading();
    _cachedContextString = null; // Force refresh context
    _contextFetchedAt = null;
    state = AsyncData(await build());
  }

  // ---------------------------------------------------------------------------
  // PRIVATE — CONTEXT FETCHING
  // ---------------------------------------------------------------------------

  /// Fetch 5 bài viết mới nhất từ Firestore, trả về Context String.
  ///
  /// Nếu Firestore không khả dụng (offline/lỗi mạng) → trả về chuỗi rỗng.
  /// Controller vẫn hoạt động bình thường, AI dùng kiến thức gốc.
  Future<String> _fetchLatestContext() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('posts')
          .where('postType', whereIn: ['news', 'directive'])
          .orderBy('createdAt', descending: true)
          .limit(_kMaxContextPosts)
          .get(
            // Cache ngắn — dữ liệu thiên tai cần cập nhật nhanh
            const GetOptions(source: Source.serverAndCache),
          );

      if (snap.docs.isEmpty) return '';

      final posts = snap.docs
          .map(_safeParseContextPost)
          .whereType<_ContextPost>()
          .toList();

      if (posts.isEmpty) return '';

      return _buildContextString(posts);
    } catch (_) {
      // Offline hoặc Firestore lỗi → trả về rỗng, AI vẫn chạy
      return '';
    }
  }

  /// Parse một Firestore document thành `_ContextPost`.
  /// Trả về null nếu document thiếu field hoặc format lỗi.
  _ContextPost? _safeParseContextPost(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      final d = doc.data();
      final rawTs = d['createdAt'];
      final createdAt =
          rawTs is Timestamp ? rawTs.toDate() : DateTime.now();

      return _ContextPost(
        title: (d['title'] as String?) ?? '(Không có tiêu đề)',
        postType: (d['postType'] as String?) ?? 'news',
        contentText: _parseQuillJson((d['content'] as String?) ?? ''),
        createdAt: createdAt,
      );
    } catch (_) {
      return null;
    }
  }

  /// Trích xuất plain text từ Quill Delta JSON.
  ///
  /// Quill Delta format: `{"ops": [{"insert": "text..."}, {"insert": "\n"}]}`
  /// Hàm này chỉ lấy các "insert" là String, bỏ qua embed (ảnh, video).
  ///
  /// Trả về chuỗi rỗng nếu JSON không hợp lệ hoặc không có text.
  String _parseQuillJson(String jsonStr) {
    if (jsonStr.isEmpty) return '';
    try {
      final decoded = jsonDecode(jsonStr);

      // Hỗ trợ cả 2 format: {"ops": [...]} và trực tiếp [...]
      final List<dynamic> ops;
      if (decoded is Map<String, dynamic> && decoded['ops'] is List) {
        ops = decoded['ops'] as List<dynamic>;
      } else if (decoded is List) {
        ops = decoded;
      } else {
        return '';
      }

      final buffer = StringBuffer();
      for (final op in ops) {
        if (op is! Map<String, dynamic>) continue;
        final insert = op['insert'];
        // Chỉ lấy insert là String; bỏ qua embed object (ảnh, video)
        if (insert is String) {
          buffer.write(insert);
        }
      }

      // Trim và giới hạn độ dài để không làm phình system prompt
      final text = buffer.toString().trim();
      return text.length > 800 ? '${text.substring(0, 800)}...' : text;
    } catch (_) {
      return '';
    }
  }

  /// Gom danh sách bài viết thành Context String theo format yêu cầu.
  String _buildContextString(List<_ContextPost> posts) {
    final buf = StringBuffer();
    buf.writeln('--- THÔNG TIN CẬP NHẬT MỚI NHẤT ---');

    for (final post in posts) {
      final timeStr = _dateFmt.format(post.createdAt.toLocal());
      final typeLabel =
          post.postType == 'directive' ? 'Công điện' : 'Tin tức';

      buf.writeln('$timeStr - ${post.title} (Loại: $typeLabel)');
      if (post.contentText.isNotEmpty) {
        buf.writeln(post.contentText);
      }
      buf.writeln('--------------------------------');
    }

    return buf.toString().trim();
  }

  // ---------------------------------------------------------------------------
  // PRIVATE — GEMINI MODEL BUILDER
  // ---------------------------------------------------------------------------

  /// Tạo `ChatSession` mới với `systemInstruction` nhúng context string.
  ///
  /// `systemInstruction` được thiết lập một lần khi tạo model —
  /// không thể thay đổi giữa chừng. Để refresh context, gọi clearChat()
  /// hoặc _refreshContextIfStale() để tạo lại session.
  ChatSession _buildChatSession(String contextString) {
    // ── System instruction ──────────────────────────────────────────────────
    final contextSection = contextString.isEmpty
        ? '(Hiện chưa có thông tin cập nhật từ Ban Chỉ huy.)'
        : contextString;

    final systemPrompt = '''
Bạn là trợ lý AI ảo của hệ thống ứng phó thiên tai OmniDisaster, được thiết kế để hỗ trợ người dân trong các tình huống khẩn cấp.

Dưới đây là các thông tin và chỉ đạo mới nhất từ Ban Chỉ huy:

$contextSection

NGUYÊN TẮC TRẢ LỜI:
• Nếu câu hỏi liên quan đến tình hình hiện tại (sơ tán, thời tiết, trạm cứu trợ, khu vực nguy hiểm), hãy MẶC ĐỊNH dùng thông tin từ Ban Chỉ huy ở trên.
• Nếu câu hỏi về kỹ năng sinh tồn, sơ cấp cứu, hoặc kiến thức ứng phó thiên tai tổng quát, hãy dùng kiến thức chuyên môn của bạn.
• Trả lời ngắn gọn, súc tích, rõ ràng, mang tính trấn an.
• Nếu không chắc chắn, hãy nói rõ và khuyến khích người dân liên hệ cơ quan chức năng.
• Luôn trả lời bằng Tiếng Việt.
• Không bịa đặt thông tin địa điểm, số liệu cụ thể nếu không có trong dữ liệu từ Ban Chỉ huy.
''';

    // ── Build model ─────────────────────────────────────────────────────────
    final model = GenerativeModel(
      model: _kModelName,
      apiKey: _kGeminiApiKey,
      systemInstruction: Content.system(systemPrompt),
      generationConfig: GenerationConfig(
        // Nhiệt độ thấp → phản hồi nhất quán, ít sáng tạo quá mức
        temperature: 0.4,
        // Giới hạn token output — đủ để trả lời súc tích
        maxOutputTokens: 512,
        topP: 0.8,
        topK: 40,
      ),
      safetySettings: [
        // Giảm ngưỡng block để tránh false-positive với nội dung thiên tai
        SafetySetting(
          HarmCategory.harassment,
          HarmBlockThreshold.high,
        ),
        SafetySetting(
          HarmCategory.hateSpeech,
          HarmBlockThreshold.high,
        ),
        SafetySetting(
          HarmCategory.dangerousContent,
          // Medium thay vì high — nội dung "nguy hiểm" có thể là hướng dẫn
          // thoát hiểm, xử lý hóa chất sau lũ... cần được AI trả lời
          HarmBlockThreshold.medium,
        ),
      ],
    );

    return model.startChat();
  }

  // ---------------------------------------------------------------------------
  // PRIVATE — CONTEXT REFRESH
  // ---------------------------------------------------------------------------

  /// Refresh context nếu cache đã hết hạn (_kContextCacheDuration).
  /// Nếu context thay đổi → tạo lại ChatSession với context mới.
  ///
  /// NOTE: Tạo lại session sẽ xóa lịch sử multi-turn của Gemini,
  /// nhưng tin nhắn trong state vẫn được giữ nguyên cho UI.
  Future<void> _refreshContextIfStale() async {
    final now = DateTime.now();
    final fetchedAt = _contextFetchedAt;

    if (fetchedAt != null &&
        now.difference(fetchedAt) < _kContextCacheDuration) {
      return; // Cache còn hạn
    }

    final newContext = await _fetchLatestContext();
    _cachedContextString = newContext;
    _contextFetchedAt = now;

    // Tạo lại session với context mới nhất
    _chatSession = _buildChatSession(newContext);
  }

  // ---------------------------------------------------------------------------
  // PRIVATE — STATE HELPERS
  // ---------------------------------------------------------------------------

  /// Replace typing indicator (id == 'typing') bằng error message.
  void _replaceTypingWithError(
    List<ChatMessage> baseMessages,
    ChatMessage userMsg,
    String errorText,
  ) {
    final errorMsg = ChatMessage.error(errorText);
    state = AsyncData([...baseMessages, userMsg, errorMsg]);
  }
}

// =============================================================================
// ── PROVIDERS ─────────────────────────────────────────────────────────────────
// =============================================================================

/// Provider chính — expose danh sách tin nhắn và notifier.
///
/// `autoDispose`: giải phóng session Gemini khi màn hình chat bị pop,
/// tránh giữ connection không cần thiết.
///
/// Sử dụng trong UI:
/// ```dart
/// // Watch state
/// final chatAsync = ref.watch(aiChatProvider);
///
/// // Gửi message
/// await ref.read(aiChatProvider.notifier).sendMessage('Tôi cần giúp đỡ');
///
/// // Clear chat
/// await ref.read(aiChatProvider.notifier).clearChat();
/// ```
final aiChatProvider =
    AsyncNotifierProvider.autoDispose<AiChatController, List<ChatMessage>>(
  AiChatController.new,
);

/// Derived provider — true khi AI đang xử lý (typing indicator visible).
///
/// Widget dùng để disable input field và nút gửi:
/// ```dart
/// final isTyping = ref.watch(aiIsTypingProvider);
/// ```
final aiIsTypingProvider = Provider.autoDispose<bool>((ref) {
  final chatAsync = ref.watch(aiChatProvider);
  return chatAsync.maybeWhen(
    data: (messages) => messages.any((m) => m.isTyping),
    orElse: () => false,
  );
});

/// Derived provider — chỉ expose list tin nhắn (không wrap AsyncValue).
///
/// Dùng khi UI đã handle loading state riêng:
/// ```dart
/// final messages = ref.watch(chatMessagesProvider);
/// ```
final chatMessagesProvider = Provider.autoDispose<List<ChatMessage>>((ref) {
  return ref.watch(aiChatProvider).value ?? const [];
});