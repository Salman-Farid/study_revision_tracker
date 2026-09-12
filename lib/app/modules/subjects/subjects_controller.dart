import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/responsive.dart';
import '../../data/models/subject_model.dart';
import '../../data/models/topic_model.dart';
import '../../data/repositories/subject_repository.dart';
import '../../data/repositories/topic_repository.dart';
import '../../data/services/supabase_service.dart';
import '../../data/services/gemini_service.dart';
import '../../core/constants/size_constants.dart';
import '../../theme/app_theme.dart';
import '../../../gemini_3_flash_live_voice_chatbot/gemini_chatbot.dart';
import '../../../gemini_3_flash_live_voice_chatbot/features/voice_assistant/study_assistant_dialogue.dart';

class SubjectsController extends GetxController {
  final _repo = Get.find<SubjectRepository>();
  final _topicRepo = Get.find<TopicRepository>();
  final _gemini = GeminiService();
  final _stt = SpeechToText();
  final subjects = <SubjectModel>[].obs;
  final isLoading = true.obs;
  final isListening = false.obs;
  final chatMessages = <Map<String, dynamic>>[].obs;
  final showChat = false.obs;
  final isDragging = false.obs;
  /// Desktop/tablet side-by-side: subject shown in the detail pane.
  final selectedSubjectId = RxnString();
  StreamSubscription<List<SubjectModel>>? _realtimeSub;
  StreamSubscription<List<TopicModel>>? _topicsSub;

  // Real per-subject progress: subjectId → {topics, revisionsDone, revisionsPlanned}
  final topicsProgress = <String, Map<String, int>>{}.obs;
  // Topic names per subject: subjectId → [topicName1, topicName2, ...]
  final topicNames = <String, List<String>>{}.obs;

  // Global key for Study Assistant button to get its position
  final studyAssistantButtonKey = GlobalKey();

