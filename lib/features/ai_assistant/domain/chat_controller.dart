import 'package:disaster_response_app/core/services/ai/ai_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Model đơn giản cho một tin nhắn
class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading; // Trạng thái AI đang gõ

  const ChatState({
    required this.messages,
    required this.isLoading,
  });

  factory ChatState.initial() => ChatState(
        messages: [
          ChatMessage(
            text:
                "Xin chào! Tôi là Trợ lý Cứu hộ OmniDisaster. Tôi có thể hướng dẫn bạn cách xử lý khi nước dâng cao, cách cầm máu, hoặc kỹ năng sinh tồn trong bão. Bạn cần giúp gì?",
            isUser: false,
          ),
        ],
        isLoading: false,
      );

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ChatController extends Notifier<ChatState> {
  late final AiService _aiService;

  @override
  ChatState build() {
    _aiService = AiService();
    return ChatState.initial();
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Thêm tin nhắn của user vào list
    state = state.copyWith(
      messages: [...state.messages, ChatMessage(text: text, isUser: true)],
      isLoading: true,
    );

    // Gọi API
    final response = await _aiService.askQuestion(text);

    // Thêm câu trả lời của AI vào list
    state = state.copyWith(
      messages: [...state.messages, ChatMessage(text: response, isUser: false)],
      isLoading: false,
    );
  }
}

final chatProvider = NotifierProvider<ChatController, ChatState>(
  ChatController.new,
);
