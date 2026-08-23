class GeminiConfig {
  GeminiConfig._();

  // Replace with your actual Gemini API key
  static const String apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AQ.Ab8RN6Lr3Or3Nj3e0t5PpXsYvtuSgJxY4fr6_rTeW3J3ASSCLA',
  );

  static const String model = 'gemini-3.1-flash-live-preview';

  static const String wsBaseUrl =
      'wss://generativelanguage.googleapis.com/ws/'
      'google.ai.generativelanguage.v1beta.GenerativeService'
      '.BidiGenerateContent';
  // Note: Some Live API features require v1alpha. If v1beta fails, try:
  // 'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent'

  static String get wsUrl => '$wsBaseUrl?key=$apiKey';

  // Audio format: Gemini Live outputs 24kHz 16-bit mono PCM
  static const int sampleRate = 24000;
  static const int channels = 1;
  static const int bitDepth = 16;
  static const int bytesPerSample = 2; // 16-bit = 2 bytes

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration setupPollInterval = Duration(milliseconds: 100);
  static const int setupMaxAttempts = 100;

  // Pause durations in microseconds for concatenation
  static const int pauseSameSpeakerUs = 500000; // 0.5s
  static const int pauseDiffSpeakerUs = 800000; // 0.8s
  static const int pauseAfterGreetingUs = 1000000; // 1.0s
}
