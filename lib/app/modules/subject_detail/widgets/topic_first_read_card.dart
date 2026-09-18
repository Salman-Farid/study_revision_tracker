import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/size_constants.dart';
import '../../../theme/app_theme.dart';
import 'topic_card_badges.dart';

class TopicFirstReadCard extends StatelessWidget {
  final bool d;
  final dynamic t;
  final int index;
  final VoidCallback onComplete;
  final VoidCallback onDelete;
  /// Top-level topic without subtopics: tap opens subtopic screen.
  final VoidCallback? onTap;
  /// Show › at card end when [onTap] opens subtopics.
  final bool showOpenChevron;
  const TopicFirstReadCard({
    super.key,
    required this.d,
    required this.t,
    required this.index,
    required this.onComplete,
    required this.onDelete,
    this.onTap,
    this.showOpenChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      key: ValueKey('fr_${t.id}'),
      margin: EdgeInsets.only(bottom: S.md),
      padding: EdgeInsets.symmetric(horizontal: S.md, vertical: S.md),
      decoration: BoxDecoration(
        color: AppColors.surface(d),
        borderRadius: BorderRadius.circular(S.radiusLg),
        border: Border.all(color: AppColors.border(d)),
      ),
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
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 20),
          ),
          SizedBox(width: S.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 6),
                TopicBadge(d: d, label: 'firstRead'.tr, color: AppColors.primary),
              ],
            ),
          ),
          SizedBox(width: S.sm),
          CompleteChip(onTap: onComplete),
          SizedBox(width: S.sm),
          TopicDeleteButton(d: d, t: t, onDelete: onDelete),
          if (showOpenChevron) ...[
            SizedBox(width: S.xs),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted(d),
              size: 22,
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(
      key: ValueKey('fr_hit_${t.id}'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }
}

class CompleteChip extends StatelessWidget {
  final VoidCallback onTap;
  const CompleteChip({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // No Material/InkWell — avoid hover splash/shadow on web.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(S.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.check_circle_rounded, size: 10, color: Colors.white),
            SizedBox(width: 2),
            Text(
              'Complete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
