import 'package:flutter/material.dart';
import '../../../core/constants/size_constants.dart';
import '../../../theme/app_theme.dart';
import '../routine_controller.dart';
import 'routine_block_palette.dart';

class RoutineTile extends StatelessWidget {
  final RoutineDisplayItem item;
  final bool d;
  const RoutineTile({super.key, required this.item, required this.d});

  @override
  Widget build(BuildContext context) {
    final accent = RoutineBlockPalette.accent(item.type);
    final bgColor = RoutineBlockPalette.bg(item.type);
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
                    Icon(RoutineBlockPalette.icon(item.type), size: 14, color: accent),
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
