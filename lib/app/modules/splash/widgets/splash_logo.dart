import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';
import '../../../theme/app_theme.dart';

class SplashLogoContent extends StatelessWidget {
  final Animation<double> fade;
  final Animation<double> scale;
  const SplashLogoContent({super.key, required this.fade, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: fade.value,
      child: Transform.scale(
        scale: scale.value,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.school_rounded,
                  color: Colors.white, size: 42),
            ),
            const SizedBox(height: 24),
            Text(
              AppConstants.appName,
              style: AppTextStyles.headlineLarge.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'startRevisionJourney'.tr,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted(
                  Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
