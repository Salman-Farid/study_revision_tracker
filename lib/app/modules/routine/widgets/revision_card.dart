import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/size_constants.dart';
import '../../../theme/app_theme.dart';
import '../routine_item_model.dart';
import 'revision_card_parts.dart';
import 'technique_guidance.dart';

class RevisionCard extends StatelessWidget {
  final RoutineItemModel item;
  final VoidCallback? onTap;

  const RevisionCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    final isCompleted = item.status == RoutineItemStatus.completed;
    final isDue = item.status == RoutineItemStatus.due;

    // Bug-06 FIX: Frosted glass container — ClipRRect + BackdropFilter + translucent fill
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(S.radiusLg),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            margin: EdgeInsets.only(bottom: 4),
            padding: EdgeInsets.all(S.sm),
            decoration: BoxDecoration(
              color: AppColors.surface(d).withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(S.radiusLg),
              border: Border.all(
                color: isCompleted
                    ? AppConstants.successColor.withValues(alpha: 0.35)
                    : isDue
                        ? AppConstants.warningColor.withValues(alpha: 0.4)
                        : (d ? Colors.white : Colors.black).withValues(alpha: 0.08),
                width: (isDue && !isCompleted) ? 1.5 : 1,
              ),
                          ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Row: Status, Revision, Time ──
            Row(
              children: [
                CardStatusIndicator(isCompleted: isCompleted, isDue: isDue, d: d),
                SizedBox(width: S.sm),
                RevisionChip(d: d, stageLabel: item.revisionStageLabel),
                Spacer(),
                if (item.sessionNumber != null)
                  Text(
                    item.sessionNumber!,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textMuted(d),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (item.sessionNumber != null && item.timeSlot != null)
                  SizedBox(width: S.sm),
                if (item.timeSlot != null)
                  Text(
                    item.timeSlot!,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textMuted(d),
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
            if (item.dayNumberLabel.isNotEmpty) ...[
              SizedBox(height: 2),
              DayBadge(d: d, dayNumberLabel: item.dayNumberLabel),
            ],
            SizedBox(height: S.sm),
            // ── Topic & Subject ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                item.topicName,
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary(d),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            SizedBox(height: 2),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                item.subjectName,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary(d),
                  fontSize: 12,
                ),
              ),
            ),
            SizedBox(height: S.sm),
            // ── Session Type + Duration + Status ──
            Row(
              children: [
                Icon(
                  item.sessionTypeIcon ?? Icons.help_outline_rounded,
                  size: 14,
                  color: AppConstants.infoColor,
                ),
                SizedBox(width: 4),
                Text(
                  item.sessionTypeLabel ?? '',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppConstants.infoColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                if (item.durationMinutes != null) ...[
                  SizedBox(width: S.md),
                  Icon(
                    Icons.schedule_rounded,
                    size: 12,
                    color: AppColors.textMuted(d),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '${item.durationMinutes} min',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textMuted(d),
                    ),
                  ),
                ],
                Spacer(),
                CardStatusText(d: d, status: item.status),
              ],
            ),
            // ── Revision Strategy ──
            SizedBox(height: S.sm),
            RevisionStrategyBanner(stage: item.revisionNumber ?? 1),
            // ── Technique Guidance ──
            if (item.technique != null && item.technique!.isNotEmpty) ...[
              SizedBox(height: S.sm),
              TechniqueGuidanceBox(technique: item.technique!),
            ],
            // ── Notes ──
            if (item.notes != null && item.notes!.isNotEmpty) ...[
              SizedBox(height: S.sm),
              Text(
                item.notes!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted(d),
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ), // Column
      ), // Container
    ), // BackdropFilter
  ), // ClipRRect
);
  }
}
