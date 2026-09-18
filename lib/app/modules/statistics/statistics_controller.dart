import 'dart:async';

import 'package:get/get.dart';
import '../../data/models/revision_schedule_model.dart';
import '../../data/models/subject_model.dart';
import '../../data/models/topic_model.dart';
import '../../data/repositories/revision_repository.dart';
import '../../data/repositories/subject_repository.dart';
import '../../data/repositories/topic_repository.dart';
import '../../data/services/supabase_service.dart';

class HistoryController extends GetxController {
  final _repo = Get.find<RevisionRepository>();
  final _subjectRepo = Get.find<SubjectRepository>();
  final _topicRepo = Get.find<TopicRepository>();

  final stats = <String, dynamic>{}.obs;
  final subjects = <SubjectModel>[].obs;
  final topics = <TopicModel>[].obs;
  final schedules = <RevisionScheduleModel>[].obs;
  final isLoading = true.obs;

  // Computed
  final totalSubjects = 0.obs;
  final totalTopics = 0.obs;
  final completedTopics = 0.obs;
  final streakDays = 0.obs;
  /// Sum of completed revisions across ALL topics (revision-weighted, so a
  /// topic with 1/6 revisions counts as 1 — not 0).
  final revisionsDone = 0.obs;
  /// 6 planned revisions per topic.
  final revisionsTotal = 0.obs;
  /// Completed revisions per weekday, Mon→Sun, for the current week (real data).
  final weeklyActivity = <int>[0, 0, 0, 0, 0, 0, 0].obs;

  StreamSubscription? _schedulesSub;
  StreamSubscription? _subjectsSub;
  StreamSubscription? _topicsSub;
  Timer? _debounce;
  bool _loading = false;

  @override
  void onInit() {
    super.onInit();
    // Realtime must be on — History is often the first dashboard pane to listen.
    try {
      Get.find<SupabaseService>().initRealtime();
    } catch (_) {}
    load();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    _schedulesSub?.cancel();
    _subjectsSub?.cancel();
    _topicsSub?.cancel();
    final svc = Get.find<SupabaseService>();
    svc.initRealtime();
    // Stream subscription → silent reload (no shimmer flicker).
    _schedulesSub = svc.schedulesStream.listen((_) => _scheduleSilentRefresh());
    _subjectsSub = svc.subjectsStream.listen((_) => _scheduleSilentRefresh());
    _topicsSub = svc.topicsStream.listen((_) => _scheduleSilentRefresh());
  }

  void _scheduleSilentRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      load(showLoading: false);
    });
  }

  @override
  void onClose() {
    _debounce?.cancel();
    _schedulesSub?.cancel();
    _subjectsSub?.cancel();
    _topicsSub?.cancel();
    super.onClose();
  }

  Future<void> load({bool showLoading = true}) async {
    if (_loading) return;
    _loading = true;
    try {
      if (Get.find<SupabaseService>().currentUser == null) return;
      if (showLoading) isLoading.value = true;

      // Load stats and subjects in parallel
      final results = await Future.wait([
        _repo.getDashboardStats(),
        _subjectRepo.getAll(),
      ]);

      stats.assignAll(results[0] as Map<String, dynamic>);
      subjects.assignAll(results[1] as List<SubjectModel>);

      // Fetch topics for each subject with a timeout
      final allTopics = <TopicModel>[];
      await Future.wait(
        subjects.map((s) async {
          try {
            final t = await _topicRepo.getBySubject(s.id)
                .timeout(const Duration(seconds: 5));
            allTopics.addAll(t);
          } catch (_) {}
        }),
      );
      topics.assignAll(allTopics);

      final allSchedules = await _repo.getSchedules();
      schedules.assignAll(allSchedules);

      // ── Real revision-weighted progress ──
      totalSubjects.value = subjects.length;
      totalTopics.value = topics.length;
      completedTopics.value = topics.where((t) => t.totalRevisions >= 6).length;
      revisionsDone.value =
          topics.fold<int>(0, (sum, t) => sum + t.totalRevisions.clamp(0, 6));
      revisionsTotal.value = topics.length * 6;

      // ── Real weekly activity (completed revisions per weekday) ──
      weeklyActivity.value = _computeWeeklyActivity(allSchedules);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final completedDates = allSchedules
          .where((s) => s.status == 'completed')
          .map((s) => DateTime(s.updatedAt.year, s.updatedAt.month, s.updatedAt.day))
          .toSet();
      int streak = 0;
      var checkDate = today;
      while (completedDates.contains(checkDate)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      }
      streakDays.value = streak;
    } catch (e) {
      // silent
    } finally {
      isLoading.value = false;
      _loading = false;
    }
  }

  /// Completed revisions grouped by weekday (Mon..Sun) of the current week,
  /// computed from real schedule completion timestamps.
  List<int> _computeWeeklyActivity(List<RevisionScheduleModel> allSchedules) {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final counts = List<int>.filled(7, 0);
    for (final s in allSchedules) {
      if (s.status != 'completed') continue;
      final day = DateTime(s.updatedAt.year, s.updatedAt.month, s.updatedAt.day);
      final diff = day.difference(weekStart).inDays;
      if (diff >= 0 && diff < 7) counts[diff]++;
    }
    return counts;
  }

  /// Overall completion as a fraction of ALL planned revisions.
  double get completionFraction =>
      revisionsTotal.value == 0 ? 0.0 : revisionsDone.value / revisionsTotal.value;

  /// Subject progress data — revision-weighted so partial progress counts:
  /// e.g. 5 topics with 1 revision done in total → 1/30 done (3%).
  List<Map<String, dynamic>> get subjectProgress {
    return subjects.map((s) {
      final subjectTopics = topics.where((t) => t.subjectId == s.id).toList();
      final done = subjectTopics.fold<int>(0, (sum, t) => sum + t.totalRevisions.clamp(0, 6));
      final planned = subjectTopics.length * 6;
      final fullyCompleted = subjectTopics.where((t) => t.totalRevisions >= 6).length;
      return {
        'subject': s,
        'total': subjectTopics.length,
        'completed': fullyCompleted,
        'revisionsDone': done,
        'revisionsPlanned': planned,
        'progress': planned > 0 ? done / planned : 0.0,
      };
    }).toList();
  }
}

