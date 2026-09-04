class ClassRoutineModel {
  final String id;
  final String userId;
  final String subjectName;
  final DateTime startTime;
  final int durationMinutes;
  final List<String> dates;
  final String? building;
  final String? floor;
  final String? room;
  final String? location;
  final bool recurring;
  final List<int> recurringDays;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClassRoutineModel({
    required this.id,
    required this.userId,
    required this.subjectName,
    required this.startTime,
    this.durationMinutes = 60,
    this.dates = const [],
    this.building,
    this.floor,
    this.room,
    this.location,
    this.recurring = false,
    this.recurringDays = const [],
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  String get locationText {
    // Prefer the single `location` field if set
    if (location != null && location!.isNotEmpty) return location!;
    // Fallback to building/floor/room
    final parts = <String>[];
    if (building != null && building!.isNotEmpty) parts.add(building!);
    if (floor != null && floor!.isNotEmpty) parts.add(floor!);
    if (room != null && room!.isNotEmpty) parts.add(room!);
    return parts.isEmpty ? '' : parts.join(', ');
  }

  String get timeText {
    var h = startTime.hour;
    final m = startTime.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    if (h == 0) h = 12;
    else if (h > 12) h -= 12;
    return '$h:$m $period';
  }

  String get endTimeText {
    final endMinutes = startTime.hour * 60 + startTime.minute + durationMinutes;
    var h = endMinutes ~/ 60;
    final m = endMinutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    if (h == 0) h = 12;
    else if (h > 12) h -= 12;
    return '$h:${m.toString().padLeft(2, '0')} $period';
  }

  String get durationText {
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  String get daysText {
    if (recurringDays.isEmpty) return '';
    const names = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return recurringDays.map((d) => names[d]).join(', ');
  }

  factory ClassRoutineModel.fromJson(Map<String, dynamic> j) {
    return ClassRoutineModel(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      subjectName: j['subject_name'] as String,
      startTime: DateTime.parse(j['start_time'] as String),
      durationMinutes: (j['duration_minutes'] as num?)?.toInt() ?? 60,
      dates: (j['dates'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      building: j['building'] as String?,
      floor: j['floor'] as String?,
      room: j['room'] as String?,
      location: j['location'] as String?,
      recurring: j['recurring'] as bool? ?? false,
      recurringDays: (j['recurring_days'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ?? [],
      notes: j['notes'] as String?,
      createdAt: DateTime.parse(j['created_at'] as String),
      updatedAt: DateTime.parse(j['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'subject_name': subjectName,
    'start_time': startTime.toIso8601String(),
    'duration_minutes': durationMinutes,
    'dates': dates,
    'building': building,
    'floor': floor,
    'room': room,
    'location': location,
    'recurring': recurring,
    'recurring_days': recurringDays,
    'notes': notes,
  };
}
