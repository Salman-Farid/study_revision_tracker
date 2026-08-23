import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/constants/app_constants.dart';

class GeminiService {
  late final GenerativeModel _model;
  GeminiService() {
    _model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: AppConstants.geminiApiKey,
      generationConfig: GenerationConfig(temperature: 0.3, topP: 0.9,
        maxOutputTokens: 2048, responseMimeType: 'application/json'),
      systemInstruction: Content.system(_sysPrompt));
  }

  static final String _sysPrompt = '''You are a smart revision tracker assistant. You understand Bengali (Bangla), English, Hindi, and other languages.
You help users create subjects and topics for their study revision tracker.
Current date: ${_cd}

RULES:
1. Always respond with valid JSON
2. For subject creation: {"action":"create_subjects","subjects":[{"name":"...","color":"#hex"}],"confirmation":"..."}
3. For topic creation: {"action":"create_topics","topics":[{"name":"...","first_read_date":"ISO8601","notes":"...","reference_answer":"..."}],"confirmation":"..."}
4. If ambiguous, ask for clarification: {"action":"clarify","question":"..."}
5. Interpret relative dates like "tomorrow", "day after tomorrow" based on current date
6. Times: "সন্ধ্যা ৭টা" = 7PM, "রাত ৮টা" = 8PM, "সকাল ১০টা" = 10AM
7. If no time specified, default to now
8. confirmation message should be in the language the user spoke''';

  static String get _cd => DateTime.now().toIso8601String().substring(0, 10);

  Future<Map<String, dynamic>> processHomeCommand(String speech) async {
    try {
      final r = await _model.generateContent([Content.text('HOME CONTEXT. User said: "$speech"')]);
      return _parse(r.text ?? '{}');
    } catch (e) { return {'action': 'error', 'question': 'Sorry, please try again.'}; }
  }

  Future<Map<String, dynamic>> processTopicCommand({required String speech, required String subject}) async {
    try {
      final r = await _model.generateContent([Content.text(
        'SUBJECT CONTEXT for "$subject". User said: "$speech". Current datetime: ${DateTime.now().toIso8601String()}')]);
      return _parse(r.text ?? '{}');
    } catch (e) { return {'action': 'error', 'question': 'Sorry, please try again.'}; }
  }

  Map<String, dynamic> _parse(String t) {
    try {
      t = t.trim();
      if (t.startsWith('{')) return jsonDecode(t) as Map<String, dynamic>;
      final s = t.indexOf('{'), e = t.lastIndexOf('}');
      if (s != -1 && e != -1) return jsonDecode(t.substring(s, e + 1)) as Map<String, dynamic>;
      return {'action': 'clarify', 'question': 'Could you repeat that?'};
    } catch (_) { return {'action': 'clarize', 'question': 'Could you repeat that?'}; }
  }
}
