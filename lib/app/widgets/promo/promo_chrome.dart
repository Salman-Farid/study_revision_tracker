import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/size_constants.dart';
import '../../theme/app_theme.dart';

class WidgetPromoHeader extends StatelessWidget {
  final bool d;
  const WidgetPromoHeader({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(S.xl, S.xl, S.xl, S.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.secondary.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(S.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.circular(S.radiusMd),
                          ),
            child: Icon(Icons.widgets_rounded, color: Colors.white, size: S.iconMd + 4),
          ),
          SizedBox(width: S.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'widgetPromoTitle'.tr,
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: AppColors.textPrimary(d),
                  ),
                ),
                SizedBox(height: S.xs),
                Text(
                  'widgetPromoSubtitle'.tr,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted(d),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WidgetPromoSubtitle extends StatelessWidget {
  final bool d;
  const WidgetPromoSubtitle({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(S.xl, S.md, S.xl, S.sm),
      child: Text(
        'widgetPromoDesc'.tr,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary(d),
        ),
      ),
    );
  }
}

class WidgetPromoButtons extends StatelessWidget {
  final bool d;
  final VoidCallback onDismiss;
  const WidgetPromoButtons({super.key, required this.d, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(S.xl, S.lg, S.xl, S.xl),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: onDismiss,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: S.base),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(S.radiusMd),
                ),
              ),
              child: Text(
                'widgetPromoMaybeLater'.tr,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMuted(d),
                ),
              ),
            ),
          ),
          SizedBox(width: S.sm),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: onDismiss,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: S.base),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(S.radiusMd),
                ),
              ),
              child: Text(
                'widgetPromoDone'.tr,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
