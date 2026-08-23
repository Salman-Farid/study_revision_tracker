import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../core/constants/size_constants.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.icon, required this.title,
    required this.subtitle, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Center(child: Padding(padding: EdgeInsets.all(S.xxxl),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: EdgeInsets.all(S.xxl), decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08), shape: BoxShape.circle),
          child: Icon(icon, size: S.iconXxl, color: AppColors.primary)),
        SizedBox(height: S.xl),
        Text(title, style: AppTextStyles.headlineSmall.copyWith(color: AppColors.textPrimary(d)),
          textAlign: TextAlign.center),
        SizedBox(height: S.sm),
        Text(subtitle, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted(d)),
          textAlign: TextAlign.center),
        if (actionLabel != null && onAction != null) ...[
          SizedBox(height: S.xl),
          ElevatedButton.icon(onPressed: onAction,
            icon: const Icon(Icons.add_rounded), label: Text(actionLabel!)),
        ],
      ])));
  }
}
