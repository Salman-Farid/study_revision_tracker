import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../data/models/subject_model.dart';
import '../../data/models/topic_model.dart';
import '../../data/repositories/topic_repository.dart';
import '../../data/repositories/revision_repository.dart';
import '../../data/services/gemini_service.dart';
import '../../theme/app_theme.dart';
import '../../core/constants/size_constants.dart';
import '../../../gemini_3_flash_live_voice_chatbot/gemini_chatbot.dart';

class SubjectDetailController extends GetxController {
  final _topicRepo = Get.find<TopicRepository>();
  final _revRepo = Get.find<RevisionRepository>();
  final _gemini = GeminiService();
  final _stt = SpeechToText();
  late SubjectModel subject;
  final topics = <TopicModel>[].obs;
  final isLoading = true.obs;
  final isListening = false.obs;
  final chatMessages = <Map<String, dynamic>>[].obs;
  final showChat = false.obs;
  StreamSubscription<List<TopicModel>>? _realtimeSub;

  @override void onInit() {
    super.onInit();
    subject = Get.arguments as SubjectModel;
    load();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    _realtimeSub = _topicRepo.stream.listen((allTopics) {
      // Filter topics belonging to this subject
      topics.assignAll(allTopics.where((t) => t.subjectId == subject.id));
    });
  }

  @override
  void onClose() {
    _realtimeSub?.cancel();
    super.onClose();
  }

  Future<void> load() async {
    try { isLoading.value = true; topics.assignAll(await _topicRepo.getBySubject(subject.id)); }
    catch (e) { Get.snackbar('Error', 'Failed'); } finally { isLoading.value = false; }
  }

  Future<void> createTopic({required String name, String? notes, String? refAnswer, DateTime? firstRead}) async {
    try {
      if (topics.any((t) => t.name.toLowerCase() == name.toLowerCase())) {
        Get.snackbar('Duplicate', '"$name" exists', snackPosition: SnackPosition.BOTTOM); return;
      }
      final rd = firstRead ?? DateTime.now();
      final t = await _topicRepo.create(subjectId: subject.id, name: name,
        notes: notes, referenceAnswer: refAnswer, firstReadDate: rd);
      await _revRepo.createSchedules(topicId: t.id, subjectId: subject.id, firstReadDate: rd);
      topics.insert(0, t);
      subject = subject.copyWith(totalTopics: subject.totalTopics + 1);
      Get.snackbar('Created', '"$name" with schedule', snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success.withOpacity(0.1));
    } catch (e) { Get.snackbar('Error', 'Failed: $e'); }
  }

  Future<void> toggleChat() async {
    showChat.value = !showChat.value;
    if (showChat.value) chatMessages.add({'t': '"${subject.name}" topic voice. "OSI Model, TCP/IP, kakey shokal 10tay"', 'u': false});
  }

  Future<void> startListening() async {
    final ok = await _stt.initialize(); if (!ok) return;
    isListening.value = true;
    await _stt.listen(onResult: (r) { if (r.finalResult) _onVoice(r.recognizedWords); },
      localeId: 'bn_BD', listenFor: const Duration(seconds: 45), pauseFor: const Duration(seconds: 4));
  }

  Future<void> stopListening() async { await _stt.stop(); isListening.value = false; }

  Future<void> _onVoice(String text) async {
    isListening.value = false;
    chatMessages.add({'t': text, 'u': true});
    final r = await _gemini.processTopicCommand(speech: text, subject: subject.name);
    if (r['action'] == 'create_topics') {
      final list = r['topics'] as List? ?? [];
      chatMessages.add({'t': r['confirmation'] ?? 'Creating ${list.length} topics...', 'u': false});
      for (final t in list) {
        final n = t['name'] as String? ?? ''; if (n.isEmpty) continue;
        DateTime? rd; if (t['first_read_date'] != null) rd = DateTime.tryParse(t['first_read_date']);
        await createTopic(name: n, notes: t['notes'], refAnswer: t['reference_answer'], firstRead: rd);
      }
    } else {
      chatMessages.add({'t': r['question'] ?? 'Could not understand', 'u': false});
    }
  }

  void showAddSheet() {
    final nc = TextEditingController(), nsc = TextEditingController(), rfc = TextEditingController();
    final sd = DateTime.now().obs, st = TimeOfDay.now().obs;
    Get.bottomSheet(Container(padding: EdgeInsets.all(S.xl),
      decoration: BoxDecoration(color: AppColors.surface(Get.isDarkMode),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(
            color: AppColors.textMuted(Get.isDarkMode), borderRadius: BorderRadius.circular(2)))),
          SizedBox(height: S.xl), Text('Add Topic', style: AppTextStyles.headlineSmall),
          SizedBox(height: S.sm), Text('Subject: ${subject.name}',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary)),
          SizedBox(height: S.xl),
          TextField(controller: nc, decoration: const InputDecoration(labelText: 'Topic Name *', prefixIcon: Icon(Icons.topic_rounded)), autofocus: true),
          SizedBox(height: S.base),
          Row(children: [
            Expanded(child: Obx(() => OutlinedButton.icon(onPressed: () async {
              final d = await showDatePicker(context: Get.context!, initialDate: sd.value,
                firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (d != null) sd.value = d;
            }, icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: Text('${sd.value.day}/${sd.value.month}/${sd.value.year}', style: AppTextStyles.labelMedium)))),
            SizedBox(width: S.sm),
            Expanded(child: Obx(() => OutlinedButton.icon(onPressed: () async {
              final t = await showTimePicker(context: Get.context!, initialTime: st.value);
              if (t != null) st.value = t;
            }, icon: const Icon(Icons.access_time_rounded, size: 16),
              label: Text(st.value.format(Get.context!), style: AppTextStyles.labelMedium)))),
          ]),
          SizedBox(height: S.base),
          TextField(controller: nsc, decoration: const InputDecoration(labelText: 'Notes (optional)', prefixIcon: Icon(Icons.note_rounded)), maxLines: 2),
          SizedBox(height: S.base),
          TextField(controller: rfc, decoration: const InputDecoration(labelText: 'Reference Answer (optional)', prefixIcon: Icon(Icons.article_rounded)), maxLines: 3),
          SizedBox(height: S.xl),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {
            final n = nc.text.trim();
            if (n.isEmpty) { Get.snackbar('Required', 'Topic name needed'); return; }
            final dt = DateTime(sd.value.year, sd.value.month, sd.value.day, st.value.hour, st.value.minute);
            createTopic(name: n, notes: nsc.text.trim().isEmpty ? null : nsc.text.trim(),
              refAnswer: rfc.text.trim().isEmpty ? null : rfc.text.trim(), firstRead: dt);
            Get.back();
          }, child: const Text('Create Topic with Schedule'))),
          SizedBox(height: S.base),
        ]))), isScrollControlled: true);
  }

  Future<void> deleteTopic(String id) async {
    try { await _topicRepo.delete(id); topics.removeWhere((t) => t.id == id); }
    catch (e) { Get.snackbar('Error', 'Failed'); }
  }

  /// Navigate to Gemini Live voice assistant
  void openVoiceAssistant() {
    Get.to(() => const VoiceAssistantScreen());
  }
}
