part of '../subjects_controller.dart';

/// Voice chat, Gemini Live, and Study Assistant dialogue.
extension SubjectsVoiceChat on SubjectsController {
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
}
