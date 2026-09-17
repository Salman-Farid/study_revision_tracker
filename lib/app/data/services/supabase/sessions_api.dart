part of '../supabase_service.dart';

/// Revision sessions for [SupabaseService].
extension SupabaseSessionsApi on SupabaseService {
  Future<RevisionSessionModel> createSession({
    required String topicId,
    String? scheduleId,
  }) async {
    final data = {
      'id': _uuid.v4(),
      'user_id': userId,
      'topic_id': topicId,
      'schedule_id': scheduleId,
      'started_at': DateTime.now().toIso8601String(),
    };
    final r =
        await client.from('revision_sessions').insert(data).select().single();
    return RevisionSessionModel.fromJson(r);
  }

  Future<void> completeSession(
    String sid, {
    required String recallRating,
    required double confidence,
    required int durationSeconds,
    String? notes,
  }) =>
      client.from('revision_sessions').update({
        'ended_at': DateTime.now().toIso8601String(),
        'duration_seconds': durationSeconds,
        'recall_rating': recallRating,
        'confidence': confidence,
        'notes': notes,
      }).eq('id', sid);

  Future<List<RevisionSessionModel>> fetchSessions({
    String? topicId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    var q = client.from('revision_sessions').select().eq('user_id', userId);
    if (topicId != null) q = q.eq('topic_id', topicId);
    if (fromDate != null) q = q.gte('started_at', fromDate.toIso8601String());
    if (toDate != null) q = q.lte('started_at', toDate.toIso8601String());
    final r = await q.order('started_at', ascending: false);
    return (r as List).map((j) => RevisionSessionModel.fromJson(j)).toList();
  }
}
