part of '../voice_assistant_controller.dart';

extension VoiceAssistantDialogueLayout on VoiceAssistantController {
  void ensureDialogueSize({
    required bool allowResize,
    required double screenW,
    required double screenH,
  }) {
    if (dialogueWidth.value > 0) return;
    if (allowResize) {
      dialogueWidth.value = VoiceAssistantController.desktopDialogueW;
      dialogueHeight.value = (screenH * 0.48).clamp(VoiceAssistantController.minDialogueH, screenH * 0.7);
    } else {
      dialogueWidth.value = (screenW - 24).clamp(280.0, 420.0);
      dialogueHeight.value = screenH * 0.35;
    }
  }

  void startDialogueResize() => isResizingDialogue.value = true;
  void endDialogueResize() => isResizingDialogue.value = false;

  /// Resize from any corner. Left/top edges also move the panel origin.
  void resizeDialogueFromCorner({
    required String corner, // topLeft | topRight | bottomLeft | bottomRight
    required Offset delta,
    required double screenW,
    required double screenH,
  }) {
    final maxW = screenW.clamp(VoiceAssistantController.minDialogueW, VoiceAssistantController.maxDialogueW);
    final maxH = screenH * VoiceAssistantController.maxDialogueHRatio;
    var w = dialogueWidth.value;
    var h = dialogueHeight.value;
    var x = dialogueOffset.value.dx;
    var y = dialogueOffset.value.dy;

    switch (corner) {
      case 'topLeft':
        w -= delta.dx;
        h -= delta.dy;
        x += delta.dx;
        y += delta.dy;
        break;
      case 'topRight':
        w += delta.dx;
        h -= delta.dy;
        y += delta.dy;
        break;
      case 'bottomLeft':
        w -= delta.dx;
        h += delta.dy;
        x += delta.dx;
        break;
      case 'bottomRight':
      default:
        w += delta.dx;
        h += delta.dy;
        break;
    }

    final newW = w.clamp(VoiceAssistantController.minDialogueW, maxW);
    final newH = h.clamp(VoiceAssistantController.minDialogueH, maxH);
    // If size was clamped, fix origin so the opposite edge stays put.
    if (corner == 'topLeft' || corner == 'bottomLeft') {
      x = dialogueOffset.value.dx + (dialogueWidth.value - newW);
    }
    if (corner == 'topLeft' || corner == 'topRight') {
      y = dialogueOffset.value.dy + (dialogueHeight.value - newH);
    }

    dialogueWidth.value = newW;
    dialogueHeight.value = newH;
    dialogueOffset.value = Offset(
      x.clamp(0.0, (screenW - newW).clamp(0.0, screenW)),
      y.clamp(0.0, (screenH - newH).clamp(0.0, screenH)),
    );
  }

  void resetDialogueSize() {
    dialogueWidth.value = 0;
    dialogueHeight.value = 0;
    isResizingDialogue.value = false;
  }

  void updateDialogueOffset(Offset delta, double screenW, double screenH, double dialogueW, double currentH) {
    dialogueOffset.value = Offset(
      (dialogueOffset.value.dx + delta.dx).clamp(0, screenW - dialogueW),
      (dialogueOffset.value.dy + delta.dy).clamp(0, screenH - currentH),
    );
  }
}
