import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../gemini_3_flash_live_voice_chatbot/features/voice_assistant/study_assistant_dialogue.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/responsive.dart';
import '../../theme/app_theme.dart';
import 'routine_controller.dart';
import 'widgets/routine_bodies.dart';
import 'widgets/routine_mode_toggle.dart';
import 'widgets/routine_shimmers.dart';

class RoutineScreen extends GetView<RoutineController> {
  const RoutineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    // Desktop/tablet: show Daily + Class side-by-side — no toggle.
    final dual = Responsive.useSplitLayout;

    return Scaffold(
      backgroundColor: AppColors.bg(d),
      appBar: AppBar(
        backgroundColor: AppColors.bg(d),
        elevation: 0,
        title: Text('routine'.tr),
        actions: [
          IconButton(
            tooltip: 'assistant'.tr,
            icon: const Icon(Icons.mic_rounded),
            onPressed: controller.openAssistant,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (dual)
            Obx(() {
              if (controller.isLoading.value) {
                return Row(
                  children: [
                    Expanded(child: DailyShimmer(d: d)),
                    const VerticalDivider(width: 1),
                    Expanded(child: ClassShimmer(d: d)),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        PaneHeader(
                          icon: Icons.today_rounded,
                          label: 'dailyRoutine'.tr,
                          d: d,
                        ),
                        Expanded(child: DailyBody(controller: controller)),
                      ],
                    ),
                  ),
                  VerticalDivider(width: 1, thickness: 1, color: AppColors.border(d)),
                  Expanded(
                    child: Column(
                      children: [
                        PaneHeader(
                          icon: Icons.event_note_rounded,
                          label: 'classRoutine'.tr,
                          d: d,
                        ),
                        Expanded(child: ClassBody(controller: controller)),
                      ],
                    ),
                  ),
                ],
              );
            })
          else
            Column(
              children: [
                ModeToggle(controller: controller),
                Expanded(
                  child: Obx(() {
                    if (controller.isLoading.value) {
                      return controller.mode.value == RoutineMode.daily
                          ? DailyShimmer(d: d)
                          : ClassShimmer(d: d);
                    }
                    return controller.mode.value == RoutineMode.daily
                        ? DailyBody(controller: controller)
                        : ClassBody(controller: controller);
                  }),
                ),
              ],
            ),
          Obx(() {
            if (!controller.voice.showDialogue.value) {
              return const SizedBox.shrink();
            }
            return const StudyAssistantDialogue();
          }),
        ],
      ),
    );
  }
}
