import 'package:disaster_response_app/features/ai_assistant/domain/chat_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// =============================================================================
// THEME TOKENS
// =============================================================================
class _ChatColors {
  static const Color scaffold = Color(0xFFF5F7FA);
  static const Color appBar = Color(0xFFFFFFFF);
  static const Color inputBar = Color(0xFFFFFFFF);

  // Bubbles
  static const Color userBubbleStart = Color(0xFFDC2626);
  static const Color userBubbleEnd = Color(0xFFEA580C);
  static const Color aiBubble = Color(0xFFFFFFFF);
  static const Color aiBubbleBorder = Color(0xFFE5E7EB);

  // Text
  static const Color userText = Colors.white;
  static const Color aiText = Color(0xFF111827);
  static const Color aiSubtext = Color(0xFF6B7280);
  static const Color timestampText = Color(0xFF9CA3AF);

  // Input
  static const Color inputBg = Color(0xFFF3F4F6);
  static const Color inputBorder = Color(0xFFE5E7EB);
  static const Color inputFocusBorder = Color(0xFFDC2626);
  static const Color sendButton = Color(0xFFDC2626);
  static const Color sendButtonDisabled = Color(0xFFD1D5DB);

  // Typing indicator
  static const Color typingDot = Color(0xFF9CA3AF);
  static const Color typingBg = Color(0xFFFFFFFF);

  static const Color divider = Color(0xFFE5E7EB);
  static const Color shadow = Color(0x0A000000);
}

