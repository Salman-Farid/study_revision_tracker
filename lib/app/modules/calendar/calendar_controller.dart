import 'dart:async';

import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../data/models/revision_schedule_model.dart';
import '../../data/repositories/revision_repository.dart';
import '../../data/services/supabase_service.dart';

class CalendarController extends GetxController {
  final _repo = Get.find<RevisionRepository>();
  final _s = Get.find<SupabaseService>();

  final calendarFormat = CalendarFormat.month.obs;
  final focusedDay = DateTime.now().obs;
  final selectedDay = DateTime.now().obs;
  final events = <DateTime, List<RevisionScheduleModel>>{}.obs;
  final isLoading = true.obs;
  /// Bumped on every reload so TableCalendar's eventLoader rebuilds.
  final eventsVersion = 0.obs;

  StreamSubscription? _schedulesSub;
  Timer? _debounce;
  bool _loading = false;

  @override
  void onInit() {
    super.onInit();
    try {
      _s.initRealtime();
    } catch (_) {}
    _subscribe();
    unawaited(load());
  }

  void _subscribe() {
    _schedulesSub?.cancel();
    _schedulesSub = _s.schedulesStream.listen((_) {
      // Near-instant refresh — no long debounce, no spinner.
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 150), () {
        unawaited(load(showLoading: false));
      });
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
      final ss = await _repo.getSchedules(
        fromDate: DateTime(now.year, now.month - 2, 1),
        toDate: DateTime(now.year, now.month + 3, 0),
      );
      final map = <DateTime, List<RevisionScheduleModel>>{};
      for (final s in ss) {
        final k = DateTime(
            s.scheduledDate.year, s.scheduledDate.month, s.scheduledDate.day);
        map.putIfAbsent(k, () => []).add(s);
      }
      // Replace the map so Obx / TableCalendar see a new instance.
      events.value = map;
      eventsVersion.value = eventsVersion.value + 1;
    } catch (e) {
      if (showLoading) {
        Get.snackbar('Error', 'Failed to load calendar: $e',
            snackPosition: SnackPosition.BOTTOM);
      }
    } finally {
      isLoading.value = false;
      _loading = false;
    }
  }

  List<RevisionScheduleModel> getEventsForDay(DateTime d) {
    // Touch version so eventLoader runs again after a reload.
    // ignore: unnecessary_statements
    eventsVersion.value;
    return events[DateTime(d.year, d.month, d.day)] ?? const [];
  }

  void onDaySelected(DateTime selected, DateTime focused) {
    selectedDay.value = selected;
    focusedDay.value = focused;
  }

  void onFormatChanged(CalendarFormat format) {
    calendarFormat.value = format;
  }
}
