import 'dart:async';

import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../models/subject_model.dart';
import '../models/topic_model.dart';
import '../models/revision_schedule_model.dart';
import '../models/revision_session_model.dart';
import '../models/class_routine_model.dart';
import '../models/daily_routine_model.dart';

class SupabaseService extends GetxService {
  final client = Supabase.instance.client;
  final _uuid = const Uuid();
  User? get currentUser => client.auth.currentUser;
  String get userId => currentUser!.id;

  // ── Realtime streams ──
  final _subjectsController = StreamController<List<SubjectModel>>.broadcast();
  final _topicsController = StreamController<List<TopicModel>>.broadcast();
  final _schedulesController = StreamController<List<RevisionScheduleModel>>.broadcast();
  final _classRoutinesController = StreamController<List<ClassRoutineModel>>.broadcast();
  final _dailyRoutinesController = StreamController<List<DailyRoutineModel>>.broadcast();

  Stream<List<SubjectModel>> get subjectsStream => _subjectsController.stream;
  Stream<List<TopicModel>> get topicsStream => _topicsController.stream;
  Stream<List<RevisionScheduleModel>> get schedulesStream => _schedulesController.stream;
  Stream<List<ClassRoutineModel>> get classRoutinesStream => _classRoutinesController.stream;
  Stream<List<DailyRoutineModel>> get dailyRoutinesStream => _dailyRoutinesController.stream;

  RealtimeChannel? _subjectsChannel;
  RealtimeChannel? _topicsChannel;
  RealtimeChannel? _schedulesChannel;
  RealtimeChannel? _classRoutinesChannel;
  RealtimeChannel? _dailyRoutinesChannel;

  // ── SUBJECTS ──
  Future<List<SubjectModel>> fetchSubjects() async {
    final r = await client.from('subjects').select()
      .eq('user_id', userId).eq('is_archived', false).order('created_at', ascending: false);
    return (r as List).map((j) => SubjectModel.fromJson(j)).toList();
  }