  SubjectModel? get selectedSubject {
    final id = selectedSubjectId.value;
    if (id == null) return null;
    for (final s in subjects) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Phone → full-screen route. Split layout → select for the side pane.
  void openSubject(SubjectModel subject) {
    if (Responsive.useSplitLayout) {
      selectedSubjectId.value = subject.id;
      return;
    }
    Get.toNamed('/subject/${subject.id}', arguments: subject);
  }

  @override void onInit() { super.onInit(); load(); _subscribeRealtime(); }

  void _subscribeRealtime() {
    _realtimeSub = _repo.stream.listen((list) {
      subjects.assignAll(list);
      isLoading.value = false;
      _recomputeProgress();
    });
    _topicsSub = _topicRepo.stream.listen((_) => _recomputeProgress());
  }

  @override
  void onClose() {
    _realtimeSub?.cancel();
    _topicsSub?.cancel();
    super.onClose();
  }

  Future<void> load() async {
    try {
      if (Get.find<SupabaseService>().currentUser == null) return;
      isLoading.value = true;
      subjects.assignAll(await _repo.getAll());
      await _recomputeProgress();
    } catch (e) { Get.snackbar('Error', 'Failed to load subjects: $e', snackPosition: SnackPosition.BOTTOM); }
    finally { isLoading.value = false; }
  }

  /// Computes REAL revision-weighted progress per subject from the DB:
  /// revisionsDone = Σ topic.totalRevisions, revisionsPlanned = 6 × topic count.
  Future<void> _recomputeProgress() async {
    final map = <String, Map<String, int>>{};
    final namesMap = <String, List<String>>{};
    await Future.wait(subjects.map((s) async {
      try {
        final topics = await _topicRepo.getBySubject(s.id)
            .timeout(const Duration(seconds: 5));
        final done = topics.fold<int>(0, (sum, t) => sum + t.totalRevisions.clamp(0, 6));
        map[s.id] = {
          'topics': topics.length,
          'revisionsDone': done,
          'revisionsPlanned': topics.length * 6,
        };
        namesMap[s.id] = topics.map((t) => t.name).toList();
        print('[Subjects] Progress ${s.name}: ${topics.length} topics, $done revisions done');
      } catch (e) {
        print('[Subjects] Progress error for ${s.name}: $e');
        map[s.id] = {'topics': s.totalTopics, 'revisionsDone': 0, 'revisionsPlanned': s.totalTopics * 6};
        namesMap[s.id] = [];
      }
    }));
    topicsProgress.assignAll(map);
    topicNames.assignAll(namesMap);
  }

  /// Real completion fraction (0..1) for a subject card's progress bar.
  double progressFor(String subjectId) {
    final p = topicsProgress[subjectId];
    if (p == null || (p['revisionsPlanned'] ?? 0) == 0) return 0;
    return (p['revisionsDone'] ?? 0) / (p['revisionsPlanned'] ?? 1);
  }

  /// Real topic count for a subject card (falls back to the DB column).
  int topicCountFor(SubjectModel subject) =>
      topicsProgress[subject.id]?['topics'] ?? subject.totalTopics;

  /// Topic names for a subject card.
  List<String> topicNamesFor(SubjectModel subject) =>
      topicNames[subject.id] ?? [];


  Future<void> createSubject({required String name, String? imageUrl, String? colorHex, int? iconCodePoint}) async {
    try {
      if (subjects.any((s) => s.name.toLowerCase() == name.toLowerCase())) {
        Get.snackbar('error'.tr, 'duplicateSubject'.tr.replaceAll('{name}', name), snackPosition: SnackPosition.BOTTOM); return;
      }
      final sub = await _repo.create(name: name, imageUrl: imageUrl, colorHex: colorHex, iconCodePoint: iconCodePoint);
      subjects.insert(0, sub);
      Get.back();
      Get.snackbar('save'.tr, 'subjectAdded'.tr.replaceAll('{name}', name), snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success.withOpacity(0.1));
    } catch (e) { Get.snackbar('error'.tr, 'error'.tr); }
  }

  Future<void> deleteSubject(String id) async {
    try { await _repo.delete(id); subjects.removeWhere((s) => s.id == id); }
    catch (e) { Get.snackbar('error'.tr, 'error'.tr); }
  }

  void reorderSubjects(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = subjects.removeAt(oldIndex);
    subjects.insert(newIndex, item);
  }

  Future<void> toggleChat() async {
    showChat.value = !showChat.value;
    if (showChat.value) chatMessages.add({'t': 'subjectNamesHint'.tr, 'u': false});
  }

  Future<void> startListening() async {
    final ok = await _stt.initialize();
    if (!ok) { Get.snackbar('error'.tr, 'error'.tr); return; }
    isListening.value = true;
    await _stt.listen(onResult: (r) { if (r.finalResult) _onVoice(r.recognizedWords); },
      localeId: 'bn_BD', listenFor: const Duration(seconds: 30), pauseFor: const Duration(seconds: 3));
  }

  Future<void> stopListening() async { await _stt.stop(); isListening.value = false; }

  Future<void> _onVoice(String text) async {
    isListening.value = false;
    chatMessages.add({'t': text, 'u': true});
    final r = await _gemini.processHomeCommand(text);
    if (r['action'] == 'create_subjects') {
      final list = r['subjects'] as List? ?? [];
      chatMessages.add({'t': r['confirmation'] ?? 'Creating ${list.length} subjects...', 'u': false});
      for (final s in list) {
        final n = s['name'] as String? ?? '';
        if (n.isNotEmpty) await createSubject(name: n, colorHex: s['color'] as String?);
      }
    } else {
      chatMessages.add({'t': r['question'] ?? 'Could not understand. Try again.', 'u': false});
    }
  }

  /// Navigate to Gemini Live voice assistant
  void openVoiceAssistant() {
    try {
      Get.find<VoiceAssistantController>().toolMode = 'subjects';
    } catch (_) {}
    Get.to(() => const VoiceAssistantScreen());
  }

  /// Open Study Assistant as a floating dialogue on top of this screen
  void openStudyAssistantDialogue() {
    // Register controller if not already
    try { Get.find<VoiceAssistantController>(); } catch (_) {
      Get.put(VoiceAssistantController(), permanent: true);
    }
    final vc = Get.find<VoiceAssistantController>();
    vc.toolMode = 'subjects'; // no class/daily routine tools on Subjects tab
    vc.showDialogue.value = true;

    showGeneralDialog(
      context: Get.context!,
      barrierDismissible: true,
      barrierLabel: 'Study Assistant',
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
      pageBuilder: (_, __, ___) => const StudyAssistantDialogue(),
    ).then((_) {
      vc.showDialogue.value = false;
    });
  }

  void showAddSheet() {
    final nc = TextEditingController();
    final ic = TextEditingController();
    final sci = 0.obs;
    Get.bottomSheet(Container(padding: EdgeInsets.all(S.xl),
      decoration: BoxDecoration(color: AppColors.surface(Get.isDarkMode),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: AppColors.textMuted(Get.isDarkMode), borderRadius: BorderRadius.circular(2)))),
        SizedBox(height: S.xl),
        Text('addSubject'.tr, style: AppTextStyles.headlineSmall),
        SizedBox(height: S.xl),
        TextField(controller: nc, decoration: InputDecoration(
          labelText: 'subjectName'.tr, prefixIcon: Icon(Icons.book_rounded)), autofocus: true),
        SizedBox(height: S.base),
        TextField(controller: ic, decoration: InputDecoration(
          labelText: 'imageUrlOptional'.tr,
          prefixIcon: Icon(Icons.image_outlined),
          hintText: 'https://images.unsplash.com/...')),
        SizedBox(height: S.base),
        Text('color'.tr, style: AppTextStyles.labelLarge),
        SizedBox(height: S.sm),
        Obx(() => Wrap(spacing: S.sm, runSpacing: S.sm,
          children: List.generate(AppConstants.subjectColors.length, (i) => GestureDetector(
            onTap: () => sci.value = i,
            child: AnimatedContainer(duration: AppConstants.microDuration, width: 36, height: 36,
              decoration: BoxDecoration(color: AppConstants.subjectColors[i], shape: BoxShape.circle,
                border: sci.value == i ? Border.all(color: Colors.white, width: 3) : null,
                boxShadow: sci.value == i
                  ? [BoxShadow(color: AppConstants.subjectColors[i].withOpacity(0.4), blurRadius: 8, spreadRadius: 1)] : null)))))),
        SizedBox(height: S.xl),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {
          final n = nc.text.trim();
          if (n.isNotEmpty) {
            final hex = '#${AppConstants.subjectColors[sci.value].value.toRadixString(16).substring(2)}';
            final img = ic.text.trim();
            createSubject(name: n, imageUrl: img.isNotEmpty ? img : null, colorHex: hex);
          }}, child: Text('createSubject'.tr))),
        SizedBox(height: S.base),
      ])), isScrollControlled: true);
  }
}
