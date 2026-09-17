import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/responsive.dart';
import '../../data/models/subject_model.dart';
import '../../data/models/topic_model.dart';
import '../../data/repositories/subject_repository.dart';
import '../../data/repositories/topic_repository.dart';
import '../../data/services/supabase_service.dart';
import '../../data/services/gemini_service.dart';
import '../../core/constants/size_constants.dart';
import '../../theme/app_theme.dart';
import '../../../gemini_3_flash_live_voice_chatbot/gemini_chatbot.dart';
import '../../../gemini_3_flash_live_voice_chatbot/features/voice_assistant/study_assistant_dialogue.dart';

part 'controller_parts/realtime_progress.dart';
part 'controller_parts/subject_actions.dart';
part 'controller_parts/voice_chat.dart';
part 'controller_parts/subject_ui.dart';

class SubjectsController extends GetxController {
  final _repo = Get.find<SubjectRepository>();
  final _topicRepo = Get.find<TopicRepository>();
  final _gemini = GeminiService();
  final _stt = SpeechToText();
  final subjects = <SubjectModel>[].obs;
  final isLoading = true.obs;
  final isListening = false.obs;
  final chatMessages = <Map<String, dynamic>>[].obs;
  final showChat = false.obs;
  final isDragging = false.obs;
  /// Desktop/tablet side-by-side: subject shown in the detail pane.
  final selectedSubjectId = RxnString();
  StreamSubscription<List<SubjectModel>>? _realtimeSub;
  StreamSubscription<List<TopicModel>>? _topicsSub;

  // Real per-subject progress: subjectId → {topics, revisionsDone, revisionsPlanned}
  final topicsProgress = <String, Map<String, int>>{}.obs;
  // Topic names per subject: subjectId → [topicName1, topicName2, ...]
  final topicNames = <String, List<String>>{}.obs;

  // Global key for Study Assistant button to get its position
  final studyAssistantButtonKey = GlobalKey();

  SubjectModel? get selectedSubject {
    final id = selectedSubjectId.value;
    if (id == null) return null;
    for (final s in subjects) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Phone → full-screen route. Split layout → select for the side pane.
  void openSubject(SubjectModel subject) {
    if (Responsive.useSplitLayout) {
      selectedSubjectId.value = subject.id;
      return;
    }
    Get.toNamed('/subject/${subject.id}', arguments: subject);
  }

  @override void onInit() { super.onInit(); load(); _subscribeRealtime(); }

  @override
  void onClose() {
    _realtimeSub?.cancel();
    _topicsSub?.cancel();
    super.onClose();
  }
}
