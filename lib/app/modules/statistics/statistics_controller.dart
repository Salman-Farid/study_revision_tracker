import 'package:collection/collection.dart';
import 'package:get/get.dart';
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
  final avgMastery = 0.0.obs;
  final streakDays = 0.obs;

  @override
  void onInit() {
    super.onInit();
    load();
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
      completedTopics.value = topics.where((t) => t.isCompleted).length;

      if (topics.isNotEmpty) {
        avgMastery.value = topics.map((t) => t.masteryLevel).sum / topics.length;
      }

      // Calculate streak from stats
      streakDays.value = stats['current_streak'] ?? 0;
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
      final completed = subjectTopics.where((t) => t.isCompleted).length;
      final avgM = subjectTopics.isEmpty
          ? 0.0
          : subjectTopics.map((t) => t.masteryLevel).sum / subjectTopics.length;
      return {
        'subject': s,
        'total': subjectTopics.length,
        'completed': completed,
        'mastery': avgM,
      };
    }).toList();
  }

  /// Mastery distribution
  Map<String, int> get masteryDistribution {
    int novice = 0, learning = 0, familiar = 0, mastered = 0;
    for (final t in topics) {
      if (t.masteryLevel < 0.25) {
        novice++;
      } else if (t.masteryLevel < 0.5) {
        learning++;
      } else if (t.masteryLevel < 0.75) {
        familiar++;
      } else {
        mastered++;
      }
    }
    return {'Novice': novice, 'Learning': learning, 'Familiar': familiar, 'Mastered': mastered};
  }
}
