part of '../subjects_controller.dart';

/// Gemini Live voice assistant entry points.
extension SubjectsVoiceChat on SubjectsController {
  /// Navigate to Gemini Live voice assistant
  void openVoiceAssistant() {
    try {
      final vc = Get.find<VoiceAssistantController>();
      vc.toolMode = 'subjects';
      vc.currentRoutineMode = null;
      vc.currentSubjectName = null;
      vc.currentTopicName = null;
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
    vc.currentRoutineMode = null;
    vc.currentSubjectName = null;
    vc.currentTopicName = null;
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
