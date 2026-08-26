import 'package:get/get.dart';
import '../models/topic_model.dart';
import '../services/supabase_service.dart';

class TopicRepository {
  final _s = Get.find<SupabaseService>();
  Future<List<TopicModel>> getBySubject(String sid) => _s.fetchTopics(sid);
  Stream<List<TopicModel>> get stream => _s.topicsStream;
  void refresh() => _s.refreshTopics();
  Future<TopicModel> create({required String subjectId, required String name,
    String? notes, String? referenceAnswer, DateTime? firstReadDate}) =>
    _s.createTopic(subjectId: subjectId, name: name, notes: notes,
      referenceAnswer: referenceAnswer, firstReadDate: firstReadDate);
  Future<void> update(String id, Map<String, dynamic> u) => _s.updateTopic(id, u);
  Future<void> delete(String id, {String? subjectId}) => _s.deleteTopic(id, subjectId: subjectId);
  Future<void> markFirstReadCompleted(String id) => _s.markFirstReadCompleted(id);
  Future<Map<String, dynamic>> getTopicFullStatus(String id) => _s.getTopicFullStatus(id);
  Future<void> markNextRevisionCompleted(String id) => _s.markNextRevisionCompleted(id);
}