// =============================================================================
// MAIN SCREEN
// =============================================================================
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _textCtrl.addListener(() {
      final hasText = _textCtrl.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    setState(() => _hasText = false);
    ref.read(chatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);

    // Auto-scroll when messages update or typing starts/stops
    ref.listen(chatProvider, (_, __) => _scrollToBottom());

    return Scaffold(
      backgroundColor: _ChatColors.scaffold,
      appBar: _ChatAppBar(),
      body: Column(
        children: [
          // ── Message List ─────────────────────────────────────────────────
          Expanded(
            child: _MessageList(
              messages: chatState.messages,
              isLoading: chatState.isLoading,
              scrollController: _scrollCtrl,
            ),
          ),

          // ── Input Bar ───────────────────────────────────────────────────
          _InputBar(
            controller: _textCtrl,
            hasText: _hasText,
            isLoading: chatState.isLoading,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// APP BAR
// =============================================================================
class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _ChatColors.appBar,
        border: Border(bottom: BorderSide(color: _ChatColors.divider)),
        boxShadow: [
          BoxShadow(
            color: _ChatColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Back button
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: Color(0xFF374151),
                ),
                onPressed: () => Navigator.of(context).maybePop(),
                splashRadius: 22,
              ),
              const SizedBox(width: 4),

              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDC2626).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Title + status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Trợ lý Cứu hộ AI',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF16A34A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Sẵn sàng hỗ trợ 24/7',
                          style: TextStyle(
                            color: _ChatColors.aiSubtext,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Info button
              IconButton(
                icon: const Icon(
                  Icons.info_outline_rounded,
                  size: 22,
                  color: Color(0xFF9CA3AF),
                ),
                onPressed: () {},
                splashRadius: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// MESSAGE LIST
// =============================================================================
class _MessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final bool isLoading;
  final ScrollController scrollController;

  const _MessageList({
    required this.messages,
    required this.isLoading,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    // Total items = messages + (typing indicator if loading)
    final itemCount = messages.length + (isLoading ? 1 : 0);

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Typing indicator as last item
        if (index == messages.length && isLoading) {
          return const _TypingIndicator();
        }

        final message = messages[index];
        final isFirst =
            index == 0 || messages[index - 1].isUser != message.isUser;
        final isLast =
            index == messages.length - 1 ||
            messages[index + 1].isUser != message.isUser;

        return _MessageBubble(
          message: message,
          isFirst: isFirst,
          isLast: isLast,
        );
      },
    );
  }
}

// =============================================================================
// MESSAGE BUBBLE
// =============================================================================
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isFirst;
  final bool isLast;

  const _MessageBubble({
    required this.message,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 8 : 2, bottom: isLast ? 8 : 2),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI Avatar (only on last AI message in a group)
          if (!isUser) ...[
            if (isLast)
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              )
            else
              const SizedBox(width: 40),
          ],

          // Bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              decoration: isUser
                  ? BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          _ChatColors.userBubbleStart,
                          _ChatColors.userBubbleEnd,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: Radius.circular(isFirst ? 18 : 18),
                        bottomLeft: const Radius.circular(18),
                        bottomRight: Radius.circular(isLast ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _ChatColors.userBubbleStart.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    )
                  : BoxDecoration(
                      color: _ChatColors.aiBubble,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isFirst ? 18 : 18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isLast ? 4 : 18),
                        bottomRight: const Radius.circular(18),
                      ),
                      border: Border.all(color: _ChatColors.aiBubbleBorder),
                      boxShadow: const [
                        BoxShadow(
                          color: _ChatColors.shadow,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isUser ? _ChatColors.userText : _ChatColors.aiText,
                  fontSize: 14.5,
                  height: 1.45,
                ),
              ),
            ),
          ),

          // User avatar (only on last user message in a group)
          if (isUser) ...[
            if (isLast)
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    'B',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 40),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// TYPING INDICATOR
// =============================================================================
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _dotCtrl;
  late List<Animation<double>> _dotAnim;

  @override
  void initState() {
    super.initState();
    _dotCtrl = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );

    _dotAnim = _dotCtrl
        .map(
          (c) => Tween<double>(
            begin: 0,
            end: -6,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)),
        )
        .toList();

    // Staggered start
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 160), () {
        if (mounted) _dotCtrl[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _dotCtrl) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI avatar
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDC2626), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),

          // Bubble with dots
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _ChatColors.typingBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: _ChatColors.aiBubbleBorder),
              boxShadow: const [
                BoxShadow(
                  color: _ChatColors.shadow,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'AI đang gõ',
                  style: TextStyle(
                    color: _ChatColors.aiSubtext,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 8),
                ...List.generate(3, (i) {
                  return AnimatedBuilder(
                    animation: _dotAnim[i],
                    builder: (_, __) => Transform.translate(
                      offset: Offset(0, _dotAnim[i].value),
                      child: Container(
                        width: 6,
                        height: 6,
                        margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
                        decoration: BoxDecoration(
                          color: _ChatColors.typingDot.withOpacity(
                            0.4 + 0.3 * (i / 2),
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// INPUT BAR
// =============================================================================
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool hasText;
  final bool isLoading;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.hasText,
    required this.isLoading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final canSend = hasText && !isLoading;

    return Container(
      decoration: const BoxDecoration(
        color: _ChatColors.inputBar,
        border: Border(top: BorderSide(color: _ChatColors.divider)),
        boxShadow: [
          BoxShadow(
            color: _ChatColors.shadow,
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0
            ? 10
            : 10 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: _ChatColors.inputBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: hasText
                      ? _ChatColors.inputFocusBorder.withOpacity(0.4)
                      : _ChatColors.inputBorder,
                  width: hasText ? 1.5 : 1,
                ),
              ),
              child: TextField(
                controller: controller,
                enabled: !isLoading,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 14.5,
                  height: 1.4,
                ),
                decoration: const InputDecoration(
                  hintText: 'Hỏi về kỹ năng sinh tồn...',
                  hintStyle: TextStyle(
                    color: Color(0xFFB0B7C3),
                    fontSize: 14.5,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Send Button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: canSend
                  ? _ChatColors.sendButton
                  : _ChatColors.sendButtonDisabled,
              borderRadius: BorderRadius.circular(15),
              boxShadow: canSend
                  ? [
                      BoxShadow(
                        color: _ChatColors.sendButton.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: canSend ? onSend : null,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
