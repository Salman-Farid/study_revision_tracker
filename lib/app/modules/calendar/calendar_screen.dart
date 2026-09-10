import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/constants/size_constants.dart';
import '../../theme/app_theme.dart';
import 'calendar_controller.dart';
import '../../data/models/revision_schedule_model.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<CalendarController>();
    return Scaffold(
      appBar: AppBar(title: Text('navCalendar'.tr, style: AppTextStyles.headlineMedium)),
      body: Obx(() {
        // Depend on version + selected day so markers/list always refresh.
        final _ = c.eventsVersion.value;
        final selected = c.selectedDay.value;
        if (c.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(children: [
          TableCalendar(
            firstDay: DateTime(2024),
            lastDay: DateTime(2027),
            focusedDay: c.focusedDay.value,
            calendarFormat: c.calendarFormat.value,
            selectedDayPredicate: (d) => isSameDay(selected, d),
            onDaySelected: c.onDaySelected,
            onFormatChanged: c.onFormatChanged,
            eventLoader: c.getEventsForDay,
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.3), shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
              markerDecoration: BoxDecoration(
                  color: AppColors.secondary, shape: BoxShape.circle),
              markerSize: 6,
              todayTextStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary(
                      Theme.of(context).brightness == Brightness.dark)),
            ),
            headerStyle: HeaderStyle(
              titleTextStyle: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.textPrimary(
                      Theme.of(context).brightness == Brightness.dark)),
              formatButtonTextStyle: AppTextStyles.labelMedium,
              leftChevronIcon: Icon(Icons.chevron_left,
                  color: AppColors.textPrimary(
                      Theme.of(context).brightness == Brightness.dark)),
              rightChevronIcon: Icon(Icons.chevron_right,
                  color: AppColors.textPrimary(
                      Theme.of(context).brightness == Brightness.dark)),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textMuted(
                      Theme.of(context).brightness == Brightness.dark)),
              weekendStyle: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textMuted(
                      Theme.of(context).brightness == Brightness.dark)),
            ),
          ),
          Expanded(child: _eventList(c, context)),
        ]);
      }),
    );
  }

  Widget _eventList(CalendarController c, BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    final evts = c.getEventsForDay(c.selectedDay.value);
    if (evts.isEmpty) return Center(child: Text('noRevisionsThisDay'.tr,
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted(d))));
    return ListView.builder(
      padding: EdgeInsets.all(S.base),
      itemCount: evts.length,
      itemBuilder: (_, i) => _eventTile(evts[i], d),
    );
  }

  Widget _eventTile(RevisionScheduleModel e, bool d) {
    final isMissed = e.status == 'missed';
    final isCompleted = e.status == 'completed';
    final sc = isCompleted ? AppColors.success : isMissed ? AppColors.error : AppColors.primary;
    final subjectLabel = e.subjectName ?? 'subject'.tr;
    final topicLabel = e.topicName ?? 'topic'.tr;
    final dateStr = '${e.scheduledDate.day}/${e.scheduledDate.month}/${e.scheduledDate.year}';
    final statusLabel = isMissed ? 'missed'.tr : isCompleted ? 'completed'.tr : 'pending'.tr;

    return Container(
      margin: EdgeInsets.only(bottom: S.sm),
      padding: EdgeInsets.all(S.md),
      decoration: BoxDecoration(
        color: isMissed ? AppColors.error.withOpacity(0.06) : AppColors.surface(d),
        borderRadius: BorderRadius.circular(S.radiusMd),
        border: Border.all(color: isMissed ? AppColors.error.withOpacity(0.3) : AppColors.border(d)),
      ),
      child: Row(children: [
        Container(width: 4, height: 48, decoration: BoxDecoration(color: sc, borderRadius: BorderRadius.circular(2))),
        SizedBox(width: S.md),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Subject name
          Text(subjectLabel, style: AppTextStyles.labelMedium.copyWith(color: AppColors.textMuted(d))),
          SizedBox(height: 2),
          // Topic name
          Text(topicLabel, style: AppTextStyles.titleSmall.copyWith(color: AppColors.textPrimary(d), fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          // Day label + date + status badge
          Row(children: [
            Text('dayLabel'.tr.replaceAll('{n}', '${e.dayNumber}'), style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted(d))),
            SizedBox(width: S.sm),
            Text('·', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted(d))),
            SizedBox(width: S.sm),
            Text(dateStr, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted(d))),
            SizedBox(width: S.sm),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: sc, borderRadius: BorderRadius.circular(4)),
              child: Text(statusLabel, style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontSize: 10)),
            ),
          ]),
        ])),
      ]),
    );
  }
}
