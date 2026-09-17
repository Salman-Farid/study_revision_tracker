part of '../widget_data_service.dart';

/// Class-routine payload + weekday matching.
/// True if [cr] occurs on [day]. Tolerates ISO timestamps in `dates`,
/// weekday names, numeric weekdays stored in `dates`, and a missing
/// `recurring` flag when `recurringDays` is set.
bool _classMatchesDay(ClassRoutineModel cr, DateTime day) {
  final dateStr =
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  const weekdayNames = [
    '', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
  ];
  const weekdayShort = ['', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  final dayName = weekdayNames[day.weekday];
  final dayShort = weekdayShort[day.weekday];

  for (final raw in cr.dates) {
    final d = raw.trim();
    if (d.isEmpty) continue;
    // Exact or prefix date match (YYYY-MM-DD or ISO datetime)
    if (d == dateStr || d.startsWith(dateStr)) return true;
    final lower = d.toLowerCase();
    if (lower == dayName || lower == dayShort) return true;
    // Weekday number stored in dates: "3" or 3 as string
    final asInt = int.tryParse(d);
    if (asInt != null && asInt == day.weekday) return true;
  }
  if (cr.recurringDays.contains(day.weekday)) return true;
  return false;
}

Future<Map<String, dynamic>> _fetchClassRoutineData(
  SupabaseClient client, String userId, DateTime now, DateTime today, DateTime tomorrow,
) async {
  // Always return a complete, valid payload so widgets never show an error.
  final result = <String, dynamic>{
    'hasToday': false,
    'statusMessage': 'Nothing to show',
    'classItems': <Map<String, dynamic>>[],
  };

  try {
    final classRows = await client
        .from('class_routines')
        .select()
        .eq('user_id', userId);

    final rowsList = classRows as List;
    final todayClasses = <Map<String, dynamic>>[];
    final displayClasses = <Map<String, dynamic>>[];

    for (final row in rowsList) {
      try {
        final cr = ClassRoutineModel.fromJson(row);
        final isToday = _classMatchesDay(cr, today);
        final startToday = DateTime(
          today.year, today.month, today.day, cr.startTime.hour, cr.startTime.minute,
        );
        final endToday = startToday.add(Duration(minutes: cr.durationMinutes));

        if (isToday) {
          todayClasses.add({
            'subject': cr.subjectName,
            'start': startToday,
            'end': endToday,
            'timeText': cr.timeText,
            'endTimeText': cr.endTimeText,
            'location': cr.locationText,
            'durationText': cr.durationText,
          });
        }

        displayClasses.add({
          'subject': cr.subjectName,
          'timeText': cr.timeText,
          'endTimeText': cr.endTimeText,
          'location': cr.locationText,
          'daysText': cr.daysText.isNotEmpty
              ? cr.daysText
              : (cr.dates.isNotEmpty ? cr.dates.join(', ') : 'One-time'),
          'durationMinutes': cr.durationMinutes,
          'durationText': cr.durationText,
          'startTimestamp': startToday.millisecondsSinceEpoch,
          'endTimestamp': endToday.millisecondsSinceEpoch,
          'isToday': isToday,
          'isCurrent': isToday &&
              !now.isBefore(startToday) &&
              now.isBefore(endToday),
          'isPast': isToday && endToday.isBefore(now),
        });
      } catch (_) {}
    }

    // Sort: today's classes first by time, then the rest by time-of-day.
    displayClasses.sort((a, b) {
      final aToday = a['isToday'] == true ? 0 : 1;
      final bToday = b['isToday'] == true ? 0 : 1;
      if (aToday != bToday) return aToday.compareTo(bToday);
      return (a['startTimestamp'] as int).compareTo(b['startTimestamp'] as int);
    });

    todayClasses.sort((a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime));
    debugPrint('[WidgetData][Class] total=${displayClasses.length} today=${todayClasses.length}');

    if (displayClasses.isEmpty) {
      result['statusMessage'] = 'Nothing to show';
      return result;
    }

    // Widget has content whenever the user has any class routine (matches UI).
    result['hasToday'] = true;
    result['classItems'] = displayClasses;
    result['todayItems'] =
        displayClasses.where((e) => e['isToday'] == true).toList();

    // Prefer a live "now" card from today's schedule.
    Map<String, dynamic>? currentClass;
    for (final cls in todayClasses) {
      final start = cls['start'] as DateTime;
      final end = cls['end'] as DateTime;
      if (!now.isBefore(start) && now.isBefore(end)) {
        currentClass = cls;
        break;
      }
    }

    if (currentClass != null) {
      final end = currentClass['end'] as DateTime;
      final remainingMin = end.difference(now).inMinutes;
      result['currentSubject'] = currentClass['subject'] as String;
      result['currentTime'] = '${currentClass['timeText']} – ${currentClass['endTimeText']}';
      result['currentLocation'] = currentClass['location'] as String? ?? '';
      result['currentRemaining'] = remainingMin > 60
          ? '${remainingMin ~/ 60}h ${remainingMin % 60}m left'
          : '${remainingMin}m left';
      result['statusMessage'] = 'Now: ${currentClass['subject']}';
    } else if (todayClasses.isNotEmpty) {
      final next = todayClasses.firstWhere(
        (cls) => (cls['start'] as DateTime).isAfter(now),
        orElse: () => todayClasses.first,
      );
      result['nextSubject'] = next['subject'] as String;
      result['nextTime'] = '${next['timeText']} – ${next['endTimeText']}';
      result['nextLocation'] = next['location'] as String? ?? '';
      result['statusMessage'] = 'Next: ${next['subject']}';
    } else {
      result['statusMessage'] = '${displayClasses.length} classes scheduled';
    }
  } catch (e, st) {
    debugPrint('[WidgetData] _fetchClassRoutineData error: $e');
    debugPrint('[WidgetData] stack: $st');
    result['hasToday'] = false;
    result['statusMessage'] = 'Nothing to show';
    result['classItems'] = <Map<String, dynamic>>[];
  }

  return result;
}
