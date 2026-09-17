part of '../supabase_service.dart';

/// Dashboard / stats aggregates for [SupabaseService].
extension SupabaseStatsApi on SupabaseService {
  Future<Map<String, dynamic>> fetchDashboardStats() async {
    final now = DateTime.now();
    final ts = DateTime(now.year, now.month, now.day);
    final te = ts.add(const Duration(days: 1));
    final weekStart = ts.subtract(Duration(days: now.weekday - 1));

    final results = await Future.wait([
      client.from('revision_schedules').select('id')
          .eq('user_id', userId).eq('status', 'pending')
          .lt('scheduled_date', ts.toIso8601String()),
      client.from('revision_schedules').select('id')
          .eq('user_id', userId).eq('status', 'pending')
          .gte('scheduled_date', ts.toIso8601String())
          .lt('scheduled_date', te.toIso8601String()),
      client.from('revision_schedules').select('id')
          .eq('user_id', userId).eq('status', 'pending')
          .gte('scheduled_date', te.toIso8601String()),
      client.from('revision_sessions').select('id')
          .eq('user_id', userId).gte('started_at', weekStart.toIso8601String()),
      client.from('revision_schedules').select('id')
          .eq('user_id', userId).eq('status', 'completed'),
      client.from('topics').select('id').eq('user_id', userId),
    ]);

    final overdueCount = (results[0] as List).length;
    final todayCount = (results[1] as List).length;
    final upcomingCount = (results[2] as List).length;
    final sessionsCount = (results[3] as List).length;
    final cl = (results[4] as List).length;
    final topicCount = (results[5] as List).length;
    final plannedTotal = topicCount * AppConstants.revisionDays.length;

    return {
      'overdue_count': overdueCount,
      'today_count': todayCount,
      'upcoming_count': upcomingCount,
      'sessions_this_week': sessionsCount,
      'total_completed': cl,
      'total_topics': topicCount,
      'total_schedules': plannedTotal,
      'completion_rate':
          plannedTotal == 0 ? 0.0 : (cl / plannedTotal).clamp(0.0, 1.0),
    };
  }
}
