import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/subject_model.dart';
import '../../data/repositories/subject_repository.dart';
import '../../data/services/gemini_service.dart';
import '../../core/constants/size_constants.dart';
import '../../theme/app_theme.dart';

class SubjectsController extends GetxController {
  final _repo = Get.find<SubjectRepository>();
  final _gemini = GeminiService();
  final _stt = SpeechToText();
  final subjects = <SubjectModel>[].obs;
  final isLoading = true.obs;
  final isListening = false.obs;
  final chatMessages = <Map<String, dynamic>>[].obs;
  final showChat = false.obs;

  @override void onInit() { super.onInit(); load(); }

  Future<void> load() async {
    try { isLoading.value = true; subjects.assignAll(await _repo.getAll()); }
    catch (e) { Get.snackbar('Error', 'Failed to load'); }
    finally { isLoading.value = false; }
  }

  Future<void> createSubject({required String name, String? colorHex, int? iconCodePoint}) async {
    try {
      if (subjects.any((s) => s.name.toLowerCase() == name.toLowerCase())) {
        Get.snackbar('Duplicate', '"$name" already exists', snackPosition: SnackPosition.BOTTOM); return;
      }
      final sub = await _repo.create(name: name, colorHex: colorHex, iconCodePoint: iconCodePoint);
      subjects.insert(0, sub);
      Get.back();
      Get.snackbar('Created', '"$name" added', snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success.withOpacity(0.1));
    } catch (e) { Get.snackbar('Error', 'Failed to create'); }
  }

  Future<void> deleteSubject(String id) async {
    try { await _repo.delete(id); subjects.removeWhere((s) => s.id == id); }
    catch (e) { Get.snackbar('Error', 'Failed'); }
  }

  Future<void> toggleChat() async {
    showChat.value = !showChat.value;
    if (showChat.value) chatMessages.add({'t': 'Subject names in Bengali/English. "Bangla, English, Math"', 'u': false});
  }

  Future<void> startListening() async {
    final ok = await _stt.initialize();
    if (!ok) { Get.snackbar('Error', 'Speech not available'); return; }
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

  void showAddSheet() {
    final nc = TextEditingController();
    final sci = 0.obs;
    Get.bottomSheet(Container(padding: EdgeInsets.all(S.xl),
      decoration: BoxDecoration(color: AppColors.surface(Get.isDarkMode),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: AppColors.textMuted(Get.isDarkMode), borderRadius: BorderRadius.circular(2)))),
        SizedBox(height: S.xl),
        Text('Add Subject', style: AppTextStyles.headlineSmall),
        SizedBox(height: S.xl),
        TextField(controller: nc, decoration: const InputDecoration(
          labelText: 'Subject Name', prefixIcon: Icon(Icons.book_rounded)), autofocus: true),
        SizedBox(height: S.base),
        Text('Color', style: AppTextStyles.labelLarge),
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
            createSubject(name: n, colorHex: hex);
          }}, child: const Text('Create Subject'))),
        SizedBox(height: S.base),
      ])), isScrollControlled: true);
  }
}
