part of '../../voice_assistant_screen.dart';

/// Thin wrappers → shared widgets at full-screen density (compact: false).
/// Prefer importing `widgets/shared/chat_bubbles.dart` in new code.

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;
  const _ChatBubble({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) =>
      ChatBubble(message: message, isDark: isDark, compact: false);
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) =>
      const ThinkingChatBubble(compact: false);
}
