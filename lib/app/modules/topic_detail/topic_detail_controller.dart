import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/topic_model.dart';
import '../../data/models/subject_model.dart';
import '../../data/models/revision_schedule_model.dart';
import '../../data/repositories/revision_repository.dart';
import '../../../gemini_3_flash_live_voice_chatbot/gemini_chatbot.dart';

class TopicDetailController extends GetxController {
  final _repo = Get.find<RevisionRepository>();
  late TopicModel topic;
  late SubjectModel subject;
  final schedules = <RevisionScheduleModel>[].obs;
  final isLoading = true.obs;
  StreamSubscription<List<RevisionScheduleModel>>? _realtimeSub;

  @override void onInit() {
    super.onInit();
    final args = Get.arguments as Map;
    topic = args['topic']; subject = args['subject'];
    _load();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    _realtimeSub = _repo.schedulesStream.listen((all) {
      schedules.assignAll(all.where((s) => s.topicId == topic.id));
    });
  }

  @override
  void onClose() {
    _realtimeSub?.cancel();
    super.onClose();
  }

  Future<void> _load() async {
    try {
      isLoading.value = true;
      schedules.assignAll(await _repo.getSchedules(topicId: topic.id));
    } catch (e) { Get.snackbar('Error', 'Failed to load revision dates: $e', snackPosition: SnackPosition.BOTTOM); } finally { isLoading.value = false; }
  }

  void openVoiceAssistant() {
    final vc = Get.find<VoiceAssistantController>();
    vc.currentSubjectName = subject.name;
    vc.toolMode = 'subjects'; // isolate: no class/daily routine tools
    Get.bottomSheet(
      const VoiceAssistantSheet(),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Get.theme.scaffoldBackgroundColor,
    );
  }
}
