import 'package:flutter/material.dart';
import '../../../core/constants/size_constants.dart';
import '../../../theme/app_theme.dart';
import 'delivery_trail.dart';
import 'expandable_card.dart';
import 'topic_card_badges.dart';

class TopicRevisionCard extends StatelessWidget {
  final bool d;
  final dynamic t;
  final bool isCompleted;
  final int index;
  final List<dynamic> schedules;
  final void Function(String dayLabel) onConfirmRevision;
  final VoidCallback onDelete;
  /// Top-level topic without subtopics: card body opens subtopic screen.
  /// Expand trail stays on the ⌄ arrow.
  final VoidCallback? onOpenSubtopics;
  const TopicRevisionCard({
    super.key,
    required this.d,
    required this.t,
    required this.isCompleted,
    required this.index,
    required this.schedules,
    required this.onConfirmRevision,
    required this.onDelete,
    this.onOpenSubtopics,
  });

  @override
  Widget build(BuildContext context) {
    final dayLabels = ['1', '3', '7', '14', '30', '90'];
    final statusLabels = [
      '1st Revision', '2nd Revision', '3rd Revision',
      '4th Revision', '5th Revision', '6th Revision',
    ];
    // Distinct base hues for the 6 revision stages (used for icons/text/borders).
    final List<Color> stageColors = [
      const Color(0xFF5B8DEF), // Day 1  — blue
      const Color(0xFF4CAF7A), // Day 3  — green
      const Color(0xFF9B7BFF), // Day 7  — violet
      const Color(0xFFE8A33D), // Day 14 — amber
      const Color(0xFFEF6B8A), // Day 30 — rose
      const Color(0xFF3DB8C9), // Day 90 — teal
    ];

    /// Soft card fill: ~1% color on white (very light pastel wash).
    Color softTint(Color base, {bool dark = false}) {
      final t = dark ? 0.12 : 0.06;
      return Color.lerp(dark ? const Color(0xFF1A1D26) : Colors.white, base, t)!;
    }

    return ExpandableCard(
      key: Key('exp_${t.id}'),
      builder: (context, isExpanded, toggleExpand, animController) {
        return Container(
          margin: EdgeInsets.only(bottom: S.md),
          decoration: BoxDecoration(
            color: AppColors.surface(d),
            borderRadius: BorderRadius.circular(S.radiusLg),
            border: Border.all(
              color: isExpanded
                  ? (isCompleted ? AppColors.success : AppColors.primary).withValues(alpha: 0.4)
                  : AppColors.border(d),
              width: isExpanded ? 1.5 : 1,
            ),
                      ),
          child: Column(
            children: [
              // Body: open subtopics when provided; expand arrow still expands.
              GestureDetector(
                onTap: onOpenSubtopics ?? toggleExpand,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: S.md, vertical: S.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ReorderableDragStartListener(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.drag_indicator_rounded,
                            color: AppColors.textMuted(d),
                            size: 22,
                          ),
                        ),
                      ),
                      CollapsedIndicator(d: d, t: t, isCompleted: isCompleted),
                      SizedBox(width: S.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${t.name}',
                              softWrap: true,
                              style: AppTextStyles.titleMedium.copyWith(
                                color: AppColors.textPrimary(d),
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                            SizedBox(height: S.xs),
                            TopicStatusBadge(d: d, t: t, dayLabels: dayLabels),
                          ],
                        ),
                      ),
                      if (onOpenSubtopics != null) ...[
                        SizedBox(width: S.xs),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textMuted(d),
                          size: 22,
                        ),
                      ],
                      // Expand control — always expands/collapses the trail.
                      SizedBox(width: S.xs),
                      GestureDetector(
                        onTap: toggleExpand,
                        behavior: HitTestBehavior.opaque,
                        child: Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textMuted(d),
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── EXPANDED TRAIL (slowmo fade+slide) ──
              AnimatedExpanded(
                controller: animController,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(S.base, 0, S.base, S.base),
                  child: DeliveryTrailContent(
                    d: d,
                    t: t,
                    isCompleted: isCompleted,
                    dayLabels: dayLabels,
                    statusLabels: statusLabels,
                    stageColors: stageColors,
                    softTint: softTint,
                    schedules: schedules,
                    onConfirmRevision: onConfirmRevision,
                    onDelete: onDelete,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CollapsedIndicator extends StatelessWidget {
  final bool d;
  final dynamic t;
  final bool isCompleted;
  const CollapsedIndicator({super.key, required this.d, required this.t, required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    final total = t.totalRevisions.clamp(0, 6);
    final progress = total / 6;
    final color = isCompleted
        ? AppColors.success
        : AppColors.primary;

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 4,
              color: AppColors.border(d),
            ),
          ),
          // Progress circle
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 4,
              color: color,
              strokeCap: StrokeCap.round,
            ),
          ),
          // Center text
          Text(
            '$total',
            style: AppTextStyles.titleMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
