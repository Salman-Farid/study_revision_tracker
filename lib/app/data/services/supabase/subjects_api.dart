part of '../supabase_service.dart';

/// Subjects CRUD for [SupabaseService].
extension SupabaseSubjectsApi on SupabaseService {
  Future<List<SubjectModel>> fetchSubjects() async {
    final r = await client.from('subjects').select()
        .eq('user_id', userId).eq('is_archived', false)
        .order('created_at', ascending: false);
    return (r as List).map((j) => SubjectModel.fromJson(j)).toList();
  }

  Future<SubjectModel> createSubject({
    required String name,
    String? description,
    String? imageUrl,
    String? colorHex,
    int? iconCodePoint,
  }) async {
    final data = {
      'id': _uuid.v4(),
      'user_id': userId,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'color_hex': colorHex ?? '#6C63FF',
      'icon_code_point': iconCodePoint ?? 0xe8a1,
    };
    final r = await client.from('subjects').insert(data).select().single();
    return SubjectModel.fromJson(r);
  }

  Future<void> updateSubject(String id, Map<String, dynamic> u) =>
      client.from('subjects').update(u).eq('id', id);

  Future<void> deleteSubject(String id) =>
      client.from('subjects').delete().eq('id', id);
}
