import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../theme/app_theme.dart';

/// Shared snackbar helpers so duration/color/position stay consistent.
class AppSnack {
  const AppSnack._();

  static void error(
    String title,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.error.withValues(alpha: 0.12),
      colorText: AppColors.error,
      duration: duration,
    );
  }

  static void success(
    String title,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.success.withValues(alpha: 0.12),
      colorText: AppColors.success,
      duration: duration,
    );
  }

  static void info(
    String title,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      duration: duration,
    );
  }
}
