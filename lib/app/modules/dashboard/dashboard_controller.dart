import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../core/constants/responsive.dart';
import '../../data/models/daily_routine_model.dart';
import '../../data/models/revision_schedule_model.dart';
import '../../data/repositories/revision_repository.dart';
import '../../data/repositories/routine_repository.dart';
import '../../data/services/supabase_service.dart';
import '../../domain/routine/routine_timeline.dart';
import '../../modules/navigation/navigation_controller.dart';
import '../../widgets/widget_promo_dialog.dart';

/// Presentation wrapper around [RoutineTimelineItem] (same fields).
typedef DashboardRoutineItem = RoutineTimelineItem;

class DashboardController extends GetxController {
  final _repo = Get.find<RevisionRepository>();
  final _routineRepo = Get.find<RoutineRepository>();
  final _s = Get.find<SupabaseService>();

  final stats = <String, dynamic>{}.obs;
  final isLoading = true.obs;
  final pendingSchedules = <RevisionScheduleModel>[].obs;

  final streakDays = 0.obs;

  final todayRoutineItems = <DashboardRoutineItem>[].obs;
  final currentRoutine = Rxn<DashboardRoutineItem>();
  final upcomingRoutines = <DashboardRoutineItem>[].obs;
  final hasDailyRoutineToday = false.obs;

  StreamSubscription? _schedulesSub;
  StreamSubscription? _subjectsSub;
  StreamSubscription? _topicsSub;
  StreamSubscription? _dailySub;
  Timer? _debounce;
  Timer? _clock;
  List<RevisionScheduleModel> _allSchedules = [];
  List<DailyRoutineModel> _dailyRoutines = [];
  bool _loading = false;

  @override
  void onInit() {
    super.onInit();
    _ensureRealtime();
    _subscribeRealtime();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(load());
      _s.refreshDailyRoutines();
      if (Get.context != null && Responsive.useBottomNav) {
        WidgetPromoDialog.showIfNeeded(Get.context!);
      }
    });
    _clock = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _recomputeRoutineTimeline(),
    );
  }

  void _ensureRealtime() {
    try {
      _s.initRealtime();
    } catch (_) {}
  }

  void _subscribeRealtime() {
    _schedulesSub?.cancel();
    _subjectsSub?.cancel();
    _topicsSub?.cancel();
    _dailySub?.cancel();
    _schedulesSub = _s.schedulesStream.listen((list) {
      _allSchedules = list;
      _recomputeStreak();
      _scheduleSilentRefresh();
    });
    _subjectsSub = _s.subjectsStream.listen((_) => _scheduleSilentRefresh());
    _topicsSub = _s.topicsStream.listen((_) => _scheduleSilentRefresh());
    // Same realtime feed the Routine tab uses.
    _dailySub = _routineRepo.dailyRoutinesStream.listen((list) {
      _dailyRoutines = list;
      _recomputeRoutineTimeline();
    });
  }

  void _scheduleSilentRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(load(showLoading: false));
    });
  }

  @override
  void onClose() {
    _debounce?.cancel();
    _clock?.cancel();
    _schedulesSub?.cancel();
    _subjectsSub?.cancel();
    _topicsSub?.cancel();
    _dailySub?.cancel();
    super.onClose();
  }

  Future<void> load({bool showLoading = true}) async {
    if (_loading) return;
    _loading = true;
    try {
      if (_s.currentUser == null) return;
      if (showLoading) isLoading.value = true;

      final data = await _repo.getDashboardStats();
      stats.assignAll(data);

      final now = DateTime.now();
      final ts = DateTime(now.year, now.month, now.day);
      final te = ts.add(const Duration(days: 1));
      final overdue = await _repo.getSchedules(status: 'pending', toDate: ts);
      final today =
          await _repo.getSchedules(status: 'pending', fromDate: ts, toDate: te);
      pendingSchedules.assignAll([...overdue, ...today]);

      _allSchedules = await _repo.getSchedules();
      _recomputeStreak();
      _recomputeRoutineTimeline();
    } catch (e) {
      if (showLoading) {
        Get.snackbar('Error', 'Failed to load dashboard: $e',
            snackPosition: SnackPosition.BOTTOM);
      }
    } finally {
      isLoading.value = false;
      _loading = false;
    }
  }

  void _recomputeStreak() {
    final days = <DateTime>{};
    for (final s in _allSchedules) {
      if (s.status != 'completed') continue;
      days.add(DateTime(s.updatedAt.year, s.updatedAt.month, s.updatedAt.day));
    }
    streakDays.value = RoutineTimeline.activityStreak(days, DateTime.now());
  }

  void _recomputeRoutineTimeline() {
    final now = DateTime.now();
    final today = RoutineTimeline.startOfDay(now);
    final items = <RoutineTimelineItem>[];

    for (final dr in _dailyRoutines) {
      if (!RoutineTimeline.sameDay(dr.date, today)) continue;
      items.addAll(RoutineTimeline.buildDayItems(
        day: today,
        rawItems: dr.items
            .map((e) => {
                  'time': e.time,
                  'subject': e.subject,
                  'topic': e.topic,
                  'type': e.type,
                  'duration_minutes': e.durationMinutes,
                })
            .toList(),
      ));
    }

    items.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    todayRoutineItems.assignAll(items);
    hasDailyRoutineToday.value = items.isNotEmpty;
    currentRoutine.value = RoutineTimeline.activeOrNext(items, now);
    upcomingRoutines.assignAll(
      items.where((it) => it.start.isAfter(now)).toList(),
    );
  }

  void openRoutineTab() {
    try {
      NavigationController.to.goToRoutine();
    } catch (_) {
      Get.put(NavigationController(), permanent: true).goToRoutine();
    }
  }

  Future<void> startRevising() async {
    try {
      NavigationController.to.goToSubjects();
    } catch (_) {
      Get.put(NavigationController(), permanent: true).goToSubjects();
    }
  }
}
