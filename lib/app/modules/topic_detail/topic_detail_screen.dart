import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/size_constants.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/revision_schedule_timeline.dart';
import 'topic_detail_controller.dart';

class TopicDetailScreen extends GetView<TopicDetailController> {
  const TopicDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
        return Scaffold(
      appBar: AppBar(title: Text(controller.topic.name, style: AppTextStyles.headlineMedium)),
      body: Obx(() {
        if (controller.isLoading.value) return const Center(child: CircularProgressIndicator());
        return SingleChildScrollView(physics: const BouncingScrollPhysics(), padding: EdgeInsets.all(S.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _infoCard(d), SizedBox(height: S.xl),
            Text('Revision Schedule', style: AppTextStyles.headlineSmall.copyWith(color: AppColors.textPrimary(d))),
            SizedBox(height: S.base),
            RevisionScheduleTimeline(schedules: controller.schedules),
            SizedBox(height: S.xl),
            SizedBox(width: double.infinity, height: S.buttonHeight, child: ElevatedButton.icon(
              onPressed: () => Get.toNamed('/revision-session/${controller.topic.id}',
                arguments: {'topic': controller.topic, 'subject': controller.subject,
                  'schedules': controller.schedules.toList()}),
              icon: const Icon(Icons.play_arrow_rounded), label: const Text('Start Revision'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white))),
            if (controller.topic.notes?.isNotEmpty == true) ...[SizedBox(height: S.xl),
              Text('Notes', style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary(d))),
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
            SizedBox(height: S.xl),
            Text('History', style: AppTextStyles.headlineSmall.copyWith(color: AppColors.textPrimary(d))),
            SizedBox(height: S.base),
            ...controller.sessions.map((s) {
              final col = s.recallRating != null ? AppColors.ratingColor(s.recallRating!) : AppColors.textMuted(d);
              return Container(margin: EdgeInsets.only(bottom: S.sm), padding: EdgeInsets.all(S.md),
                decoration: BoxDecoration(color: AppColors.surface(d), borderRadius: BorderRadius.circular(S.radiusMd),
                  border: Border.all(color: AppColors.border(d))),
                child: Row(children: [
                  Container(padding: EdgeInsets.symmetric(horizontal: S.sm, vertical: S.xs),
                    decoration: BoxDecoration(color: col.withOpacity(0.12), borderRadius: BorderRadius.circular(S.radiusSm)),
                    child: Text(s.recallRating?.toUpperCase() ?? 'N/A', style: AppTextStyles.labelSmall.copyWith(color: col))),
                  SizedBox(width: S.md),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.durationFormatted, style: AppTextStyles.titleSmall.copyWith(color: AppColors.textPrimary(d))),
                    Text('${s.startedAt.day}/${s.startedAt.month}/${s.startedAt.year}',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted(d))),
                  ])),
                ]));
            }),
            if (controller.sessions.isEmpty) Text('No sessions yet',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted(d))),
            SizedBox(height: S.xxxl),
          ]));
      }),
    );
  }

  Widget _infoCard(bool d) => Container(padding: EdgeInsets.all(S.xl),
    decoration: BoxDecoration(color: AppColors.surface(d), borderRadius: BorderRadius.circular(S.radiusLg),
      border: Border.all(color: AppColors.border(d)), boxShadow: S.shadowSm),
    child: Row(children: [
      _infoTile('Mastery', '${(controller.topic.masteryLevel * 100).round()}%',
        controller.topic.masteryLevel >= 0.75 ? AppColors.success : AppColors.warning),
      _infoTile('Confidence', '${(controller.topic.confidence * 100).round()}%', AppColors.info),
      _infoTile('Revisions', '${controller.topic.totalRevisions}', AppColors.primary),
    ]));

  Widget _infoTile(String l, String v, Color c) => Expanded(child: Column(children: [
    Text(v, style: AppTextStyles.headlineMedium.copyWith(color: c)),
    Text(l, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted(Get.isDarkMode))),
  ]));
}
