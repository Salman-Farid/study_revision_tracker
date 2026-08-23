import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../models/subject_model.dart';
import '../models/topic_model.dart';
import '../models/revision_schedule_model.dart';
import '../models/revision_session_model.dart';

class SupabaseService extends GetxService {
  final client = Supabase.instance.client;
  final _uuid = const Uuid();
  User? get currentUser => client.auth.currentUser;
  String get userId => currentUser!.id;

  // ── SUBJECTS ──
  Future<List<SubjectModel>> fetchSubjects() async {
    final r = await client.from('subjects').select()
      .eq('user_id', userId).eq('is_archived', false).order('created_at', ascending: false);
    return (r as List).map((j) => SubjectModel.fromJson(j)).toList();
  }

  Future<SubjectModel> createSubject({required String name, String? description,
    String? colorHex, int? iconCodePoint}) async {
    final data = {'id': _uuid.v4(), 'user_id': userId, 'name': name,
      'description': description, 'color_hex': colorHex ?? '#6C63FF',
      'icon_code_point': iconCodePoint ?? 0xe8a1};
    final r = await client.from('subjects').insert(data).select().single();
    return SubjectModel.fromJson(r);
  }

  Future<void> updateSubject(String id, Map<String, dynamic> u) =>
    client.from('subjects').update(u).eq('id', id);
  Future<void> deleteSubject(String id) =>
    client.from('subjects').delete().eq('id', id);

  // ── TOPICS ──
  Future<List<TopicModel>> fetchTopics(String subjectId) async {
    final r = await client.from('topics').select()
      .eq('subject_id', subjectId).order('created_at', ascending: false);
    return (r as List).map((j) => TopicModel.fromJson(j)).toList();
  }

  Future<TopicModel> createTopic({required String subjectId, required String name,
    String? notes, String? referenceAnswer, DateTime? firstReadDate}) async {
    final data = {'id': _uuid.v4(), 'user_id': userId, 'subject_id': subjectId,
      'name': name, 'notes': notes, 'reference_answer': referenceAnswer,
      'first_read_date': (firstReadDate ?? DateTime.now()).toIso8601String()};
    final r = await client.from('topics').insert(data).select().single();
    // increment subject topic count
    final sub = await client.from('subjects').select('total_topics').eq('id', subjectId).single();
    await client.from('subjects').update({'total_topics': (sub['total_topics'] as int) + 1}).eq('id', subjectId);
    return TopicModel.fromJson(r);
  }

  Future<void> updateTopic(String id, Map<String, dynamic> u) =>
    client.from('topics').update(u).eq('id', id);
  Future<void> deleteTopic(String id) => client.from('topics').delete().eq('id', id);

  // ── SCHEDULES ──
  Future<List<RevisionScheduleModel>> fetchSchedules({String? topicId,
    String? status, DateTime? fromDate, DateTime? toDate}) async {
    var q = client.from('revision_schedules').select().eq('user_id', userId);
    if (topicId != null) q = q.eq('topic_id', topicId);
    if (status != null) q = q.eq('status', status);
    if (fromDate != null) q = q.gte('scheduled_date', fromDate.toIso8601String());
    if (toDate != null) q = q.lte('scheduled_date', toDate.toIso8601String());
    final r = await q.order('scheduled_date', ascending: true);
    return (r as List).map((j) => RevisionScheduleModel.fromJson(j)).toList();
  }

  Future<List<RevisionScheduleModel>> createRevisionSchedules({
    required String topicId, required String subjectId, required DateTime firstReadDate}) async {
    final rows = <Map<String, dynamic>>[];
    for (final d in AppConstants.revisionDays) {
      rows.add({'id': _uuid.v4(), 'user_id': userId, 'topic_id': topicId,
        'subject_id': subjectId, 'scheduled_date': firstReadDate.add(Duration(days: d)).toIso8601String(),
        'day_number': d, 'status': 'pending'});
    }
    final r = await client.from('revision_schedules').insert(rows).select();
    return (r as List).map((j) => RevisionScheduleModel.fromJson(j)).toList();
  }

  Future<void> updateScheduleStatus(String id, String st) =>
    client.from('revision_schedules').update({'status': st}).eq('id', id);

  // ── SESSIONS ──
  Future<RevisionSessionModel> createSession({required String topicId, String? scheduleId}) async {
    final data = {'id': _uuid.v4(), 'user_id': userId, 'topic_id': topicId,
      'schedule_id': scheduleId, 'started_at': DateTime.now().toIso8601String()};
    final r = await client.from('revision_sessions').insert(data).select().single();
    return RevisionSessionModel.fromJson(r);
  }

  Future<void> completeSession(String sid, {required String recallRating,
    required double confidence, required int durationSeconds, String? notes}) =>
    client.from('revision_sessions').update({
      'ended_at': DateTime.now().toIso8601String(), 'duration_seconds': durationSeconds,
      'recall_rating': recallRating, 'confidence': confidence, 'notes': notes}).eq('id', sid);

  Future<List<RevisionSessionModel>> fetchSessions({String? topicId,
    DateTime? fromDate, DateTime? toDate}) async {
    var q = client.from('revision_sessions').select().eq('user_id', userId);
    if (topicId != null) q = q.eq('topic_id', topicId);
    if (fromDate != null) q = q.gte('started_at', fromDate.toIso8601String());
    if (toDate != null) q = q.lte('started_at', toDate.toIso8601String());
    final r = await q.order('started_at', ascending: false);
    return (r as List).map((j) => RevisionSessionModel.fromJson(j)).toList();
  }

  // ── STATS ──
  Future<Map<String, dynamic>> fetchDashboardStats() async {
    final now = DateTime.now();
    final ts = DateTime(now.year, now.month, now.day);
    final te = ts.add(const Duration(days: 1));
    final overdue = await client.from('revision_schedules').select().eq('user_id', userId)
      .eq('status', 'pending').lt('scheduled_date', ts.toIso8601String());
    final today = await client.from('revision_schedules').select().eq('user_id', userId)
      .eq('status', 'pending').gte('scheduled_date', ts.toIso8601String())
      .lt('scheduled_date', te.toIso8601String());
    final upcomingEnd = te.add(const Duration(days: 7));
    final upcoming = await client.from('revision_schedules').select().eq('user_id', userId)
      .eq('status', 'pending').gte('scheduled_date', te.toIso8601String())
      .lt('scheduled_date', upcomingEnd.toIso8601String());
    final weekStart = ts.subtract(Duration(days: now.weekday - 1));
    final sessions = await client.from('revision_sessions').select().eq('user_id', userId)
      .gte('started_at', weekStart.toIso8601String());
    final completed = await client.from('revision_schedules').select('id')
      .eq('user_id', userId).eq('status', 'completed');
    final total = await client.from('revision_schedules').select('id').eq('user_id', userId);
    final tl = (total as List).length;
    final cl = (completed as List).length;
    return {'overdue_count': (overdue as List).length, 'today_count': (today as List).length,
      'upcoming_count': (upcoming as List).length, 'sessions_this_week': (sessions as List).length,
      'total_completed': cl, 'total_schedules': tl, 'completion_rate': tl == 0 ? 0.0 : cl / tl};
  }
}
