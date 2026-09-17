part of '../supabase_service.dart';

/// Class routines for [SupabaseService].
extension SupabaseClassRoutinesApi on SupabaseService {
  Future<List<Map<String, dynamic>>> fetchClassRoutines({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    var query = client.from('class_routines').select().eq('user_id', userId);
    if (fromDate != null) {
      query = query.gte('start_time', fromDate.toIso8601String());
    }
    if (toDate != null) {
      query = query.lte('start_time', toDate.toIso8601String());
    }
    final r = await query.order('start_time', ascending: true);
    return (r as List).map((j) => Map<String, dynamic>.from(j as Map)).toList();
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
