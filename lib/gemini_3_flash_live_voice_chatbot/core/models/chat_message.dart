enum ChatRole { user, assistant, system }

class ChatMessage {
  final ChatRole role;
  final String text;
  final DateTime timestamp;
  final bool isAudio;

  ChatMessage({
    required this.role,
    required this.text,
    DateTime? timestamp,
    this.isAudio = false,
  }) : timestamp = timestamp ?? DateTime.now();

  String get displayText => text;
  bool get isUser => role == ChatRole.user;
  bool get isAssistant => role == ChatRole.assistant;
}
