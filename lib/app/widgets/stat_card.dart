import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../core/constants/size_constants.dart';

class StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;
  const StatCard({super.key, required this.title, required this.value,
    required this.icon, required this.color, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(S.radiusLg),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: S.statCardMinHeight),
          child: Ink(
            padding: EdgeInsets.all(S.base),
            decoration: BoxDecoration(
              color: AppColors.surface(d),
              borderRadius: BorderRadius.circular(S.radiusLg),
              border: Border.all(color: AppColors.border(d)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(S.sm),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(S.radiusMd),
                  ),
                  child: Icon(icon, color: color, size: S.iconMd),
                ),
                SizedBox(height: S.md),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: AppColors.textPrimary(d),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  SizedBox(height: S.xs),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted(d)),
                    ),
                  ),
                ],
                SizedBox(height: S.xs),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted(d)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
