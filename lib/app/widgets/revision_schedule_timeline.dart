import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/size_constants.dart';
import '../data/models/revision_schedule_model.dart';
import '../theme/app_theme.dart';

class RevisionScheduleTimeline extends StatelessWidget {
  final List<RevisionScheduleModel> schedules;
  const RevisionScheduleTimeline({super.key, required this.schedules});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Column(children: List.generate(AppConstants.revisionDays.length, (i) {
      final dn = AppConstants.revisionDays[i];
      final sch = schedules.where((s) => s.dayNumber == dn).firstOrNull;
      final st = sch?.status ?? 'pending';
      final done = st == 'completed', missed = st == 'missed';
      final col = done ? AppColors.success : missed ? AppColors.error : AppColors.textMuted(d);
      final last = i == AppConstants.revisionDays.length - 1;
      return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: S.xxl, child: Column(children: [
          Container(width: S.iconSm, height: S.iconSm, decoration: BoxDecoration(color: col, shape: BoxShape.circle),
            child: done ? Icon(Icons.check, size: S.iconXs, color: Colors.white)
              : missed ? Icon(Icons.close, size: S.iconXs, color: Colors.white) : null),
          if (!last) Expanded(child: Container(width: 2, color: done ? col : AppColors.border(d))),
        ])),
        SizedBox(width: S.md),
        Expanded(child: Padding(padding: EdgeInsets.only(bottom: S.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppConstants.revisionDayLabels[i], style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.textPrimary(d), fontWeight: done ? FontWeight.w700 : FontWeight.w500)),
            if (sch != null) Text('${sch.scheduledDate.day}/${sch.scheduledDate.month}/${sch.scheduledDate.year}',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted(d))),
          ]))),
        Container(padding: EdgeInsets.symmetric(horizontal: S.sm, vertical: S.xs),
          decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(S.radiusSm)),
          child: Text(done ? 'Done' : missed ? 'Missed' : 'Pending',
            style: AppTextStyles.labelSmall.copyWith(color: col))),
      ]));
    }));
  }
}
