import 'package:get/get.dart';

class VoiceAssistantBinding extends Bindings {
  @override
  void dependencies() {
    // Both GeminiLiveService and VoiceAssistantController are registered
    // in main.dart as permanent. No additional registration needed here.
  }
}
