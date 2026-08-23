import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../core/constants/size_constants.dart';

class StatCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const StatCard({super.key, required this.title, required this.value,
    required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(onTap: onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(S.base),
        decoration: BoxDecoration(color: AppColors.surface(d),
          borderRadius: BorderRadius.circular(S.radiusLg),
          border: Border.all(color: AppColors.border(d)), boxShadow: S.shadowSm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: EdgeInsets.all(S.sm),
            decoration: BoxDecoration(color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(S.radiusMd)),
            child: Icon(icon, color: color, size: S.iconMd)),
          SizedBox(height: S.md),
          Text(value, style: AppTextStyles.headlineMedium.copyWith(
            color: AppColors.textPrimary(d), fontWeight: FontWeight.w800)),
          SizedBox(height: S.xs),
          Text(title, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted(d))),
        ]))));
  }
}
