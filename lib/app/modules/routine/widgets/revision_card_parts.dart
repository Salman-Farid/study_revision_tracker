import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/size_constants.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/status_badge.dart';
import '../routine_item_model.dart';

class RevisionStrategyBanner extends StatelessWidget {
  final int stage;
  const RevisionStrategyBanner({super.key, required this.stage});

  @override
  Widget build(BuildContext context) {
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
}

class CardStatusIndicator extends StatelessWidget {
  final bool isCompleted;
  final bool isDue;
  final bool d;
  const CardStatusIndicator({super.key, required this.isCompleted, required this.isDue, required this.d});

  @override
  Widget build(BuildContext context) =>
      StatusDotIcon(isCompleted: isCompleted, isDue: isDue, size: 36);
}

class RevisionChip extends StatelessWidget {
  final bool d;
  final String stageLabel;
  const RevisionChip({super.key, required this.d, required this.stageLabel});

  @override
  Widget build(BuildContext context) => StatusPill(
        label: stageLabel,
        color: AppConstants.infoColor,
        uppercase: true,
        fontSize: 10,
        letterSpacing: 0.5,
      );
}

class DayBadge extends StatelessWidget {
  final bool d;
  final String dayNumberLabel;
  const DayBadge({super.key, required this.d, required this.dayNumberLabel});

  @override
  Widget build(BuildContext context) => StatusPill(
        label: dayNumberLabel,
        color: AppColors.textMuted(d),
        fontSize: 10,
        fontWeight: FontWeight.w600,
      );
}

class CardStatusText extends StatelessWidget {
  final bool d;
  final RoutineItemStatus status;
  const CardStatusText({super.key, required this.d, required this.status});

  @override
  Widget build(BuildContext context) {
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
