import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/size_constants.dart';
import '../../theme/app_theme.dart';
import 'revision_session_controller.dart';

class RevisionSessionScreen extends GetView<RevisionSessionController> {
  const RevisionSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
        return Scaffold(appBar: AppBar(title: Text(controller.topic.name)),
      body: SingleChildScrollView(physics: const BouncingScrollPhysics(), padding: EdgeInsets.all(S.xl),
        child: Column(children: [
          _timer(d), SizedBox(height: S.xxxl), _controls(d), SizedBox(height: S.xxxl),
          _recallRating(d), SizedBox(height: S.xl), _confidenceSlider(d), SizedBox(height: S.xl),
          TextField(controller: controller.notesCtrl,
            decoration: const InputDecoration(labelText: 'Session Notes', prefixIcon: Icon(Icons.note_alt_rounded)), maxLines: 3),
          SizedBox(height: S.xxl),
          Obx(() => SizedBox(width: double.infinity, height: S.buttonHeight,
            child: ElevatedButton.icon(onPressed: controller.isSaving.value ? null : controller.complete,
              icon: controller.isSaving.value ? const SizedBox(height: 20, width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_rounded),
              label: Text(controller.isSaving.value ? 'Saving...' : 'Complete Session'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success)))),
          SizedBox(height: S.xxxl),
        ])));
  }

  Widget _timer(bool d) => Obx(() => Container(
    padding: EdgeInsets.symmetric(vertical: S.xxxl, horizontal: S.xxl),
    decoration: BoxDecoration(color: AppColors.surface(d), borderRadius: BorderRadius.circular(S.radiusXl),
      border: Border.all(color: AppColors.border(d)), boxShadow: S.shadowMd),
    child: Column(children: [
      Text(controller.formattedTime, style: AppTextStyles.headlineLarge.copyWith(
        fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()],
        color: AppColors.textPrimary(d))),
      SizedBox(height: S.sm),
      Text(controller.isRunning.value ? (controller.isPaused.value ? 'Paused' : 'Revising...') : 'Ready',
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted(d))),
    ])));

  Widget _controls(bool d) => Obx(() => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
    if (!controller.isRunning.value) _btn(Icons.play_arrow_rounded, 'Start', AppColors.success, controller.start)
    else ...[
      _btn(controller.isPaused.value ? Icons.play_arrow_rounded : Icons.pause_rounded,
        controller.isPaused.value ? 'Resume' : 'Pause', AppColors.warning,
        controller.isPaused.value ? controller.resume : controller.pause),
      SizedBox(width: S.base),
      _btn(Icons.stop_rounded, 'Stop', AppColors.error, controller.stop),
    ],
  ]));

  Widget _btn(IconData icon, String label, Color col, VoidCallback onTap) => GestureDetector(onTap: onTap,
    child: Column(children: [
      Container(padding: EdgeInsets.all(S.base), decoration: BoxDecoration(color: col.withOpacity(0.12), shape: BoxShape.circle),
        child: Icon(icon, color: col, size: S.iconLg)),
      SizedBox(height: S.xs), Text(label, style: AppTextStyles.labelSmall.copyWith(color: col)),
    ]));

  Widget _recallRating(bool d) {
    final ratings = [['Forgot', 'forgot', AppColors.forgot, Icons.close_rounded],
      ['Partial', 'partial', AppColors.partial, Icons.remove_rounded],
      ['Good', 'good', AppColors.good, Icons.check_rounded],
      ['Perfect', 'perfect', AppColors.perfect, Icons.check_circle_rounded]];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('How well did you recall?', style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary(d))),
      SizedBox(height: S.md),
      Obx(() => Row(children: ratings.map((r) {
        final sel = controller.selectedRating.value == r[1];
        return Expanded(child: GestureDetector(onTap: () => controller.selectedRating.value = r[1] as String,
          child: AnimatedContainer(duration: AppConstants.shortDuration,
            margin: EdgeInsets.symmetric(horizontal: S.xs), padding: EdgeInsets.symmetric(vertical: S.md),
            decoration: BoxDecoration(color: sel ? (r[2] as Color).withOpacity(0.15) : AppColors.surface(d),
              borderRadius: BorderRadius.circular(S.radiusMd),
              border: Border.all(color: sel ? r[2] as Color : AppColors.border(d), width: sel ? 2 : 1)),
            child: Column(children: [
              Icon(r[3] as IconData, color: r[2] as Color, size: S.iconLg),
              SizedBox(height: S.xs),
              Text(r[0] as String, style: AppTextStyles.labelSmall.copyWith(
                color: sel ? r[2] as Color : AppColors.textMuted(d), fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
            ]))));
      }).toList())),
    ]);
  }

  Widget _confidenceSlider(bool d) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('Confidence', style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary(d))),
      Obx(() => Text('${(controller.confidence.value * 100).round()}%',
        style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700))),
    ]),
    Obx(() => Slider(value: controller.confidence.value, onChanged: (v) => controller.confidence.value = v,
      activeColor: AppColors.primary, inactiveColor: AppColors.primary.withOpacity(0.15))),
  ]);
}
