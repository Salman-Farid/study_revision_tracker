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
    return Scaffold(
      appBar: AppBar(title: Text('todaysRevisions'.tr)),
      body: Column(
        children: [
          _chips(d),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final tab = controller.selectedTab.value;
              final list = tab == 0
                  ? controller.today
                  : tab == 1
                      ? controller.overdue
                      : controller.upcoming;

              if (list.isEmpty) {
                return RefreshIndicator(
                  onRefresh: controller.load,
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: EmptyState(
                          icon: tab == 1
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_rounded,
                          title: tab == 0
                              ? 'allCaughtUpTitle'.tr
                              : tab == 1
                                  ? 'missed'.tr
                                  : 'statUpcoming'.tr,
                          subtitle: tab == 0
                              ? 'allCaughtUpSub'.tr
                              : tab == 1
                                  ? 'noPendingRevisions'.tr
                                  : 'noRevisionsThisDay'.tr,
                        ),
                      ),
                    ),
                  ),
                );
              }

              final accent = tab == 0
                  ? AppColors.primary
                  : tab == 1
                      ? AppColors.error
                      : AppColors.info;

              return RefreshIndicator(
                onRefresh: controller.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics()),
                  padding: EdgeInsets.all(S.base),
                  children: [
                    if (tab != 2) ...[
                      // Completing a missed/today revision → completed.
                      ...list.map((s) => _tile(
                            s,
                            accent,
                            () => controller.markDone(s.id),
                            d,
                            isOverdue: tab == 1,
                          )),
                    ] else
                      ...list.map((s) => _tile(
                            s,
                            accent,
                            () => controller.markDone(s.id),
                            d,
                            isOverdue: false,
                          )),
                    SizedBox(height: S.xxxl),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _chips(bool d) {
    return Obx(() {
      final selected = controller.selectedTab.value;
      final items = [
        (0, 'statToday'.tr, controller.today.length, AppColors.primary),
        (1, 'missed'.tr, controller.overdue.length, AppColors.error),
        (2, 'statUpcoming'.tr, controller.upcoming.length, AppColors.info),
      ];
      return Padding(
        padding: EdgeInsets.fromLTRB(S.base, S.sm, S.base, S.sm),
        child: Row(
          children: [
            for (final it in items) ...[
              Expanded(
                child: _chip(
                  d,
                  it.$2,
                  it.$3,
                  it.$4,
                  selected == it.$1,
                  () => controller.selectedTab.value = it.$1,
                ),
              ),
              if (it.$1 != 2) SizedBox(width: S.sm),
            ],
          ],
        ),
      );
    });
  }

  Widget _chip(
      bool d, String label, int count, Color col, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(vertical: S.sm, horizontal: S.xs),
        decoration: BoxDecoration(
          color: selected ? col.withValues(alpha: 0.12) : AppColors.surface(d),
          borderRadius: BorderRadius.circular(S.radiusFull),
          border: Border.all(
            color: selected ? col : AppColors.border(d),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelMedium.copyWith(
                  color: selected ? col : AppColors.textSecondary(d),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (count > 0) ...[
              SizedBox(width: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? col : AppColors.textMuted(d).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(S.radiusFull),
                ),
                child: Text(
                  '$count',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: selected ? Colors.white : AppColors.textMuted(d),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tile(RevisionScheduleModel s, Color col, VoidCallback onDismiss, bool d,
      {required bool isOverdue}) {
    final subjectLabel = s.subjectName ?? 'subject'.tr;
    final topicLabel = s.topicName ?? 'topic'.tr;
    final dateStr =
        '${s.scheduledDate.day}/${s.scheduledDate.month}/${s.scheduledDate.year}';

    return Dismissible(
      key: ValueKey(s.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: S.xl),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.2),
          borderRadius: BorderRadius.circular(S.radiusMd),
        ),
        child: Icon(Icons.check_rounded, color: AppColors.success),
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: S.sm),
        padding: EdgeInsets.all(S.base),
        decoration: BoxDecoration(
          color: AppColors.surface(d),
          borderRadius: BorderRadius.circular(S.radiusMd),
          border: Border.all(color: AppColors.border(d)),
        ),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              width: 4,
              decoration:
                  BoxDecoration(color: col, borderRadius: BorderRadius.circular(2)),
            ),
            SizedBox(width: S.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(subjectLabel,
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.textMuted(d))),
                SizedBox(height: 2),
                Text(topicLabel,
                    style: AppTextStyles.titleSmall
                        .copyWith(color: AppColors.textPrimary(d), fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Flexible(
                  child: Wrap(children: [
                    Text('dayLabel'.tr.replaceAll('{n}', '${s.dayNumber}'),
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted(d))),
                    SizedBox(width: S.sm),
                    Text('·',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted(d))),
                    SizedBox(width: S.sm),
                    Text(dateStr,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted(d))),
                    if (isOverdue) ...[
                      SizedBox(width: S.sm),
                      Text('missed'.tr,
                          style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                              fontSize: 10)),
                    ],
                  ]),
                ),
              ]),
            ),
            // Full-height swap box (no top/bottom margin)
            Container(
              margin: EdgeInsets.only(left: S.sm),
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              width: 72,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(S.radiusSm),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.swap_horiz_rounded, color: AppColors.success, size: 20),
                  SizedBox(height: 4),
                  Text(
                    'swap left\nto complete',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 9,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
