import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/size_constants.dart';
import '../theme/app_theme.dart';

/// Small colored pill (revision stage, "DAY 3", etc.).
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool uppercase;
  final FontWeight fontWeight;
  final double fontSize;
  final double letterSpacing;
  final EdgeInsetsGeometry padding;

  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.uppercase = false,
    this.fontWeight = FontWeight.w700,
    this.fontSize = 10,
    this.letterSpacing = 0,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(S.radiusXs),
      ),
      child: Text(
        uppercase ? label.toUpperCase() : label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: letterSpacing == 0 ? null : letterSpacing,
        ),
      ),
    );
  }
}

/// Circular status icon used on revision cards.
class StatusDotIcon extends StatelessWidget {
  final bool isCompleted;
  final bool isDue;
  final double size;

  const StatusDotIcon({
    super.key,
    required this.isCompleted,
    required this.isDue,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color iconColor;
    final IconData icon;

    if (isCompleted) {
      bgColor = AppConstants.successColor.withValues(alpha: 0.12);
      iconColor = AppConstants.successColor;
      icon = Icons.check_rounded;
    } else if (isDue) {
      bgColor = AppConstants.warningColor.withValues(alpha: 0.12);
      iconColor = AppConstants.warningColor;
      icon = Icons.replay_rounded;
    } else {
      bgColor = AppConstants.infoColor.withValues(alpha: 0.12);
      iconColor = AppConstants.infoColor;
      icon = Icons.replay_rounded;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bgColor),
      child: Icon(icon, size: 18 * (size / 36), color: iconColor),
    );
  }
}
