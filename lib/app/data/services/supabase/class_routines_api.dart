part of '../supabase_service.dart';

/// Class routines for [SupabaseService].
extension SupabaseClassRoutinesApi on SupabaseService {
  Future<List<Map<String, dynamic>>> fetchClassRoutines({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    // Recurring classes store ONE representative start_time (often not "today").
    // Never SQL-filter by start_time — load all, then keep rows that hit the range
    // via recurring_days / dates. This is why "Tue 4:30 English" was missing.
    final query = client.from('class_routines').select().eq('user_id', userId);
    final r = await query.order('start_time', ascending: true);
    final rows = (r as List)
        .map((j) => Map<String, dynamic>.from(j as Map))
        .toList();
    if (fromDate == null && toDate == null) return rows;
    final from = DateTime(
        (fromDate ?? DateTime(2000)).year,
        (fromDate ?? DateTime(2000)).month,
        (fromDate ?? DateTime(2000)).day);
    final to = toDate == null
        ? from.add(const Duration(days: 365))
        : DateTime(toDate.year, toDate.month, toDate.day);
    return rows.where((row) {
      final recurring = row['recurring'] == true;
      final recDays = ((row['recurring_days'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList();
      final dates = ((row['dates'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
      for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
        if (recurring && recDays.contains(d.weekday)) return true;
        final key =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        if (dates.any((x) => x.startsWith(key))) return true;
      }
      // Legacy one-off with no dates list: fall back to start_time day.
      if (!recurring && dates.isEmpty) {
        final st = DateTime.parse(row['start_time'] as String);
        for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
          if (st.year == d.year && st.month == d.month && st.day == d.day) {
            return true;
          }
        }
      }
      return false;
    }).toList();
  }

  Future<Map<String, dynamic>> createClassRoutine({
    required String subjectName,
    required DateTime startTime,
    required int durationMinutes,
    required List<String> dates,
    String? location,
    bool recurring = false,
    List<int> recurringDays = const [],
    String? notes,
  }) async {
    final data = {
      'id': _uuid.v4(),
      'user_id': userId,
      'subject_name': subjectName,
      'start_time': startTime.toIso8601String(),
      'duration_minutes': durationMinutes,
      'dates': dates,
      'location': location,
      'recurring': recurring,
      'recurring_days': recurringDays,
      'notes': notes,
    };
    final r =
        await client.from('class_routines').insert(data).select().single();
    _debouncedNotificationUpdate(force: true);
    return Map<String, dynamic>.from(r as Map);
  }

  Future<void> deleteClassRoutine(String id) =>
      client.from('class_routines').delete().eq('id', id);
}
