import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/size_constants.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import 'today_controller.dart';
import '../../data/models/revision_schedule_model.dart';

class TodayRevisionsScreen extends GetView<TodayController> {
  const TodayRevisionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(appBar: AppBar(title: Text('todaysRevisions'.tr)),
      body: Obx(() {
        if (controller.isLoading.value) return const Center(child: CircularProgressIndicator());
        final total = controller.overdue.length + controller.today.length;
        if (total == 0) return EmptyState(icon: Icons.check_circle_rounded,
          title: 'allCaughtUpTitle'.tr, subtitle: 'allCaughtUpSub'.tr);
        return RefreshIndicator(onRefresh: controller.load,
          child: ListView(physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: EdgeInsets.all(S.base), children: [
              if (controller.overdue.isNotEmpty) ...[
                _header('missed'.tr, controller.overdue.length, AppColors.error),
                ...controller.overdue.map((s) => _tile(s, AppColors.error, () => controller.markMissed(s.id), d, isOverdue: true)),
                SizedBox(height: S.base),
              ],
              if (controller.today.isNotEmpty) ...[
                _header('dueToday'.tr, controller.today.length, AppColors.primary),
                ...controller.today.map((s) => _tile(s, AppColors.primary, () => controller.markDone(s.id), d, isOverdue: false)),
              ],
              SizedBox(height: S.xxxl),
            ]));
      }));
  }

  Widget _header(String t, int c, Color col) => Padding(padding: EdgeInsets.symmetric(vertical: S.md),
    child: Row(children: [
      Container(width: 4, height: 20, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(2))),
      SizedBox(width: S.sm), Text(t, style: AppTextStyles.titleMedium.copyWith(color: col)),
      SizedBox(width: S.sm),
      Container(padding: EdgeInsets.symmetric(horizontal: S.sm, vertical: 2),
        decoration: BoxDecoration(color: col.withOpacity(0.12), borderRadius: BorderRadius.circular(S.radiusSm)),
        child: Text('$c', style: AppTextStyles.labelSmall.copyWith(color: col))),
    ]));

  Widget _tile(RevisionScheduleModel s, Color col, VoidCallback onDismiss, bool d, {required bool isOverdue}) {
    final subjectLabel = s.subjectName ?? 'subject'.tr;
    final topicLabel = s.topicName ?? 'topic'.tr;
    final dateStr = '${s.scheduledDate.day}/${s.scheduledDate.month}/${s.scheduledDate.year}';

    return Dismissible(key: ValueKey(s.id),
      direction: DismissDirection.endToStart, onDismissed: (_) => onDismiss(),
      background: Container(alignment: Alignment.centerRight, padding: EdgeInsets.only(right: S.xl),
        decoration: BoxDecoration(color: AppColors.success.withOpacity(0.2), borderRadius: BorderRadius.circular(S.radiusMd)),
        child: Icon(Icons.check_rounded, color: AppColors.success)),
      child: Container(margin: EdgeInsets.only(bottom: S.sm), padding: EdgeInsets.all(S.base),
        decoration: BoxDecoration(
          color: AppColors.surface(d),
          borderRadius: BorderRadius.circular(S.radiusMd),
          border: Border.all(color: AppColors.border(d))),
        child: Row(children: [
          Container(width: 4, height: 48, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(2))),
          SizedBox(width: S.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Subject name
            Text(subjectLabel, style: AppTextStyles.labelMedium.copyWith(color: AppColors.textMuted(d))),
            SizedBox(height: 2),
            // Topic name
            Text(topicLabel, style: AppTextStyles.titleSmall.copyWith(color: AppColors.textPrimary(d), fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            // Day label + date or Missed badge
            Row(children: [
              Text('dayLabel'.tr.replaceAll('{n}', '${s.dayNumber}'), style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted(d))),
              SizedBox(width: S.sm),
              Text('·', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted(d))),
              SizedBox(width: S.sm),
              Text(dateStr, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted(d))),
              if (isOverdue) ...[
                SizedBox(width: S.sm),
                Text('missed'.tr, style: AppTextStyles.labelSmall.copyWith(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 10)),
              ],
            ]),
          ])),
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted(d)),
        ])));
  }
}
