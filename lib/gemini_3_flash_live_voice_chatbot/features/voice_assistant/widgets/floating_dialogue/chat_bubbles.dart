part of '../../study_assistant_dialogue.dart';

/// Thin wrappers → shared widgets at floating-dialogue density (compact: true).

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;
  const _ChatBubble({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) =>
      ChatBubble(message: message, isDark: isDark, compact: true);
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) => const ThinkingChatBubble(compact: true);
}
