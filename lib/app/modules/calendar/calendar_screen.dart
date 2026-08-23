import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../core/constants/size_constants.dart';
import '../../data/repositories/revision_repository.dart';
import '../../data/models/revision_schedule_model.dart';
import '../../theme/app_theme.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _repo = Get.find<RevisionRepository>();
  CalendarFormat _fmt = CalendarFormat.month;
  DateTime _focused = DateTime.now(), _selected = DateTime.now();
  final _events = <DateTime, List<RevisionScheduleModel>>{};
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      setState(() => _loading = true);
      final now = DateTime.now();
      final ss = await _repo.getSchedules(
        fromDate: DateTime(now.year, now.month - 2, 1),
        toDate: DateTime(now.year, now.month + 3, 0));
      _events.clear();
      for (final s in ss) {
        final k = DateTime(s.scheduledDate.year, s.scheduledDate.month, s.scheduledDate.day);
        _events.putIfAbsent(k, () => []).add(s);
      }
    } catch (_) {} finally { if (mounted) setState(() => _loading = false); }
  }

  List<RevisionScheduleModel> _getEvents(DateTime d) =>
    _events[DateTime(d.year, d.month, d.day)] ?? [];

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
        return Scaffold(appBar: AppBar(title: Text('Calendar', style: AppTextStyles.headlineMedium)),
      body: _loading ? const Center(child: CircularProgressIndicator()) :
      Column(children: [
        TableCalendar(firstDay: DateTime(2024), lastDay: DateTime(2027), focusedDay: _focused,
          calendarFormat: _fmt, selectedDayPredicate: (d) => isSameDay(_selected, d),
          onDaySelected: (s, f) => setState(() { _selected = s; _focused = f; }),
          onFormatChanged: (f) => setState(() => _fmt = f), eventLoader: _getEvents,
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(color: AppColors.primary.withOpacity(0.3), shape: BoxShape.circle),
            selectedDecoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            markerDecoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle),
            markerSize: 6, todayTextStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary(d))),
          headerStyle: HeaderStyle(titleTextStyle: AppTextStyles.titleLarge.copyWith(color: AppColors.textPrimary(d)),
            formatButtonTextStyle: AppTextStyles.labelMedium,
            leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.textPrimary(d)),
            rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.textPrimary(d))),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.textMuted(d)),
            weekendStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.textMuted(d)))),
        Expanded(child: _eventList(d)),
      ]));
  }

  Widget _eventList(bool d) {
    final evts = _getEvents(_selected);
    if (evts.isEmpty) return Center(child: Text('No revisions this day',
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted(d))));
    return ListView.builder(padding: EdgeInsets.all(S.base), itemCount: evts.length,
      itemBuilder: (_, i) {
        final e = evts[i];
        final sc = e.status == 'completed' ? AppColors.success : e.status == 'missed' ? AppColors.error : AppColors.primary;
        return Container(margin: EdgeInsets.only(bottom: S.sm), padding: EdgeInsets.all(S.md),
          decoration: BoxDecoration(color: AppColors.surface(d), borderRadius: BorderRadius.circular(S.radiusMd),
            border: Border.all(color: AppColors.border(d))),
          child: Row(children: [
            Container(width: 4, height: 40, decoration: BoxDecoration(color: sc, borderRadius: BorderRadius.circular(2))),
            SizedBox(width: S.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Day ${e.dayNumber} Revision', style: AppTextStyles.titleSmall.copyWith(color: AppColors.textPrimary(d))),
              Text(e.status.toUpperCase(), style: AppTextStyles.labelSmall.copyWith(color: sc)),
            ])),
          ]));
      });
  }
}
