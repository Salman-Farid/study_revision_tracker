import 'package:get/get.dart';
import '../models/revision_schedule_model.dart';
import '../models/revision_session_model.dart';
import '../services/supabase_service.dart';

class RevisionRepository {
  final _s = Get.find<SupabaseService>();
  Future<List<RevisionScheduleModel>> getSchedules({String? topicId,
    String? status, DateTime? fromDate, DateTime? toDate}) =>
    _s.fetchSchedules(topicId: topicId, status: status, fromDate: fromDate, toDate: toDate);
  Future<List<RevisionScheduleModel>> createSchedules({required String topicId,
    required String subjectId, required DateTime firstReadDate}) =>
    _s.createRevisionSchedules(topicId: topicId, subjectId: subjectId, firstReadDate: firstReadDate);
  Future<void> updateScheduleStatus(String id, String st) => _s.updateScheduleStatus(id, st);
  Future<RevisionSessionModel> startSession({required String topicId, String? scheduleId}) =>
    _s.createSession(topicId: topicId, scheduleId: scheduleId);
  Future<void> completeSession(String sid, {required String recallRating,
    required double confidence, required int durationSeconds, String? notes}) =>
    _s.completeSession(sid, recallRating: recallRating, confidence: confidence,
      durationSeconds: durationSeconds, notes: notes);
  Future<List<RevisionSessionModel>> getSessions({String? topicId,
    DateTime? fromDate, DateTime? toDate}) =>
    _s.fetchSessions(topicId: topicId, fromDate: fromDate, toDate: toDate);
  Future<Map<String, dynamic>> getDashboardStats() => _s.fetchDashboardStats();
}
