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
  SubjectDetailController({SubjectModel? initialSubject, TopicModel? parentTopic})
      : _initialSubject = initialSubject,
        _parentTopic = parentTopic;

  final SubjectModel? _initialSubject;
  /// Non-null → this screen lists **subtopics** of [parentTopic].
  TopicModel? _parentTopic;

  final _subjectRepo = Get.find<SubjectRepository>();
  final _topicRepo = Get.find<TopicRepository>();
  final _revRepo = Get.find<RevisionRepository>();
  late SubjectModel subject;
  TopicModel? get parentTopic => _parentTopic;
  bool get isSubtopicMode => _parentTopic != null;

  /// All topics for the subject (parents + children) — used for parent rings.
  final allSubjectTopics = <TopicModel>[].obs;
  final topics = <TopicModel>[].obs;
  final schedulesByTopic = <String, List<RevisionScheduleModel>>{}.obs;
  final isLoading = true.obs;
  final selectedFilter = 'firstRead'.obs;
  final topicSearch = ''.obs;
  /// Ticks when entering/leaving subtopic mode so Obx titles rebuild.
  final listVersion = 0.obs;
  StreamSubscription<List<TopicModel>>? _realtimeSub;
  StreamSubscription? _schedulesStreamSub;

  bool _ignoreNextRealtime = false;
  DateTime? _lastReorderAt;

  String get _orderKey => isSubtopicMode
      ? 'subtopic_order_${_parentTopic!.id}'
      : 'topic_order_${subject.id}';

  /// Case-insensitive name filter — works for any upper/lower mix.
  /// Parent topics WITH subtopics stay in First Read until ALL subtopics
  /// are fully done — adding subtopics does NOT hide the topic.
  List<TopicModel> get filteredTopics {
    final q = topicSearch.value.trim().toLowerCase();
    final byStatus = switch (selectedFilter.value) {
      'firstRead' => topics.where((t) {
          if (t.hasSubtopics) return !parentIsDoneFor(t);
          return !t.firstReadCompleted;
        }).toList(),
      'inRevision' => topics
          .where((t) =>
              !t.hasSubtopics &&
              t.firstReadCompleted &&
              t.totalRevisions < 6)
          .toList(),
      'completed' => topics.where((t) {
          if (t.hasSubtopics) return parentIsDoneFor(t);
          return t.firstReadCompleted && t.totalRevisions >= 6;
        }).toList(),
      _ => topics.toList(),
    };
    if (q.isEmpty) return byStatus;
    return byStatus.where((t) => t.name.toLowerCase().contains(q)).toList();
  }

  void setTopicSearch(String value) => topicSearch.value = value;

  void clearTopicSearch() => topicSearch.value = '';

  /// Children of [topicId] from the cached subject list.
  List<TopicModel> childrenOf(String topicId) => allSubjectTopics
      .where((t) => t.parentTopicId == topicId)
      .toList();

  /// Parent ring 0..1 — average of subtopic completion (regular process).
  double parentRingFor(TopicModel parent) {
    final kids = childrenOf(parent.id);
    if (kids.isEmpty) return 0;
    final sum = kids.fold<double>(0, (a, c) => a + c.subtopicCompletion);
    return sum / kids.length;
  }

  bool parentIsDoneFor(TopicModel parent) {
    final kids = childrenOf(parent.id);
    return kids.isNotEmpty && kids.every((k) => k.isFullyDone);
  }

  int get firstReadCount => topics.where((t) {
        if (t.hasSubtopics) return !parentIsDoneFor(t);
        return !t.firstReadCompleted;
      }).length;
  int get inRevisionCount => topics
      .where((t) =>
          !t.hasSubtopics && t.firstReadCompleted && t.totalRevisions < 6)
      .length;
  int get completedCount => topics.where((t) {
        if (t.hasSubtopics) return parentIsDoneFor(t);
        return t.firstReadCompleted && t.totalRevisions >= 6;
      }).length;

  String get screenTitle =>
      isSubtopicMode ? _parentTopic!.name : subject.name;

  /// Open the same screen as a subtopic list for [parent].
  void openSubtopics(TopicModel parent) {
    debugPrint('[SubjectDetail] openSubtopics ${parent.name} id=${parent.id}');
    _parentTopic = parent;
    topics.clear();
    schedulesByTopic.clear();
    selectedFilter.value = 'all';
    topicSearch.value = '';
    isLoading.value = true;
    listVersion.value++;
    unawaited(load());
  }

  /// Leave subtopic mode → back to subject topics.
  void exitSubtopics() {
    if (!isSubtopicMode) return;
    _parentTopic = null;
    topics.clear();
    schedulesByTopic.clear();
    selectedFilter.value = 'firstRead';
    topicSearch.value = '';
    isLoading.value = true;
    listVersion.value++;
    unawaited(load());
  }

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    SubjectModel? initSubject = _initialSubject;
    TopicModel? parent = _parentTopic;
    if (arg is SubjectModel) {
      initSubject ??= arg;
    } else if (arg is Map) {
      final sub = arg['subject'];
      final p = arg['parentTopic'];
      if (sub is SubjectModel) initSubject ??= sub;
      if (p is TopicModel) parent = p;
    }
    subject = initSubject ??
        (throw StateError('SubjectDetailController requires a subject'));
    _parentTopic = parent;
    load();
    _subscribeRealtime();
  }

  void switchSubject(SubjectModel next) {
    if (subject.id == next.id && _parentTopic == null) return;
    subject = next;
    _parentTopic = null;
    topics.clear();
    allSubjectTopics.clear();
    schedulesByTopic.clear();
    selectedFilter.value = 'firstRead';
    topicSearch.value = '';
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
