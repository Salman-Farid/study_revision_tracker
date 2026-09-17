import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/core/constants/app_constants.dart';
import '../../../app/core/constants/responsive.dart';
import '../../../app/theme/app_theme.dart';
import '../../core/models/chat_message.dart';
import '../../core/websocket/gemini_socket.dart' as ws;
import '../../shared/widgets/thinking_dots.dart';
import 'voice_assistant_controller.dart';
import 'widgets/shared/chat_bubbles.dart';
import 'widgets/shared/error_bar.dart';
part 'widgets/floating_dialogue/chat_bubbles.dart';
part 'widgets/floating_dialogue/corner_painter.dart';
part 'widgets/floating_dialogue/error_bar.dart';
part 'widgets/floating_dialogue/message_builders.dart';
part 'widgets/floating_dialogue/panel_layout.dart';

class StudyAssistantDialogue extends StatefulWidget {
  const StudyAssistantDialogue({super.key});
  @override
  State<StudyAssistantDialogue> createState() => _StudyAssistantDialogueState();
}

class _StudyAssistantDialogueState extends State<StudyAssistantDialogue> {
  bool _sessionStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _sessionStarted) return;
      final c = Get.find<VoiceAssistantController>();
      if (c.connectionState.value == ws.ConnectionState.disconnected) {
        _sessionStarted = true;
        try {
          c.startSession();
        } catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<VoiceAssistantController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    // Desktop/tablet: floating compact card + corner resize.
    // Phone: near-full-width sheet + expand chevron.
    final allowResize = Responsive.useNavRail;

    c.ensureDialogueSize(
      allowResize: allowResize,
      screenW: screenW,
      screenH: screenH,
    );
    if (!allowResize) {
      c.initExpandAnim();
    }

    final baseW = c.dialogueWidth.value > 0
        ? c.dialogueWidth.value
        : (screenW - 24).clamp(280.0, 420.0);
    final baseH = c.dialogueHeight.value > 0
        ? c.dialogueHeight.value
        : screenH * 0.35;

    if (!c.dialogueOffsetInitialized) {
      // Center-ish on desktop, mid-screen on phone.
      final dy = allowResize
          ? ((screenH - baseH) / 2).clamp(24.0, screenH - baseH - 24)
          : (screenH - baseH) / 2;
      final dx = allowResize
          ? ((screenW - baseW) / 2).clamp(12.0, screenW - baseW - 12)
          : 12.0;
      c.dialogueOffset.value = Offset(dx, dy);
      c.dialogueOffsetInitialized = true;
    }

    if (allowResize) {
      return Stack(
        children: [
          Obx(() {
            final w = c.dialogueWidth.value;
            final h = c.dialogueHeight.value;
            return Positioned(
              left: c.dialogueOffset.value.dx,
              top: c.dialogueOffset.value.dy,
              width: w,
              height: h,
              child: _panelShell(
                c: c,
                isDark: isDark,
                screenW: screenW,
                screenH: screenH,
                dialogueW: w,
                currentH: h,
                allowResize: true,
              ),
            );
          }),
        ],
      );
    }

    // Phone: expand animation between 35% ↔ 70% height.
    return AnimatedBuilder(
      animation: c.expandAnim!,
      builder: (context, _) {
        return Stack(
          children: [
            Obx(() {
              final hNormal = baseH;
              final hExpanded = screenH * 0.70;
              final currentH =
                  hNormal + (hExpanded - hNormal) * c.expandAnim!.value;
              return Positioned(
                left: c.dialogueOffset.value.dx,
                top: c.dialogueOffset.value.dy,
                child: _panelShell(
                  c: c,
                  isDark: isDark,
                  screenW: screenW,
                  screenH: screenH,
                  dialogueW: baseW,
                  currentH: currentH,
                  allowResize: false,
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
