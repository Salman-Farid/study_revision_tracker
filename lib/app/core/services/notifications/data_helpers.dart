part of '../notification_service.dart';

/// Supabase fetch helpers for reminders.
extension NotificationDataHelpers on NotificationService {

  Future<Map<String, String>> _fetchNames(
    SupabaseClient client,
    String table,
    Set<String> ids,
  ) async {
    if (ids.isEmpty) return {};
    final rows =
        await client.from(table).select('id, name').inFilter('id', ids.toList());
    return {for (final r in rows as List) r['id'] as String: r['name'] as String? ?? ''};
  }

  Future<List<RevisionScheduleModel>> _fetchPendingRevisions(
    SupabaseClient client,
    String userId,
    DateTime from,
    DateTime to,
  ) async {
    final rows = await client
        .from('revision_schedules')
        .select()
        .eq('user_id', userId)
        .eq('status', 'pending')
        .gte('scheduled_date', from.toIso8601String())
        .lte('scheduled_date', to.toIso8601String())
        .order('scheduled_date', ascending: true);
    return (rows as List)
        .map((j) => RevisionScheduleModel.fromJson(j))
        .toList();
  }

  Future<List<ClassRoutineModel>> _fetchActiveClassRoutines(
    SupabaseClient client,
    String userId,
  ) async {
    final rows = await client
        .from('class_routines')
        .select()
        .eq('user_id', userId)
        .order('start_time', ascending: true);
    return (rows as List)
        .map((j) => ClassRoutineModel.fromJson(j))
        .toList();
  }

  Future<List<DailyRoutineModel>> _fetchActiveDailyRoutines(
    SupabaseClient client,
    String userId,
    DateTime from,
  ) async {
    final to = from.add(const Duration(days: 7));
    final rows = await client
        .from('daily_routines')
        .select()
        .eq('user_id', userId)
        .gte('date', from.toIso8601String().substring(0, 10))
        .lte('date', to.toIso8601String().substring(0, 10))
        .order('date', ascending: true);
    return (rows as List)
        .map((j) => DailyRoutineModel.fromJson(j))
        .toList();
  }
}
