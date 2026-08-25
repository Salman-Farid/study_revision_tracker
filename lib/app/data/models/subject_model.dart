import 'dart:ui';

class SubjectModel {
  final String id, userId, name, colorHex;
  final String? description, imageUrl;
  final int iconCodePoint, totalTopics, completedTopics;
  final bool isArchived;
  final DateTime createdAt, updatedAt;

  SubjectModel({
    required this.id, required this.userId, required this.name,
    this.description, this.imageUrl, required this.colorHex, required this.iconCodePoint,
    this.totalTopics = 0, this.completedTopics = 0, this.isArchived = false,
    required this.createdAt, required this.updatedAt,
  });

  factory SubjectModel.fromJson(Map<String, dynamic> j) => SubjectModel(
    id: j['id'], userId: j['user_id'], name: j['name'],
    description: j['description'] as String?,
    imageUrl: j['image_url'] as String?,
    colorHex: j['color_hex'] ?? '#6C63FF',
    iconCodePoint: j['icon_code_point'] ?? 0xe8a1,
    totalTopics: j['total_topics'] ?? 0, completedTopics: j['completed_topics'] ?? 0,
    isArchived: j['is_archived'] ?? false,
    createdAt: DateTime.parse(j['created_at']),
    updatedAt: DateTime.parse(j['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'user_id': userId, 'name': name, 'description': description,
    'image_url': imageUrl,
    'color_hex': colorHex, 'icon_code_point': iconCodePoint,
    'total_topics': totalTopics, 'completed_topics': completedTopics,
    'is_archived': isArchived, 'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  SubjectModel copyWith({String? name, String? description, String? imageUrl, String? colorHex,
    int? iconCodePoint, int? totalTopics, int? completedTopics, bool? isArchived}) {
    return SubjectModel(id: id, userId: userId,
      name: name ?? this.name, description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      colorHex: colorHex ?? this.colorHex, iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      totalTopics: totalTopics ?? this.totalTopics, completedTopics: completedTopics ?? this.completedTopics,
      isArchived: isArchived ?? this.isArchived, createdAt: createdAt, updatedAt: DateTime.now());
  }

  double get progressPercent => totalTopics == 0 ? 0 : completedTopics / totalTopics;
  Color get color => Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
}