  Future<SubjectModel> createSubject({required String name, String? description,
    String? imageUrl, String? colorHex, int? iconCodePoint}) async {
    final data = {'id': _uuid.v4(), 'user_id': userId, 'name': name,
      'description': description, 'image_url': imageUrl,
      'color_hex': colorHex ?? '#6C63FF',
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

  Future<void> markFirstReadCompleted(String topicId) =>
    client.from('topics').update({'first_read_completed': true}).eq('id', topicId);

  Future<Map<String, dynamic>> getTopicFullStatus(String topicId) async {
    final topicRow = await client.from('topics').select().eq('id', topicId).single();
    final schedules = await client.from('revision_schedules').select()
      .eq('topic_id', topicId).order('day_number', ascending: true);
    final scheduleList = (schedules as List).map((j) => RevisionScheduleModel.fromJson(j)).toList();
    final topic = TopicModel.fromJson(topicRow);

    final completedSchedules = scheduleList.where((s) => s.status == 'completed').toList();
    final pendingSchedules = scheduleList.where((s) => s.status == 'pending').toList();
    final completedDays = completedSchedules.map((s) => s.dayNumber).toSet();
    final allDays = AppConstants.revisionDays;

    int nextPendingRevisionIndex = -1;
    for (int i = 0; i < allDays.length; i++) {
      if (!completedDays.contains(allDays[i])) {
        nextPendingRevisionIndex = i;
        break;
      }
    }

    final pendingBeforeNext = <int>[];
    if (nextPendingRevisionIndex > 0) {
      for (int i = 0; i < nextPendingRevisionIndex; i++) {
        if (!completedDays.contains(allDays[i])) {
          pendingBeforeNext.add(allDays[i]);
        }
      }
    }

    return {
      'topic': topic,
      'schedules': scheduleList,
      'totalRevisions': allDays.length,
      'completedRevisionCount': completedSchedules.length,
      'nextPendingRevisionIndex': nextPendingRevisionIndex,
      'nextPendingRevisionDay': nextPendingRevisionIndex >= 0 ? allDays[nextPendingRevisionIndex] : null,
      'pendingBeforeNext': pendingBeforeNext,
      'completedDays': completedDays.toList()..sort(),
      'pendingDays': pendingSchedules.map((s) => s.dayNumber).toList()..sort(),
    };
  }

  Future<void> markNextRevisionCompleted(String topicId) async {
    final status = await getTopicFullStatus(topicId);
    final nextIndex = status['nextPendingRevisionIndex'] as int;
    if (nextIndex < 0) return;

    final allDays = AppConstants.revisionDays;
    final nextDay = allDays[nextIndex];
    final schedules = status['schedules'] as List<RevisionScheduleModel>;
    final nextSchedule = schedules.firstWhere((s) => s.dayNumber == nextDay);

    await updateScheduleStatus(nextSchedule.id, 'completed');
    await updateTopic(topicId, {
      'total_revisions': (status['completedRevisionCount'] as int) + 1,
      'last_revised_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteTopic(String id, {String? subjectId}) async {
    await client.from('topics').delete().eq('id', id);
    // Decrement subject's total_topics count if subjectId provided
    if (subjectId != null) {
      try {
        final sub = await client.from('subjects').select('total_topics').eq('id', subjectId).single();
        final current = (sub['total_topics'] as int?) ?? 0;
        if (current > 0) {
          await client.from('subjects').update({'total_topics': current - 1}).eq('id', subjectId);
        }
      } catch (_) {}
    }
  }

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

  // ── REALTIME SUBSCRIPTIONS ──

  /// Start listening to all table changes. Call once on app start.
  void initRealtime() {
    // Subjects table changes
    _subjectsChannel = client.channel('subjects-realtime')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'subjects',
        callback: (_) => _refreshSubjects(),
      )
      ..subscribe();

    // Topics table changes
    _topicsChannel = client.channel('topics-realtime')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'topics',
        callback: (_) => _refreshTopics(),
      )
      ..subscribe();

    // Revision schedules table changes
    _schedulesChannel = client.channel('schedules-realtime')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'revision_schedules',
        callback: (_) => _refreshSchedules(),
      )
      ..subscribe();

    // Class routines table changes
    _classRoutinesChannel = client.channel('class-routines-realtime')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'class_routines',
        callback: (_) => _refreshClassRoutines(),
      )
      ..subscribe();

    // Daily routines table changes
    _dailyRoutinesChannel = client.channel('daily-routines-realtime')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'daily_routines',
        callback: (_) => _refreshDailyRoutines(),
      )
      ..subscribe();
  }

  Future<void> _refreshSubjects() async {
    try {
      final subjects = await fetchSubjects();
      _subjectsController.add(subjects);
    } catch (e) { print('[Supabase] ❌ _refreshSubjects failed: $e'); }
  }

  Future<void> _refreshTopics() async {
    try {
      // Refresh all topics for all subjects
      final subjects = await fetchSubjects();
      final allTopics = <TopicModel>[];
      for (final sub in subjects) {
        allTopics.addAll(await fetchTopics(sub.id));
      }
      _topicsController.add(allTopics);
    } catch (e) { print('[Supabase] ❌ _refreshTopics failed: $e'); }
  }

  Future<void> _refreshSchedules() async {
    try {
      final schedules = await fetchSchedules();
      _schedulesController.add(schedules);
    } catch (e) { print('[Supabase] ❌ _refreshSchedules failed: $e'); }
  }

  Future<void> _refreshClassRoutines() async {
    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, 1);
      final to = from.add(const Duration(days: 60));
      final rows = await fetchClassRoutines(fromDate: from, toDate: to);
      final models = rows.map((j) => ClassRoutineModel.fromJson(j)).toList();
      _classRoutinesController.add(models);
    } catch (e) { print('[Supabase] ❌ _refreshClassRoutines failed: $e'); }
  }

  Future<void> _refreshDailyRoutines() async {
    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day);
      final to = from.add(const Duration(days: 30));
      final rows = await fetchDailyRoutines(fromDate: from, toDate: to);
      final models = rows.map((j) => DailyRoutineModel.fromJson(j)).toList();
      _dailyRoutinesController.add(models);
    } catch (e) { print('[Supabase] ❌ _refreshDailyRoutines failed: $e'); }
  }

  /// Manually trigger a refresh
  void refreshSubjects() => _refreshSubjects();
  void refreshTopics() => _refreshTopics();
  void refreshSchedules() => _refreshSchedules();
  void refreshClassRoutines() => _refreshClassRoutines();
  void refreshDailyRoutines() => _refreshDailyRoutines();

  // ── CLASS ROUTINES ──

  Future<List<Map<String, dynamic>>> fetchClassRoutines({DateTime? fromDate, DateTime? toDate}) async {
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
    final r = await client.from('class_routines').insert(data).select().single();
    return Map<String, dynamic>.from(r as Map);
  }

  Future<void> deleteClassRoutine(String id) =>
      client.from('class_routines').delete().eq('id', id);

  // ── DAILY ROUTINES ──

  Future<List<Map<String, dynamic>>> fetchDailyRoutines({DateTime? fromDate, DateTime? toDate}) async {
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
    final r = await client.from('daily_routines').insert(data).select().single();
    return Map<String, dynamic>.from(r as Map);
  }

  Future<void> deleteDailyRoutine(String id) =>
      client.from('daily_routines').delete().eq('id', id);

  Future<int> deleteDailyRoutinesByDate(DateTime date) async {
    final from = DateTime(date.year, date.month, date.day);
    final to = from.add(const Duration(days: 1));
    final result = await client.from('daily_routines').delete()
        .gte('date', from.toIso8601String().substring(0, 10))
        .lt('date', to.toIso8601String().substring(0, 10))
        .select('id');
    return (result as List).length;
  }

  @override
  void onClose() {
    _subjectsChannel?.unsubscribe();
    _topicsChannel?.unsubscribe();
    _schedulesChannel?.unsubscribe();
    _classRoutinesChannel?.unsubscribe();
    _dailyRoutinesChannel?.unsubscribe();
    _subjectsController.close();
    _topicsController.close();
    _schedulesController.close();
    _classRoutinesController.close();
    _dailyRoutinesController.close();
    super.onClose();
  }
}
