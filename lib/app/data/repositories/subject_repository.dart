import 'package:get/get.dart';
import '../models/subject_model.dart';
import '../services/supabase_service.dart';

class SubjectRepository {
  final _s = Get.find<SupabaseService>();
  Future<List<SubjectModel>> getAll() => _s.fetchSubjects();
  Future<SubjectModel> create({required String name, String? description,
    String? colorHex, int? iconCodePoint}) =>
    _s.createSubject(name: name, description: description, colorHex: colorHex, iconCodePoint: iconCodePoint);
  Future<void> update(String id, Map<String, dynamic> u) => _s.updateSubject(id, u);
  Future<void> delete(String id) => _s.deleteSubject(id);
}
