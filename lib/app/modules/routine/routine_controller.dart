import 'dart:async';

import 'package:get/get.dart';

import '../../../gemini_3_flash_live_voice_chatbot/core/websocket/gemini_socket.dart'
    as ws;
import '../../../gemini_3_flash_live_voice_chatbot/features/voice_assistant/voice_assistant_controller.dart';
import '../../data/models/class_routine_model.dart';
import '../../data/models/daily_routine_model.dart';
import '../../data/repositories/routine_repository.dart';
import '../../domain/routine/routine_time_utils.dart';

enum RoutineMode { daily, class$ }

/// Simple display model for both class and daily routine items on the daily tab.
class RoutineDisplayItem {
  final String subjectName;
  final String timeText;
  final String endTimeText;
  final String sortKey; // 24h format for correct sorting
  final String locationText;
  final String durationText;
  final String type; // 'class', 'study', 'first_read', 'revision', 'review', 'break', 'meal', 'nap', 'recall', 'question_practice'
  final String? topicName;
  final String? notes;

  const RoutineDisplayItem({
    required this.subjectName,
    required this.timeText,
    required this.endTimeText,
    required this.sortKey,
    required this.locationText,
    required this.durationText,
    required this.type,
    this.topicName,
    this.notes,
  });

  /// Human-readable title based on type
  String get displayTitle {
    switch (type) {
      case 'break':
        return 'Break';
      case 'meal':
        return subjectName.isNotEmpty ? subjectName : 'Meal';
      case 'nap':
        return 'Power Nap';
      case 'recall':
        return 'Active Recall';
      case 'question_practice':
        return 'Question Practice';
      case 'review':
        return 'Quick Review';
      case 'class':
        return subjectName;
      case 'study':
      case 'first_read':
      case 'revision':
      default:
        return subjectName;
    }
  }

  /// Motivational tagline for non-study blocks
  String? get tagline {
    switch (type) {
      case 'break':
        final breakLines = [
          'Take a deep breath',
          'Stretch your body',
          'Hydrate & recharge',
          'Close your eyes for a moment',
          'Stay humble, keep going',
          '放松一下 — you earned it',
        ];
        // Deterministic pick based on sortKey hash
        return breakLines[sortKey.hashCode.abs() % breakLines.length];
      case 'nap':
        return 'Power nap for memory consolidation';
      case 'meal':
        return 'Fuel your brain';
      case 'recall':
        final recallLines = [
          'Test yourself without looking',
          'Recall what you just studied',
          'Active recall strengthens memory',
          'Challenge your brain',
        ];
        return recallLines[sortKey.hashCode.abs() % recallLines.length];
      case 'question_practice':
        return 'Solve problems, don\'t just read';
      case 'review':
        return 'Quick revision before moving on';
      default:
        return topicName;
    }
  }

  /// Timeline text: "9:00 AM - 9:50 AM"
  String get timelineText => '$timeText – $endTimeText';
}

class RoutineController extends GetxController {
  final VoiceAssistantController voice = Get.find<VoiceAssistantController>();
  final RoutineRepository _routineRepo = Get.find<RoutineRepository>();

  final Rx<RoutineMode> mode = RoutineMode.daily.obs;
  final RxList<ClassRoutineModel> classRoutines = <ClassRoutineModel>[].obs;
  final RxList<DailyRoutineModel> dailyRoutines = <DailyRoutineModel>[].obs;
  final RxBool isLoading = true.obs;

  StreamSubscription? _classSub;
  StreamSubscription? _dailySub;

  @override
  void onInit() {
    super.onInit();
    // Sync initial mode to voice assistant
    voice.currentRoutineMode = mode.value == RoutineMode.daily ? 'daily' : 'class';
    _classSub = _routineRepo.classRoutinesStream.listen((list) {
      classRoutines.assignAll(list);
      isLoading.value = false;
    });
    _dailySub = _routineRepo.dailyRoutinesStream.listen((list) {
      dailyRoutines.assignAll(list);
      isLoading.value = false;
    });
    // Trigger initial load
    Future.microtask(() {
      voice.refreshClassRoutines();
      voice.refreshDailyRoutines();
    });
  }

  @override
  void onClose() {
    _classSub?.cancel();
    _dailySub?.cancel();
    super.onClose();
  }

  void switchMode(RoutineMode next) {
    mode.value = next;
    voice.currentRoutineMode = next == RoutineMode.daily ? 'daily' : 'class';
  }

  /// Daily tab list = assistant-created daily routine only.
  /// Class routines stay on the Class tab so they aren't duplicated here.
  List<RoutineDisplayItem> get todayItems {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final items = <RoutineDisplayItem>[];

    for (final dr in dailyRoutines) {
      if (isSameCalendarDay(dr.date, today)) {
        for (final item in dr.items) {
          final parts = item.time.split(':');
          final sh = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
          final sm = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
          final startDt = DateTime(today.year, today.month, today.day, sh, sm);

          items.add(RoutineDisplayItem(
            subjectName: item.subject,
            timeText: formatTime12Hour(item.time),
            endTimeText: formatEndTimeText(startDt, item.durationMinutes),
            sortKey: item.time,
            locationText: '',
            durationText: '${item.durationMinutes}m',
            type: item.type,
            topicName: item.topic,
            notes: item.notes,
          ));
        }
      }
    }

    items.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return items;
  }

  void openAssistant() {
    voice.currentRoutineMode = mode.value == RoutineMode.daily ? 'daily' : 'class';
    voice.toolMode = 'routine';
    voice.showDialogue.value = true;
    // Restart session so filtered tools take effect
    if (voice.connectionState.value != ws.ConnectionState.disconnected) {
      try { voice.stopSession(); } catch (_) {}
    }
    try { voice.startSession(); } catch (_) {}
  }

  void toggleMic() {
    openAssistant();
    voice.toggleListening();
  }
}
