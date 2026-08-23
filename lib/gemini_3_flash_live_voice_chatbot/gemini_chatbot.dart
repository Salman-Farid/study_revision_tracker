/// Gemini 3 Flash Live Voice Chatbot
///
/// Usage:
/// ```dart
/// import 'gemini_3_flash_live_voice_chatbot/gemini_chatbot.dart';
///
/// // Navigate to the screen
/// Get.to(() => const VoiceAssistantScreen());
///
/// // Or use the service directly
/// final service = GeminiLiveService();
/// await service.startSession(voice: 'Kore');
/// service.sendText('Hello');
/// ```
library;

export 'config/gemini_config.dart';
export 'core/audio/audio_player.dart';
export 'core/audio/audio_recorder.dart';
export 'core/audio/pcm_converter.dart';
export 'core/websocket/gemini_socket.dart' show GeminiSocket, ConnectionState;
export 'features/voice_assistant/voice_assistant_binding.dart';
export 'features/voice_assistant/voice_assistant_controller.dart';
export 'features/voice_assistant/voice_assistant_screen.dart';
export 'services/gemini_live_service.dart';
