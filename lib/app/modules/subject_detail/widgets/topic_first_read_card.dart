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
  const TopicFirstReadCard({
    super.key,
    required this.d,
    required this.t,
    required this.index,
    required this.onComplete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('fr_${t.id}'),
      margin: EdgeInsets.only(bottom: S.md),
      padding: EdgeInsets.symmetric(horizontal: S.md, vertical: S.md),
      decoration: BoxDecoration(
        color: AppColors.surface(d),
        borderRadius: BorderRadius.circular(S.radiusLg),
        border: Border.all(color: AppColors.border(d)),
        boxShadow: S.shadowSm,
      ),
      child: Row(
        children: [
          // Press-and-drag reorder grip (explicit — not a whole-row default handle).
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
          // Title + badge
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textPrimary(d),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                TopicBadge(d: d, label: 'firstRead'.tr, color: AppColors.primary),
              ],
            ),
          ),
          SizedBox(width: S.sm),
          // Complete sits mid-right, not glued to the bin.
          Flexible(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: CompleteChip(onTap: onComplete),
            ),
          ),
          SizedBox(width: S.md),
          TopicDeleteButton(d: d, t: t, onDelete: onDelete),
        ],
      ),
    );
  }
}

class CompleteChip extends StatelessWidget {
  final VoidCallback onTap;
  const CompleteChip({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(S.radiusFull),
        onTap: onTap,
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
      ),
    );
  }
}
