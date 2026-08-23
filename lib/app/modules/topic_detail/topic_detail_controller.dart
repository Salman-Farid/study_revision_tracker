import 'package:get/get.dart';
import '../../data/models/topic_model.dart';
import '../../data/models/subject_model.dart';
import '../../data/models/revision_schedule_model.dart';
import '../../data/models/revision_session_model.dart';
import '../../data/repositories/revision_repository.dart';

class TopicDetailController extends GetxController {
  final _repo = Get.find<RevisionRepository>();
  late TopicModel topic;
  late SubjectModel subject;
  final schedules = <RevisionScheduleModel>[].obs;
  final sessions = <RevisionSessionModel>[].obs;
  final isLoading = true.obs;

  @override void onInit() {
    super.onInit();
    final args = Get.arguments as Map;
    topic = args['topic']; subject = args['subject'];
    _load();
  }

  Future<void> _load() async {
    try {
      isLoading.value = true;
      schedules.assignAll(await _repo.getSchedules(topicId: topic.id));
      sessions.assignAll(await _repo.getSessions(topicId: topic.id));
    } catch (_) {} finally { isLoading.value = false; }
  }
}
