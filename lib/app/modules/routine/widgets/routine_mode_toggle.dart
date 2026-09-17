import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/size_constants.dart';
import '../../../theme/app_theme.dart';
import '../routine_controller.dart';

class PaneHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool d;
  const PaneHeader({super.key, required this.icon, required this.label, required this.d});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(S.base, S.sm, S.base, S.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppConstants.primaryColor),
          SizedBox(width: S.sm),
          Text(
            label,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textPrimary(d),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class ModeToggle extends StatelessWidget {
  final RoutineController controller;
  const ModeToggle({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.fromLTRB(S.base, S.sm, S.base, S.sm),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: (d ? AppColors.surfaceDark : AppColors.surfaceLight)
              .withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(S.radiusFull),
          border: Border.all(
            color: (d ? Colors.white : Colors.black).withValues(alpha: 0.06),
          ),
        ),
        child: Obx(() {
          final mode = controller.mode.value;
          return Row(
            children: [
              Expanded(
                child: SegmentButton(
                  label: 'dailyRoutine'.tr,
                  icon: Icons.today_rounded,
                  active: mode == RoutineMode.daily,
                  onTap: () => controller.switchMode(RoutineMode.daily),
                  d: d,
                ),
              ),
              Expanded(
                child: SegmentButton(
                  label: 'classRoutine'.tr,
                  icon: Icons.event_note_rounded,
                  active: mode == RoutineMode.class$,
                  onTap: () => controller.switchMode(RoutineMode.class$),
                  d: d,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class SegmentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final bool d;
  const SegmentButton({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    required this.d,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? AppConstants.primaryColor.withValues(alpha: 0.18)
        : Colors.transparent;
    final border = active
        ? AppConstants.primaryColor.withValues(alpha: 0.6)
        : Colors.transparent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppConstants.shortDuration,
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(vertical: S.sm, horizontal: S.sm),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(S.radiusFull),
          border: Border.all(color: border, width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: active
                  ? AppConstants.primaryColor
                  : AppColors.textMuted(d),
            ),
            SizedBox(width: S.sm),
            Text(
              label,
              style: AppTextStyles.titleSmall.copyWith(
                color: active
                    ? AppConstants.primaryColor
                    : AppColors.textMuted(d),
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
