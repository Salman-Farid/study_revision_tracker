import 'dart:convert';

class DailyRoutineItem {
  final String time;
  final String subject;
  final String topic;
  final String type;
  final int durationMinutes;
  final String? notes;

  const DailyRoutineItem({
    required this.time,
    required this.subject,
    required this.topic,
    required this.type,
    this.durationMinutes = 45,
    this.notes,
  });

  factory DailyRoutineItem.fromJson(Map<String, dynamic> j) {
    return DailyRoutineItem(
      time: j['time'] as String? ?? '',
      subject: j['subject'] as String? ?? '',
      topic: j['topic'] as String? ?? '',
      type: j['type'] as String? ?? 'study',
      durationMinutes: (j['duration_minutes'] as num?)?.toInt() ?? 45,
      notes: j['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'time': time,
    'subject': subject,
    'topic': topic,
    'type': type,
    'duration_minutes': durationMinutes,
    if (notes != null) 'notes': notes,
  };
}

class DailyRoutineModel {
  final String id;
  final String userId;
  final DateTime date;
  final List<DailyRoutineItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DailyRoutineModel({
    required this.id,
    required this.userId,
    required this.date,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DailyRoutineModel.fromJson(Map<String, dynamic> j) {
    final rawItems = j['items'];
    List<DailyRoutineItem> parsedItems;
    if (rawItems is String && rawItems.isNotEmpty) {
      final decoded = jsonDecode(rawItems) as List;
      parsedItems = decoded
          .map((e) => DailyRoutineItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (rawItems is List) {
      parsedItems = rawItems
          .map((e) => DailyRoutineItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      parsedItems = [];
    }

    return DailyRoutineModel(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      date: DateTime.parse(j['date'] as String),
      items: parsedItems,
      createdAt: DateTime.parse(j['created_at'] as String),
      updatedAt: DateTime.parse(j['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'date': date.toIso8601String().substring(0, 10),
    'items': items.map((e) => e.toJson()).toList(),
  };
}
