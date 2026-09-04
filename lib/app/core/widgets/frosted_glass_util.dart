import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:study_revision_tracker/app/theme/app_theme.dart';

/// Bug-06 & Bug-15 FIX: Frosted-glass card decoration.
/// Wraps a translucent Container with BackdropFilter + ImageFilter.blur
/// and a subtle border to create the iOS-style glassmorphism effect.
/// Place this as the decoration of any card Container.
BoxDecoration glassDecoration(BuildContext context) {
  final d = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: (d ? AppColors.surfaceDark : AppColors.surfaceLight)
        .withValues(alpha: 0.7),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: (d ? Colors.white : Colors.black).withValues(alpha: 0.1),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: d ? 0.3 : 0.08),
        blurRadius: 20,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

/// Bug-06 FIX: Wrap content in a frosted glass panel.
/// Use BackdropFilter with sigmaX/Y = 15 for a strong blur effect.
Widget frostedGlassPanel({
  required BuildContext context,
  required Widget child,
  EdgeInsets padding = EdgeInsets.zero,
  BorderRadius borderRadius = const BorderRadius.all(Radius.circular(16)),
}) {
  final d = Theme.of(context).brightness == Brightness.dark;
  return ClipRRect(
    borderRadius: borderRadius,
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: d
              ? AppColors.surfaceDark.withValues(alpha: 0.65)
              : AppColors.surfaceLight.withValues(alpha: 0.65),
          borderRadius: borderRadius,
          border: Border.all(
            color: d
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
        child: child,
      ),
    ),
  );
}
