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
      ),
      floatingActionButton: _AnimatedAssistantFab(
        onPressed: controller.openAssistant,
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
              // No white PaneFrame cards — content sits on the screen background.
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
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: AppColors.border(d),
                  ),
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

/// Bottom FAB that continuously bounces / tilts like a cartoon character.
class _AnimatedAssistantFab extends StatefulWidget {
  const _AnimatedAssistantFab({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_AnimatedAssistantFab> createState() => _AnimatedAssistantFabState();
}

class _AnimatedAssistantFabState extends State<_AnimatedAssistantFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;
  late final Animation<double> _dy;
  late final Animation<double> _tilt;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.1), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 0.96), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.96, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
    _dy = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeInOut),
    );
    _tilt = Tween<double>(begin: -0.08, end: 0.08).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        return Transform.translate(
          offset: Offset(0, _dy.value),
          child: Transform.rotate(
            angle: _tilt.value,
            child: Transform.scale(
              scale: _scale.value,
              child: child,
            ),
          ),
        );
      },
      child: FloatingActionButton(
        heroTag: 'routine_assistant_fab',
        backgroundColor: AppConstants.primaryColor,
        onPressed: widget.onPressed,
        tooltip: 'assistant'.tr,
        child: const Icon(Icons.mic_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}
