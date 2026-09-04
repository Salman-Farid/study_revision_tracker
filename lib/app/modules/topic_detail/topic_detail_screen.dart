import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/size_constants.dart';
import '../../theme/app_theme.dart';
import '../../widgets/revision_schedule_timeline.dart';
import 'topic_detail_controller.dart';

class TopicDetailScreen extends GetView<TopicDetailController> {
  const TopicDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
        return Scaffold(
      appBar: AppBar(title: Text(controller.topic.name, style: AppTextStyles.headlineMedium), actions: [
        IconButton(
          onPressed: controller.openVoiceAssistant,
          icon: Icon(Icons.mic_rounded, color: AppConstants.primaryColor),
          tooltip: 'studyRoutine'.tr,
        ),
      ]),
      body: Obx(() {
        if (controller.isLoading.value) return const Center(child: CircularProgressIndicator());
        return SingleChildScrollView(physics: const BouncingScrollPhysics(), padding: EdgeInsets.all(S.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _infoCard(d), SizedBox(height: S.xl),
            Text('revisionsLabel'.tr, style: AppTextStyles.headlineSmall.copyWith(color: AppColors.textPrimary(d))),
            SizedBox(height: S.base),
            RevisionScheduleTimeline(schedules: controller.schedules),
            if (controller.topic.notes?.isNotEmpty == true) ...[SizedBox(height: S.xl),
              Text('notes'.tr, style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary(d))),
              SizedBox(height: S.sm),
              Container(width: double.infinity, padding: EdgeInsets.all(S.base),
                decoration: BoxDecoration(color: AppColors.surface(d), borderRadius: BorderRadius.circular(S.radiusMd),
                  border: Border.all(color: AppColors.border(d))),
                child: Text(controller.topic.notes!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary(d))))],
            if (controller.topic.referenceAnswer?.isNotEmpty == true) ...[SizedBox(height: S.xl),
              Text('Reference', style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary(d))),
              SizedBox(height: S.sm),
              Container(width: double.infinity, padding: EdgeInsets.all(S.base),
                decoration: BoxDecoration(color: AppColors.success.withOpacity(0.05), borderRadius: BorderRadius.circular(S.radiusMd),
                  border: Border.all(color: AppColors.success.withOpacity(0.2))),
                child: Text(controller.topic.referenceAnswer!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary(d))))],
            SizedBox(height: S.xxxl),
          ]));
      }),
    );
  }

  Widget _infoCard(bool d) => Container(padding: EdgeInsets.all(S.xl),
    decoration: BoxDecoration(color: AppColors.surface(d), borderRadius: BorderRadius.circular(S.radiusLg),
      border: Border.all(color: AppColors.border(d)), boxShadow: S.shadowSm),
    child: Row(children: [
      _infoTile('Revisions', '${controller.topic.totalRevisions}', AppColors.primary),
    ]));

  Widget _infoTile(String l, String v, Color c) => Expanded(child: Column(children: [
    Text(v, style: AppTextStyles.headlineMedium.copyWith(color: c)),
    Text(l, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted(Get.isDarkMode))),
  ]));
}
