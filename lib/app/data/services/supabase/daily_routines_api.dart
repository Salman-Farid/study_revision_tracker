part of '../supabase_service.dart';

/// Daily routines for [SupabaseService].
extension SupabaseDailyRoutinesApi on SupabaseService {
  Future<List<Map<String, dynamic>>> fetchDailyRoutines({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    var query = client.from('daily_routines').select().eq('user_id', userId);
    if (fromDate != null) {
      query = query.gte('date', fromDate.toIso8601String().substring(0, 10));
    }
    if (toDate != null) {
      query = query.lte('date', toDate.toIso8601String().substring(0, 10));
    }
    final r = await query.order('date', ascending: true);
    return (r as List).map((j) => Map<String, dynamic>.from(j as Map)).toList();
  }

  Future<Map<String, dynamic>> createDailyRoutine({
    required DateTime date,
    required List<Map<String, dynamic>> items,
  }) async {
    final data = {
      'id': _uuid.v4(),
      'user_id': userId,
      'date': date.toIso8601String().substring(0, 10),
      'items': items,
    };
    final r =
        await client.from('daily_routines').insert(data).select().single();
    _debouncedNotificationUpdate(force: true);
    return Map<String, dynamic>.from(r as Map);
  }

  Future<void> deleteDailyRoutine(String id) =>
      client.from('daily_routines').delete().eq('id', id);

  Future<int> deleteDailyRoutinesByDate(DateTime date) async {
    final from = DateTime(date.year, date.month, date.day);
    final to = from.add(const Duration(days: 1));
    final result = await client
        .from('daily_routines')
        .delete()
        .gte('date', from.toIso8601String().substring(0, 10))
        .lt('date', to.toIso8601String().substring(0, 10))
        .select('id');
    return (result as List).length;
  }
}
