import 'package:flutter/material.dart';
import '../core/constants/size_constants.dart';
import '../theme/app_theme.dart';

/// Card-style empty state (bordered surface + icon + title + subtitle).
/// Distinct from centered [EmptyState] — use when the empty area sits
/// inside a card/grid slot rather than a full-screen placeholder.
class CardEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool d;
  final IconData icon;

  const CardEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.d,
    this.icon = Icons.hourglass_empty_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(S.xl),
      decoration: BoxDecoration(
        color: AppColors.surface(d),
        borderRadius: BorderRadius.circular(S.radiusLg),
        border: Border.all(color: AppColors.border(d)),
      ),
      child: Column(
        children: [
          Icon(icon, size: S.iconXxl, color: AppColors.textMuted(d)),
          SizedBox(height: S.md),
          Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textSecondary(d),
            ),
          ),
          SizedBox(height: S.xs),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted(d),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
