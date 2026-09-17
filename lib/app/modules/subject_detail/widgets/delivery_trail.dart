import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/size_constants.dart';
import '../../../theme/app_theme.dart';
import 'topic_card_badges.dart';

class DeliveryTrailContent extends StatelessWidget {
  final bool d;
  final dynamic t;
  final bool isCompleted;
  final List<String> dayLabels;
  final List<String> statusLabels;
  final List<Color> stageColors;
  final Color Function(Color, {bool dark}) softTint;
  final List<dynamic> schedules;
  final void Function(String dayLabel) onConfirmRevision;
  final VoidCallback onDelete;
  const DeliveryTrailContent({
    super.key,
    required this.d,
    required this.t,
    required this.isCompleted,
    required this.dayLabels,
    required this.statusLabels,
    required this.stageColors,
    required this.softTint,
    required this.schedules,
    required this.onConfirmRevision,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final completedCount = t.totalRevisions.clamp(0, 6);
    final nodeSize = 24.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: AppColors.border(d)),
        SizedBox(height: S.md),
        Text(
          isCompleted
              ? 'allRevisionsDone'.tr
              : 'revisionsOfDone'.tr.replaceAll('{n}', '$completedCount'),
          style: AppTextStyles.labelMedium.copyWith(
            color: isCompleted ? AppColors.success : AppColors.textMuted(d),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: S.md),
        // Each revision step is its own soft-tinted card (~1% color on white).
        ...List.generate(6, (i) {
          final isStepCompleted = i < completedCount;
          final isCurrent = i == completedCount && !isCompleted;
          final color = stageColors[i];
          final bg = softTint(color, dark: d);

          return Padding(
            padding: EdgeInsets.only(bottom: S.sm),
            child: GestureDetector(
              onTap: (isCurrent && !isCompleted)
                  ? () => onConfirmRevision(dayLabels[i])
                  : null,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: S.md, vertical: S.md),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(S.radiusMd),
                  border: Border.all(
                    color: isCurrent
                        ? color.withValues(alpha: 0.45)
                        : color.withValues(alpha: 0.12),
                    width: isCurrent ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Status node
                    Container(
                      width: nodeSize,
                      height: nodeSize,
                      decoration: BoxDecoration(
                        color: isStepCompleted || isCompleted
                            ? color
                            : isCurrent
                                ? color.withValues(alpha: 0.15)
                                : color.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.withValues(
                            alpha: (isStepCompleted || isCompleted || isCurrent) ? 1 : 0.35,
                          ),
                          width: isCurrent ? 2.2 : 1.5,
                        ),
                      ),
                      child: Center(
                        child: isStepCompleted || isCompleted
                            ? Icon(Icons.check_rounded, size: 13, color: Colors.white)
                            : isCurrent
                                ? Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : null,
                      ),
                    ),
                    SizedBox(width: S.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Day ${dayLabels[i]} — ${statusLabels[i]}',
                            style: AppTextStyles.labelMedium.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isStepCompleted || isCompleted || isCurrent
                                  ? color
                                  : AppColors.textMuted(d),
                            ),
                          ),
                          if (i < schedules.length)
                            Text(
                              formatTopicDate(schedules[i].scheduledDate),
                              style: AppTextStyles.labelSmall.copyWith(
                                fontSize: 10,
                                color: AppColors.textMuted(d),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isCurrent && !isCompleted)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(S.radiusFull),
                          border: Border.all(color: color, width: 1.2),
                        ),
                        child: Text(
                          'Mark Done',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    if (isStepCompleted || isCompleted)
                      Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check_rounded, size: 14, color: color),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
        SizedBox(height: S.sm),
        Padding(
          padding: EdgeInsets.only(right: S.xs),
          child: Align(
            alignment: Alignment.centerRight,
            child: TopicDeleteButton(d: d, t: t, onDelete: onDelete),
          ),
        ),
      ],
    );
  }
}
