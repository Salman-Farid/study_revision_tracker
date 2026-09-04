import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/size_constants.dart';
import '../../../theme/app_theme.dart';
import '../routine_item_model.dart';

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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: d ? 0.25 : 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Row: Status, Revision, Time ──
            Row(
              children: [
                _buildStatusIndicator(isCompleted, isDue, d),
                SizedBox(width: S.sm),
                _buildRevisionChip(d),
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
              _buildDayBadge(d),
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
                  item.sessionTypeIcon,
                  size: 14,
                  color: AppConstants.infoColor,
                ),
                SizedBox(width: 4),
                Text(
                  item.sessionTypeLabel,
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
                _buildStatusText(d),
              ],
            ),
            // ── Revision Strategy ──
            SizedBox(height: S.sm),
            _buildRevisionStrategy(d),
            // ── Technique Guidance ──
            if (item.technique != null && item.technique!.isNotEmpty) ...[
              SizedBox(height: S.sm),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(S.sm),
                decoration: BoxDecoration(
                  color: AppConstants.infoColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(S.xs),
                  border: Border.all(
                    color: AppConstants.infoColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.psychology_rounded,
                      size: 14,
                      color: AppConstants.infoColor,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.technique!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppConstants.infoColor,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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

  Widget _buildRevisionStrategy(bool d) {
    final stage = item.revisionNumber ?? 1;
    String strategy;
    String icon;
    Color color;

    switch (stage) {
      case 1:
        strategy = 'Day 3 Revision: Recall key concepts. Close book, write summary from memory. Then self-quiz.';
        icon = '1';
        color = AppConstants.infoColor;
        break;
      case 2:
        strategy = 'Day 7 Revision: Focus on weak points. Use flashcards. Teach the concept to yourself aloud.';
        icon = '2';
        color = AppConstants.primaryColor;
        break;
      case 3:
        strategy = 'Day 14 Revision: Solve practice problems. Connect concepts to real examples.';
        icon = '3';
        color = const Color(0xFF9C27B0);
        break;
      case 4:
        strategy = 'Day 30 Revision: Deep review. Explain connections between topics. Create concept maps.';
        icon = '4';
        color = const Color(0xFFE91E63);
        break;
      case 5:
        strategy = 'Day 90 Revision: Final consolidation. Quick self-test on all subtopics. Reinforce weak areas.';
        icon = '5';
        color = AppConstants.warningColor;
        break;
      default:
        strategy = 'Advanced revision: Focus on synthesis and cross-topic connections.';
        icon = '6';
        color = AppConstants.errorColor;
        break;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(S.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(S.xs),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                icon,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              strategy,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(bool isCompleted, bool isDue, bool d) {
    Color bgColor;
    Color iconColor;
    IconData icon;

    if (isCompleted) {
      bgColor = AppConstants.successColor.withValues(alpha: 0.12);
      iconColor = AppConstants.successColor;
      icon = Icons.check_rounded;
    } else if (isDue) {
      bgColor = AppConstants.warningColor.withValues(alpha: 0.12);
      iconColor = AppConstants.warningColor;
      icon = Icons.replay_rounded;
    } else {
      bgColor = AppConstants.infoColor.withValues(alpha: 0.12);
      iconColor = AppConstants.infoColor;
      icon = Icons.replay_rounded;
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
      ),
      child: Icon(icon, size: 18, color: iconColor),
    );
  }

  Widget _buildRevisionChip(bool d) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: S.sm, vertical: 2),
      decoration: BoxDecoration(
        color: AppConstants.infoColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(S.radiusXs),
      ),
      child: Text(
        item.revisionStageLabel.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: AppConstants.infoColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDayBadge(bool d) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.textMuted(d).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(S.radiusXs),
      ),
      child: Text(
        item.dayNumberLabel,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textMuted(d),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusText(bool d) {
    final status = item.status;
    String text;
    Color color;

    switch (status) {
      case RoutineItemStatus.completed:
        text = 'Completed';
        color = AppConstants.successColor;
      case RoutineItemStatus.due:
        text = 'Due today';
        color = AppConstants.warningColor;
      case RoutineItemStatus.upcoming:
        text = 'Upcoming';
        color = AppConstants.infoColor;
      case RoutineItemStatus.pending:
        text = 'Pending';
        color = AppColors.textMuted(d);
    }

    return Text(
      text,
      style: AppTextStyles.labelSmall.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: 11,
      ),
    );
  }
}
