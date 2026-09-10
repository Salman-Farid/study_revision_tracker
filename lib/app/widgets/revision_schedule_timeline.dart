import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/size_constants.dart';
import '../data/models/revision_schedule_model.dart';
import '../theme/app_theme.dart';

class RevisionScheduleTimeline extends StatelessWidget {
  final List<RevisionScheduleModel> schedules;
  const RevisionScheduleTimeline({super.key, required this.schedules});

  static const List<Color> _stageColors = [
    Color(0xFF5B8DEF),
    Color(0xFF4CAF7A),
    Color(0xFF9B7BFF),
    Color(0xFFE8A33D),
    Color(0xFFEF6B8A),
    Color(0xFF3DB8C9),
  ];

  Color _softTint(Color base, bool dark) =>
      Color.lerp(dark ? const Color(0xFF1A1D26) : Colors.white, base, dark ? 0.12 : 0.06)!;

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: List.generate(AppConstants.revisionDays.length, (i) {
        final dn = AppConstants.revisionDays[i];
        final sch = schedules.where((s) => s.dayNumber == dn).firstOrNull;
        final st = sch?.status ?? 'pending';
        final done = st == 'completed';
        final missed = st == 'missed';
        final col = _stageColors[i];
        final bg = _softTint(col, d);

        return Padding(
          padding: EdgeInsets.only(bottom: S.sm),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(S.md),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(S.radiusMd),
              border: Border.all(
                color: col.withValues(alpha: done || missed ? 0.35 : 0.12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: S.iconSm,
                  height: S.iconSm,
                  decoration: BoxDecoration(
                    color: done || missed ? col : col.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: col, width: 1.5),
                  ),
                  child: done
                      ? Icon(Icons.check, size: S.iconXs, color: Colors.white)
                      : missed
                          ? Icon(Icons.close, size: S.iconXs, color: Colors.white)
                          : null,
                ),
                SizedBox(width: S.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppConstants.revisionDayLabels[i],
                        style: AppTextStyles.titleSmall.copyWith(
                          color: done || missed ? col : AppColors.textPrimary(d),
                          fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      if (sch != null)
                        Text(
                          '${sch.scheduledDate.day}/${sch.scheduledDate.month}/${sch.scheduledDate.year}',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted(d)),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: S.sm, vertical: S.xs),
                  decoration: BoxDecoration(
                    color: col.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(S.radiusSm),
                  ),
                  child: Text(
                    done ? 'Done' : missed ? 'Missed' : 'Pending',
                    style: AppTextStyles.labelSmall.copyWith(color: col),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
