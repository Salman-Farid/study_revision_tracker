import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/constants/size_constants.dart';
import '../../theme/app_theme.dart';
import 'calendar_controller.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<CalendarController>();
    return Scaffold(
      appBar: AppBar(title: Text('Calendar', style: AppTextStyles.headlineMedium)),
      body: Obx(() => c.isLoading.value
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Obx(() => TableCalendar(
                firstDay: DateTime(2024), lastDay: DateTime(2027),
                focusedDay: c.focusedDay.value,
                calendarFormat: c.calendarFormat.value,
                selectedDayPredicate: (d) => isSameDay(c.selectedDay.value, d),
                onDaySelected: c.onDaySelected,
                onFormatChanged: c.onFormatChanged,
                eventLoader: c.getEventsForDay,
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(color: AppColors.primary.withOpacity(0.3), shape: BoxShape.circle),
                  selectedDecoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  markerDecoration: BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle),
                  markerSize: 6,
                  todayTextStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary(
                    Theme.of(context).brightness == Brightness.dark)),
                ),
                headerStyle: HeaderStyle(
                  titleTextStyle: AppTextStyles.titleLarge.copyWith(color: AppColors.textPrimary(
                    Theme.of(context).brightness == Brightness.dark)),
                  formatButtonTextStyle: AppTextStyles.labelMedium,
                  leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.textPrimary(
                    Theme.of(context).brightness == Brightness.dark)),
                  rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.textPrimary(
                    Theme.of(context).brightness == Brightness.dark)),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.textMuted(
                    Theme.of(context).brightness == Brightness.dark)),
                  weekendStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.textMuted(
                    Theme.of(context).brightness == Brightness.dark)),
                ),
              )),
              Expanded(child: _eventList(c, context)),
            ])),
    );
  }

  Widget _eventList(CalendarController c, BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    final evts = c.getEventsForDay(c.selectedDay.value);
    if (evts.isEmpty) return Center(child: Text('No revisions this day',
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted(d))));
    return ListView.builder(
      padding: EdgeInsets.all(S.base),
      itemCount: evts.length,
      itemBuilder: (_, i) {
        final e = evts[i];
        final sc = e.status == 'completed' ? AppColors.success : e.status == 'missed' ? AppColors.error : AppColors.primary;
        return Container(
          margin: EdgeInsets.only(bottom: S.sm),
          padding: EdgeInsets.all(S.md),
          decoration: BoxDecoration(
            color: AppColors.surface(d),
            borderRadius: BorderRadius.circular(S.radiusMd),
            border: Border.all(color: AppColors.border(d)),
          ),
          child: Row(children: [
            Container(width: 4, height: 40, decoration: BoxDecoration(color: sc, borderRadius: BorderRadius.circular(2))),
            SizedBox(width: S.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Day ${e.dayNumber} Revision', style: AppTextStyles.titleSmall.copyWith(color: AppColors.textPrimary(d))),
              Text(e.status.toUpperCase(), style: AppTextStyles.labelSmall.copyWith(color: sc)),
            ])),
          ]),
        );
      },
    );
  }
}
