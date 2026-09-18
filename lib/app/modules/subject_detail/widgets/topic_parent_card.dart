import 'package:flutter/material.dart';
import '../../../core/constants/size_constants.dart';
import '../../../data/models/topic_model.dart';
import '../../../theme/app_theme.dart';

/// Topic with subtopics — ring + % ; tap opens subtopic list.
/// No Material ink/hover shadow; chevron at card end, centered.
class TopicParentCard extends StatelessWidget {
  const TopicParentCard({
    super.key,
    required this.d,
    required this.topic,
    required this.ringProgress,
    required this.isDone,
    required this.onOpen,
  });

  final bool d;
  final TopicModel topic;
  final double ringProgress;
  final bool isDone;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final pct = (ringProgress * 100).round();
    final kids = topic.subtopicCount;
    return GestureDetector(
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: EdgeInsets.only(bottom: S.md),
        padding: EdgeInsets.symmetric(horizontal: S.md, vertical: S.md),
        decoration: BoxDecoration(
          color: AppColors.surface(d),
          borderRadius: BorderRadius.circular(S.radiusLg),
          border: Border.all(
            color: isDone
                ? AppColors.success.withValues(alpha: 0.45)
                : AppColors.border(d),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      value: ringProgress.clamp(0.0, 1.0),
                      strokeWidth: 4,
                      backgroundColor:
                          (isDone ? AppColors.success : AppColors.primary)
                              .withValues(alpha: 0.15),
                      color: isDone ? AppColors.success : AppColors.primary,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Text(
                    '$pct%',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isDone ? AppColors.success : AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: S.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${topic.name}',
                    softWrap: true,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.textPrimary(d),
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:
                              (isDone ? AppColors.success : AppColors.primary)
                                  .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(S.radiusSm),
                        ),
                        child: Text(
                          isDone ? 'Done' : 'Subtopics',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: isDone
                                ? AppColors.success
                                : AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      Text(
                        '$kids subtopic${kids == 1 ? '' : 's'} · $pct%',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted(d),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Chevron at the END, vertically centered.
            SizedBox(width: S.xs),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted(d),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
