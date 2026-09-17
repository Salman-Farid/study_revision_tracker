import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/size_constants.dart';
import '../../../theme/app_theme.dart';
import '../routine_controller.dart';
import 'routine_routine_tile.dart';
import 'class_routine_tile.dart';

class DailyBody extends StatelessWidget {
  final RoutineController controller;
  const DailyBody({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      final items = controller.todayItems;
      if (items.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_available_rounded,
                  size: 48, color: AppColors.textMuted(d)),
              SizedBox(height: S.md),
              Text(
                'noRoutinesForToday'.tr,
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary(d),
                ),
              ),
              SizedBox(height: S.sm),
              Text(
                'tapMicToAskAssistant'.tr,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted(d),
                ),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.fromLTRB(S.base, 0, S.base, S.xxxl),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          return RoutineTile(item: item, d: d);
        },
      );
    });
  }
}

class ClassBody extends StatelessWidget {
  final RoutineController controller;
  const ClassBody({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      final routines = controller.classRoutines;
      if (routines.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_note_rounded,
                  size: 48, color: AppColors.textMuted(d)),
              SizedBox(height: S.md),
              Text(
                'noClassRoutines'.tr,
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary(d),
                ),
              ),
              SizedBox(height: S.sm),
              Text(
                'sayToAddOne'.tr,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted(d),
                ),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.fromLTRB(S.base, 0, S.base, S.xxxl),
        itemCount: routines.length,
        itemBuilder: (_, i) {
          final cr = routines[i];
          return ClassRoutineTile(cr: cr, d: d);
        },
      );
    });
  }
}
