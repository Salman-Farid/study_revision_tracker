import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/notification_service.dart';
import '../../data/models/subject_model.dart';
import '../../data/models/topic_model.dart';
import '../../data/models/revision_schedule_model.dart';
import '../../data/repositories/subject_repository.dart';
import '../../data/repositories/topic_repository.dart';
import '../../data/repositories/revision_repository.dart';
import '../../data/services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../core/constants/size_constants.dart';
import '../../../gemini_3_flash_live_voice_chatbot/gemini_chatbot.dart';

part 'controller_parts/realtime.dart';
part 'controller_parts/topic_loading.dart';
part 'controller_parts/topic_actions.dart';
part 'controller_parts/topic_ui.dart';

class SubjectDetailController extends GetxController {
  SubjectDetailController({SubjectModel? initialSubject})
      : _initialSubject = initialSubject;

  final SubjectModel? _initialSubject;
  final _subjectRepo = Get.find<SubjectRepository>();
  final _topicRepo = Get.find<TopicRepository>();
  final _revRepo = Get.find<RevisionRepository>();
  late SubjectModel subject;
  final topics = <TopicModel>[].obs;
  final schedulesByTopic = <String, List<RevisionScheduleModel>>{}.obs;
  final isLoading = true.obs;
  final selectedFilter = 'firstRead'.obs;
  StreamSubscription<List<TopicModel>>? _realtimeSub;
  StreamSubscription? _schedulesStreamSub;

  /// Ignore one realtime overwrite right after a user drag-reorder.
  bool _ignoreNextRealtime = false;
  DateTime? _lastReorderAt;

  String get _orderKey => 'topic_order_${subject.id}';

  List<TopicModel> get filteredTopics {
    final list = switch (selectedFilter.value) {
      'firstRead' => topics.where((t) => !t.firstReadCompleted).toList(),
      'inRevision' =>
        topics.where((t) => t.firstReadCompleted && t.totalRevisions < 6).toList(),
      'completed' => topics.where((t) => t.totalRevisions >= 6).toList(),
      _ => topics.toList(),
    };
    return list;
  }

  int get firstReadCount => topics.where((t) => !t.firstReadCompleted).length;
  int get inRevisionCount =>
      topics.where((t) => t.firstReadCompleted && t.totalRevisions < 6).length;
  int get completedCount => topics.where((t) => t.totalRevisions >= 6).length;

  @override
  void onInit() {
    super.onInit();
    // Embedded desktop pane passes the subject directly; full route uses args.
    final arg = Get.arguments;
    subject = _initialSubject ??
        ((arg is SubjectModel) ? arg : null) ??
        (throw StateError('SubjectDetailController requires a subject'));
    load();
    _subscribeRealtime();
  }

  /// Desktop side-pane: swap the open subject without recreating the controller.
  void switchSubject(SubjectModel next) {
    if (subject.id == next.id) return;
    subject = next;
    topics.clear();
    schedulesByTopic.clear();
    selectedFilter.value = 'firstRead';
    isLoading.value = true;
    unawaited(load());
  }

  @override
  void onClose() {
    _realtimeSub?.cancel();
    _schedulesStreamSub?.cancel();
    super.onClose();
  }
}
