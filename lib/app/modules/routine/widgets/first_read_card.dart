import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/size_constants.dart';
import '../../../theme/app_theme.dart';
import '../routine_item_model.dart';
import 'technique_guidance.dart';

/// Bug-06 FIX: Frosted-glass card widget.
/// Uses BackdropFilter + translucent Container + subtle border
/// to implement the iOS-style glassmorphism design.
class FirstReadCard extends StatelessWidget {
  final RoutineItemModel item;
  final VoidCallback? onTap;

  const FirstReadCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    final isCompleted = item.status == RoutineItemStatus.completed;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(S.radiusLg),
        child: BackdropFilter(
          // Bug-06 FIX: Apply frosted glass blur (sigmaX/Y = 15) + translucent fill
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            margin: EdgeInsets.only(bottom: 4),
            padding: EdgeInsets.all(S.sm),
            decoration: BoxDecoration(
              // Translucent fill — the backdrop shows through with blur
              color: (d ? AppColors.surfaceDark : AppColors.surfaceLight)
                  .withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(S.radiusLg),
              border: Border.all(
                color: isCompleted
                    ? AppConstants.successColor.withValues(alpha: 0.35)
                    : (d ? Colors.white : Colors.black).withValues(alpha: 0.08),
                width: isCompleted ? 1.5 : 1,
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
                // ── Top Row: Status, Type, Time ──
                Row(
                  children: [
                    _buildStatusIndicator(isCompleted, d),
                    SizedBox(width: S.sm),
                    _buildTypeChip(d),
                    SizedBox(width: S.sm),
                    if (item.sessionNumber != null)
                      Text(
                        item.sessionNumber!,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textMuted(d),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Spacer(),
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
                SizedBox(height: S.sm),
                // ── Subject & Topic ──
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
                // ── Session Type + Duration ──
                Row(
                  children: [
                    Icon(
                      item.sessionTypeIcon ?? Icons.menu_book_rounded,
                      size: 14,
                      color: AppConstants.primaryColor,
                    ),
                    SizedBox(width: 4),
                    Text(
                      item.sessionTypeLabel ?? '',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary(d),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: S.md),
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
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
                ),
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(bool isCompleted, bool d) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted
            ? AppConstants.successColor.withValues(alpha: 0.12)
            : AppConstants.primaryColor.withValues(alpha: 0.12),
      ),
      child: Icon(
        item.typeIcon,
        size: 18,
        color: isCompleted
            ? AppConstants.successColor
            : AppConstants.primaryColor,
      ),
    );
  }

  Widget _buildTypeChip(bool d) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: S.sm, vertical: 2),
      decoration: BoxDecoration(
        color: AppConstants.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(S.radiusXs),
      ),
      child: Text(
        'FIRST READ',
        style: AppTextStyles.labelSmall.copyWith(
          color: AppConstants.primaryColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
