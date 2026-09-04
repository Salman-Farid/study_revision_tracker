import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../core/constants/size_constants.dart';

/// Bug-15 FIX: Frosted-glass StatCard.
/// Uses BackdropFilter + translucent Container + subtle border
/// to implement the iOS-style glassmorphism design.
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
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(S.radiusLg),
        child: BackdropFilter(
          // Bug-15 FIX: Frosted glass blur (sigmaX/Y = 15) + translucent surface
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: BoxConstraints(minHeight: S.statCardMinHeight),
            padding: EdgeInsets.all(S.base),
            decoration: BoxDecoration(
              // Translucent glass fill — backdrop bleeds through with blur
              color: (d ? AppColors.surfaceDark : AppColors.surfaceLight)
                  .withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(S.radiusLg),
              border: Border.all(
                color: (d ? Colors.white : Colors.black).withValues(alpha: 0.09),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: d ? 0.3 : 0.07),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Container(padding: EdgeInsets.all(S.sm),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(S.radiusMd)),
                child: Icon(icon, color: color, size: S.iconMd)),
              SizedBox(height: S.md),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                child: Text(value, maxLines: 1, style: AppTextStyles.headlineMedium.copyWith(
                  color: AppColors.textPrimary(d), fontWeight: FontWeight.w800))),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                SizedBox(height: S.xs),
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                  child: Text(subtitle!, maxLines: 1, style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted(d)))),
              ],
              SizedBox(height: S.xs),
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted(d))),
            ])),
        ),
      ),
    );
  }
}
