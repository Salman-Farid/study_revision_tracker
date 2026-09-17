import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/size_constants.dart';
import '../../../theme/app_theme.dart';
import '../../../data/models/class_routine_model.dart';
import '../routine_controller.dart';
import '../routine_item_model.dart';

class RoutineTile extends StatelessWidget {
  final RoutineDisplayItem item;
  final bool d;
  const RoutineTile({super.key, required this.item, required this.d});

  /// Soft background color per block type (99% white, 1% tint)
  Color _bgColor() {
    switch (item.type) {
      case 'class':
        return const Color(0xFFF8FAFF); // barely-there blue
      case 'study':
      case 'first_read':
      case 'revision':
        return const Color(0xFFF7FBF7); // barely-there green
      case 'break':
        return const Color(0xFFFEFCF6); // barely-there amber
      case 'meal':
        return const Color(0xFFFEF8FA); // barely-there pink
      case 'nap':
        return const Color(0xFFFBF8FE); // barely-there purple
      case 'recall':
        return const Color(0xFFF6FDFE); // barely-there cyan
      case 'question_practice':
        return const Color(0xFFFEFAF5); // barely-there orange
      case 'review':
        return const Color(0xFFF6FDF8); // barely-there teal
      default:
        return AppColors.surfaceLight;
    }
  }

  /// Accent color for icon/strip
  Color _accentColor() {
    switch (item.type) {
      case 'class':
        return const Color(0xFF5B8DEF); // blue
      case 'study':
      case 'first_read':
      case 'revision':
        return const Color(0xFF4CAF50); // green
      case 'break':
        return const Color(0xFFFFB74D); // amber
      case 'meal':
        return const Color(0xFFEC407A); // pink
      case 'nap':
        return const Color(0xFFAB7EFF); // purple
      case 'recall':
        return const Color(0xFF26C6DA); // cyan
      case 'question_practice':
        return const Color(0xFFFF9800); // orange
      case 'review':
        return const Color(0xFF66BB6A); // teal
      default:
        return AppConstants.primaryColor;
    }
  }

  IconData _icon() {
    switch (item.type) {
      case 'class':
        return Icons.school_rounded;
      case 'break':
        return Icons.coffee_rounded;
      case 'meal':
        return Icons.restaurant_rounded;
      case 'nap':
        return Icons.bedtime_rounded;
      case 'recall':
        return Icons.psychology_rounded;
      case 'question_practice':
        return Icons.quiz_rounded;
      case 'review':
        return Icons.replay_rounded;
      case 'study':
      case 'first_read':
      case 'revision':
      default:
        return Icons.menu_book_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor();
    final bgColor = _bgColor();
    final displayTitle = item.displayTitle;
    final tagline = item.tagline;

    return Container(
      margin: EdgeInsets.only(bottom: S.sm),
      padding: EdgeInsets.all(S.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(S.radiusLg),
        border: Border.all(
          color: accent.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // ── Accent strip ──
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: S.sm),
          // ── Content ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: timeline + icon + location
                Row(
                  children: [
                    Icon(_icon(), size: 14, color: accent),
                    SizedBox(width: 4),
                    Text(
                      item.timelineText,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.locationText.isNotEmpty) ...[
                      SizedBox(width: 8),
                      Icon(Icons.location_on_outlined,
                          size: 12, color: AppColors.textMuted(d)),
                      SizedBox(width: 2),
                      Text(
                        item.locationText,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textMuted(d),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4),
                // Row 2: title (type-based)
                Text(
                  displayTitle,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textPrimary(d),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Row 3: tagline or topic
                if (tagline != null && tagline.isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(
                    tagline,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary(d),
                      fontStyle: (item.type == 'break' || item.type == 'nap')
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // ── Duration badge ──
          Container(
            padding: EdgeInsets.symmetric(horizontal: S.sm, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(S.radiusSm),
            ),
            child: Text(
              item.durationText,
              style: AppTextStyles.labelSmall.copyWith(color: accent),
            ),
          ),
        ],
      ),
    );
  }
}
