import 'package:collection/collection.dart';
import 'package:get/get.dart';
import '../../data/models/revision_schedule_model.dart';
import '../../data/models/topic_model.dart';
import '../../data/models/subject_model.dart';
import '../../data/repositories/revision_repository.dart';
import '../../data/repositories/topic_repository.dart';
import '../../data/repositories/subject_repository.dart';
import '../../data/services/supabase_service.dart';

class DashboardController extends GetxController {
  final _repo = Get.find<RevisionRepository>();
  final _topicRepo = Get.find<TopicRepository>();
  final _subjectRepo = Get.find<SubjectRepository>();
  final stats = <String, dynamic>{}.obs;
  final isLoading = true.obs;
  final pendingSchedules = <RevisionScheduleModel>[].obs;

  @override void onInit() { super.onInit(); load(); }

  Future<void> load() async {
    try {
      if (Get.find<SupabaseService>().currentUser == null) return;
      isLoading.value = true;
      stats.assignAll(await _repo.getDashboardStats());
      final now = DateTime.now();
      final ts = DateTime(now.year, now.month, now.day);
      final te = ts.add(const Duration(days: 1));
      final overdue = await _repo.getSchedules(status: 'pending', toDate: ts);
      final today = await _repo.getSchedules(status: 'pending', fromDate: ts, toDate: te);
      pendingSchedules.assignAll([...overdue, ...today]);
    } catch (e) { /* silent */ }
    finally { isLoading.value = false; }
  }

  Future<void> startRevising() async {
    if (pendingSchedules.isEmpty) {
      Get.snackbar('All caught up', 'No pending revisions', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final schedule = pendingSchedules.first;
    try {
      final topics = await _topicRepo.getBySubject(schedule.subjectId);
      final topic = topics.firstWhereOrNull((t) => t.id == schedule.topicId);
      if (topic == null) {
        Get.snackbar('Error', 'Topic not found');
        return;
      }
      final subjects = await _subjectRepo.getAll();
      final subject = subjects.firstWhereOrNull((s) => s.id == schedule.subjectId);
      if (subject == null) {
        Get.snackbar('Error', 'Subject not found');
        return;
      }
      final schedules = await _repo.getSchedules(topicId: topic.id, status: 'pending');
      Get.toNamed('/revision-session/${topic.id}',
        arguments: {'topic': topic, 'subject': subject, 'schedules': schedules});
    } catch (e) {
      Get.snackbar('Error', 'Failed to start revision');
    }
  }
}
