import 'dart:async';

import 'package:get/get.dart';
import '../../data/models/revision_schedule_model.dart';
import '../../data/repositories/revision_repository.dart';
import '../../data/services/supabase_service.dart';

class TodayController extends GetxController {
  final _repo = Get.find<RevisionRepository>();
  final _s = Get.find<SupabaseService>();

  /// 0 = Ongoing Today, 1 = Missed, 2 = Upcoming
  final selectedTab = 0.obs;

  final overdue = <RevisionScheduleModel>[].obs;
  final today = <RevisionScheduleModel>[].obs;
  final upcoming = <RevisionScheduleModel>[].obs;
  final isLoading = true.obs;

  StreamSubscription? _schedulesSub;
  Timer? _debounce;
  bool _loading = false;

  @override
  void onInit() {
    super.onInit();
    try {
      _s.initRealtime();
    } catch (_) {}
    _subscribeRealtime();
    unawaited(load());
  }

  void _subscribeRealtime() {
    _schedulesSub?.cancel();
    _schedulesSub = _s.schedulesStream.listen((_) => _scheduleSilentRefresh());
  }

  void _scheduleSilentRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(load(showLoading: false));
    });
  }

  @override
  void onClose() {
    _debounce?.cancel();
    _schedulesSub?.cancel();
    super.onClose();
  }

  Future<void> load({bool showLoading = true}) async {
    if (_loading) return;
    _loading = true;
    try {
      if (showLoading) isLoading.value = true;
      final now = DateTime.now();
      final ts = DateTime(now.year, now.month, now.day);
      final te = ts.add(const Duration(days: 1));
      final results = await Future.wait([
        _repo.getSchedules(status: 'pending', toDate: ts),
        _repo.getSchedules(status: 'pending', fromDate: ts, toDate: te),
        _repo.getSchedules(status: 'pending', fromDate: te),
      ]);
      overdue.assignAll(results[0]);
      today.assignAll(results[1]);
      upcoming.assignAll(results[2]);
    } catch (e) {
      if (showLoading) {
        Get.snackbar('Error', "Failed to load today's revisions: $e",
            snackPosition: SnackPosition.BOTTOM);
      }
    } finally {
      isLoading.value = false;
      _loading = false;
    }
  }

  Future<void> markDone(String id) async {
    await _repo.updateScheduleStatus(id, 'completed');
    overdue.removeWhere((s) => s.id == id);
    today.removeWhere((s) => s.id == id);
    upcoming.removeWhere((s) => s.id == id);
    // Push a stream event so Dashboard / widgets also update.
    try {
      _s.refreshSchedules();
    } catch (_) {}
  }

  Future<void> markMissed(String id) async {
    await _repo.updateScheduleStatus(id, 'missed');
    overdue.removeWhere((s) => s.id == id);
    today.removeWhere((s) => s.id == id);
    upcoming.removeWhere((s) => s.id == id);
    try {
      _s.refreshSchedules();
    } catch (_) {}
  }
}
