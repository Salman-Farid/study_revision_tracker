import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/size_constants.dart';
import '../../../theme/app_theme.dart';
import '../../../data/models/revision_schedule_model.dart';

class TodayRevisionTile extends StatelessWidget {
  final RevisionScheduleModel s;
  final Color col;
  final VoidCallback onDismiss;
  final bool d;
  final bool isOverdue;
  const TodayRevisionTile({
    super.key,
    required this.s,
    required this.col,
    required this.onDismiss,
    required this.d,
    required this.isOverdue,
  });

  @override
  Widget build(BuildContext context) {
    final subjectLabel = s.subjectName ?? 'subject'.tr;
    final parent = s.parentTopicName;
    final topicLabel = (parent != null && parent.isNotEmpty)
        ? '${s.topicName ?? 'topic'.tr}'
        : (s.topicName ?? 'topic'.tr);
    final line2 = (parent != null && parent.isNotEmpty)
        ? '$parent · $topicLabel'
        : topicLabel;
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
                Text(line2,
                    softWrap: true,
                    style: AppTextStyles.titleSmall
                        .copyWith(color: AppColors.textPrimary(d), fontWeight: FontWeight.w600)),
                if (parent != null && parent.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      s.hierarchyLabel,
                      softWrap: true,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted(d), fontSize: 11),
                    ),
                  ),
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
