import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/size_constants.dart';
import '../../../theme/app_theme.dart';
import '../dashboard_controller.dart';

/// Live daily-routine card (only when a routine exists for today).
/// Stream-driven via DashboardController — no pull-to-refresh required.
class DailyRoutineLiveCard extends StatelessWidget {
  final bool d;
  final DashboardController controller;
  const DailyRoutineLiveCard({super.key, required this.d, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!controller.hasDailyRoutineToday.value) return const SizedBox.shrink();

    final streak = controller.streakDays.value;
    final current = controller.currentRoutine.value;
    final upcoming = controller.upcomingRoutines;
    final total = controller.todayRoutineItems.length;
    final done = total -
        upcoming.length -
        (current != null ? 1 : 0);

    return Container(
      margin: EdgeInsets.fromLTRB(S.xl, 0, S.xl, S.md),
      padding: EdgeInsets.all(S.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(S.radiusLg),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(S.sm + 2),
                decoration: BoxDecoration(
                  color: (streak > 0
                          ? const Color(0xFFFF6B35)
                          : AppColors.primary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(S.radiusSm),
                ),
                child: Icon(
                  streak > 0
                      ? Icons.local_fire_department_rounded
                      : Icons.schedule_rounded,
                  color: streak > 0
                      ? const Color(0xFFFF6B35)
                      : AppColors.primary,
                  size: S.iconMd,
                ),
              ),
              SizedBox(width: S.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      streak > 0
                          ? 'dayStreak'.tr.replaceAll('{n}', '$streak')
                          : 'dailyRoutine'.tr,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.textPrimaryLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${done.clamp(0, total)}/$total blocks · up next',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted(d)),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: controller.openRoutineTab,
                child: Text(
                  'open'.tr,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          if (current != null) ...[
            SizedBox(height: S.md),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(S.base),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(S.radiusMd),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: S.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'NOW',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  SizedBox(width: S.sm),
                  Expanded(
                    child: Text(
                      current.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.textPrimaryLight,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${current.timeText} – ${current.endTimeText}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (upcoming.isNotEmpty) ...[
            SizedBox(height: S.md),
            Text(
              'UP NEXT',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textMuted(d),
                letterSpacing: 0.06,
              ),
            ),
            SizedBox(height: S.sm),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: upcoming.length,
                separatorBuilder: (_, __) => SizedBox(width: S.sm),
                itemBuilder: (_, i) {
                  final it = upcoming[i];
                  return Container(
                    width: 148,
                    padding: EdgeInsets.all(S.md),
                    decoration: BoxDecoration(
                      color: AppColors.bg(d),
                      borderRadius: BorderRadius.circular(S.radiusMd),
                      border: Border.all(color: AppColors.border(d)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          it.timeText,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          it.displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleSmall.copyWith(
                            color: AppColors.textPrimary(d),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
