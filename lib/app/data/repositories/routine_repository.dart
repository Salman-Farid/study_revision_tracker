import 'package:get/get.dart';
import '../models/class_routine_model.dart';
import '../models/daily_routine_model.dart';
import '../services/supabase_service.dart';

class RoutineRepository {
  final _s = Get.find<SupabaseService>();

  // ── Realtime streams ──
  Stream<List<ClassRoutineModel>> get classRoutinesStream => _s.classRoutinesStream;
  Stream<List<DailyRoutineModel>> get dailyRoutinesStream => _s.dailyRoutinesStream;

  // ── Class routines ──

  Future<List<ClassRoutineModel>> getClassRoutines({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final rows = await _s.fetchClassRoutines(fromDate: fromDate, toDate: toDate);
    return rows.map((j) => ClassRoutineModel.fromJson(j)).toList();
  }

  Future<ClassRoutineModel> createClassRoutine({
    required String subjectName,
    required DateTime startTime,
    required int durationMinutes,
    required List<String> dates,
    String? location,
    bool recurring = false,
    List<int> recurringDays = const [],
    String? notes,
  }) async {
    final row = await _s.createClassRoutine(
      subjectName: subjectName,
      startTime: startTime,
      durationMinutes: durationMinutes,
      dates: dates,
      location: location,
      recurring: recurring,
      recurringDays: recurringDays,
      notes: notes,
    );
    return ClassRoutineModel.fromJson(row);
  }

  Future<void> deleteClassRoutine(String id) => _s.deleteClassRoutine(id);

  // ── Daily routines ──

  Future<List<DailyRoutineModel>> getDailyRoutines({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final rows = await _s.fetchDailyRoutines(fromDate: fromDate, toDate: toDate);
    return rows.map((j) => DailyRoutineModel.fromJson(j)).toList();
  }

  Future<DailyRoutineModel> createDailyRoutine({
    required DateTime date,
    required List<DailyRoutineItem> items,
  }) async {
    final row = await _s.createDailyRoutine(
      date: date,
      items: items.map((e) => e.toJson()).toList(),
    );
    return DailyRoutineModel.fromJson(row);
  }

  Future<void> deleteDailyRoutine(String id) => _s.deleteDailyRoutine(id);

  Future<int> deleteDailyRoutinesByDate(DateTime date) => _s.deleteDailyRoutinesByDate(date);
}
