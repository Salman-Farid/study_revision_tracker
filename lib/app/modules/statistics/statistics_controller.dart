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
  final isLoading = true.obs;

  // Computed
  final totalSubjects = 0.obs;
  final totalTopics = 0.obs;
  final completedTopics = 0.obs;
  final streakDays = 0.obs;

  StreamSubscription? _schedulesSub;
  StreamSubscription? _subjectsSub;
  StreamSubscription? _topicsSub;

  @override
  void onInit() {
    super.onInit();
    load();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    _schedulesSub?.cancel();
    _subjectsSub?.cancel();
    _topicsSub?.cancel();
    final svc = Get.find<SupabaseService>();
    _schedulesSub = svc.schedulesStream.listen((_) => load());
    _subjectsSub = svc.subjectsStream.listen((_) => load());
    _topicsSub = svc.topicsStream.listen((_) => load());
  }

  @override
  void onClose() {
    _schedulesSub?.cancel();
    _subjectsSub?.cancel();
    _topicsSub?.cancel();
    super.onClose();
  }

  Future<void> load() async {
    try {
      if (Get.find<SupabaseService>().currentUser == null) return;
      isLoading.value = true;

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

      // Calculate computed values
      totalSubjects.value = subjects.length;
      totalTopics.value = topics.length;
      completedTopics.value = topics.where((t) => t.totalRevisions >= 6).length;

      // Calculate streak: consecutive days with completed revisions
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final schedules = await _repo.getSchedules();
      final completedDates = schedules
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
    }
  }

  /// Subject progress data for charts
  List<Map<String, dynamic>> get subjectProgress {
    return subjects.map((s) {
      final subjectTopics = topics.where((t) => t.subjectId == s.id).toList();
      final completed = subjectTopics.where((t) => t.totalRevisions >= 6).length;
      return {
        'subject': s,
        'total': subjectTopics.length,
        'completed': completed,
      };
    }).toList();
  }
}
