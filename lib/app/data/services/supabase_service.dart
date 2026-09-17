import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/widget_data_service.dart';
import '../models/subject_model.dart';
import '../models/topic_model.dart';
import '../models/revision_schedule_model.dart';
import '../models/revision_session_model.dart';
import '../models/class_routine_model.dart';
import '../models/daily_routine_model.dart';

part 'supabase/subjects_api.dart';
part 'supabase/topics_api.dart';
part 'supabase/schedules_api.dart';
part 'supabase/sessions_api.dart';
part 'supabase/stats_api.dart';
part 'supabase/class_routines_api.dart';
part 'supabase/daily_routines_api.dart';

/// Core Supabase access: auth context, realtime streams, and lifecycle.
/// Table CRUD lives in sibling `supabase/*_api.dart` parts.
class SupabaseService extends GetxService {
  final client = Supabase.instance.client;
  final _uuid = const Uuid();
  User? get currentUser => client.auth.currentUser;
  String get userId => currentUser!.id;

  // ── Realtime streams ──
  final _subjectsController = StreamController<List<SubjectModel>>.broadcast();
  final _topicsController = StreamController<List<TopicModel>>.broadcast();
  final _schedulesController =
      StreamController<List<RevisionScheduleModel>>.broadcast();
  final _classRoutinesController =
      StreamController<List<ClassRoutineModel>>.broadcast();
  final _dailyRoutinesController =
      StreamController<List<DailyRoutineModel>>.broadcast();

  Stream<List<SubjectModel>> get subjectsStream => _subjectsController.stream;
  Stream<List<TopicModel>> get topicsStream => _topicsController.stream;
  Stream<List<RevisionScheduleModel>> get schedulesStream =>
      _schedulesController.stream;
  Stream<List<ClassRoutineModel>> get classRoutinesStream =>
      _classRoutinesController.stream;
  Stream<List<DailyRoutineModel>> get dailyRoutinesStream =>
      _dailyRoutinesController.stream;

  RealtimeChannel? _subjectsChannel;
  RealtimeChannel? _topicsChannel;
  RealtimeChannel? _schedulesChannel;
  RealtimeChannel? _classRoutinesChannel;
  RealtimeChannel? _dailyRoutinesChannel;

  /// Start listening to all table changes. Call once on app start.
  void initRealtime() {
    _subjectsChannel = client.channel('subjects-realtime')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'subjects',
        callback: (_) => _refreshSubjects(),
      )
      ..subscribe();

    _topicsChannel = client.channel('topics-realtime')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'topics',
        callback: (_) => _refreshTopics(),
      )
      ..subscribe();

    _schedulesChannel = client.channel('schedules-realtime')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'revision_schedules',
        callback: (_) => _refreshSchedules(),
      )
      ..subscribe();

    _classRoutinesChannel = client.channel('class-routines-realtime')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'class_routines',
        callback: (_) => _refreshClassRoutines(),
      )
      ..subscribe();

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
    } catch (e) {
      debugPrint('[Supabase] ❌ _refreshSubjects failed: $e');
    }
  }

  Future<void> _refreshTopics() async {
    try {
      final r = await client.from('topics').select()
          .eq('user_id', userId).order('created_at', ascending: false);
      final allTopics =
          (r as List).map((j) => TopicModel.fromJson(j)).toList();
      _topicsController.add(allTopics);
    } catch (e) {
      debugPrint('[Supabase] ❌ _refreshTopics failed: $e');
    }
  }

  Future<void> _refreshSchedules() async {
    try {
      final schedules = await fetchSchedules();
      _schedulesController.add(schedules);
      _debouncedWidgetUpdate();
      _debouncedNotificationUpdate();
    } catch (e) {
      debugPrint('[Supabase] ❌ _refreshSchedules failed: $e');
    }
  }

  Future<void> _refreshClassRoutines() async {
    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, 1);
      final to = from.add(const Duration(days: 60));
      final rows = await fetchClassRoutines(fromDate: from, toDate: to);
      final models =
          rows.map((j) => ClassRoutineModel.fromJson(j)).toList();
      _classRoutinesController.add(models);
      _debouncedWidgetUpdate();
      _debouncedNotificationUpdate();
    } catch (e) {
      debugPrint('[Supabase] ❌ _refreshClassRoutines failed: $e');
    }
  }

  Future<void> _refreshDailyRoutines() async {
    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day);
      final to = from.add(const Duration(days: 30));
      final rows = await fetchDailyRoutines(fromDate: from, toDate: to);
      final models =
          rows.map((j) => DailyRoutineModel.fromJson(j)).toList();
      _dailyRoutinesController.add(models);
      _debouncedWidgetUpdate();
      _debouncedNotificationUpdate();
    } catch (e) {
      debugPrint('[Supabase] ❌ _refreshDailyRoutines failed: $e');
    }
  }

  DateTime? _lastWidgetUpdate;
  void _debouncedWidgetUpdate() {
    final now = DateTime.now();
    if (_lastWidgetUpdate != null &&
        now.difference(_lastWidgetUpdate!).inSeconds < 20) {
      return;
    }
    _lastWidgetUpdate = now;
    Future.microtask(() {
      try {
        WidgetDataProvider.updateAllWidgets();
      } catch (_) {}
    });
  }

  DateTime? _lastNotificationUpdate;
  void _debouncedNotificationUpdate({bool force = false}) {
    final now = DateTime.now();
    if (!force &&
        _lastNotificationUpdate != null &&
        now.difference(_lastNotificationUpdate!).inSeconds < 2) {
      return;
    }
    _lastNotificationUpdate = now;
    Future.microtask(() {
      try {
        NotificationService.to.rescheduleAll(force: true);
      } catch (_) {}
    });
  }

  void refreshSubjects() => _refreshSubjects();
  void refreshTopics() => _refreshTopics();
  void refreshSchedules() => _refreshSchedules();
  void refreshClassRoutines() => _refreshClassRoutines();
  void refreshDailyRoutines() => _refreshDailyRoutines();

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
