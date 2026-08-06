class ActivityWeb {
  final String id;
  final String activityType;
  final DateTime activityDate;
  final double distanceKm;
  final int durationMinutes;
  final int caloriesBurned;
  final String routeData; // JSON-encoded list of lat/long points
  final DateTime createdAt;

  ActivityWeb({
    required this.id,
    required this.activityType,
    required this.activityDate,
    required this.distanceKm,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.routeData,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  ActivityWeb.fromMap(Map<String, dynamic> map)
      : id = map['id']?.toString() ?? '',
        activityType = map['activity_type'] ?? 'unknown',
        activityDate = DateTime.tryParse(map['activity_date']) ?? DateTime.now(),
        distanceKm = (map['distance_km'] ?? 0).toDouble(),
        durationMinutes = map['duration_minutes'] ?? 0,
        caloriesBurned = map['calories_burned'] ?? 0,
        routeData = map['route_data'] ?? '[]',
        createdAt = DateTime.tryParse(map['created_at']) ?? DateTime.now();
}

class ActivityIsar {
  late String uuid;
  late String activityType;
  late DateTime activityDate;
  late double distanceKm;
  late int durationMinutes;
  late int caloriesBurned;
  late String routeData; // JSON-encoded list of lat/long points
  String? note;
  late DateTime createdAt;

  ActivityIsar();

  factory ActivityIsar.fromMap(Map<String, dynamic> map) {
    final a = ActivityIsar();
    final id = map['id']?.toString();
    a.uuid = (id == null || id.isEmpty)
        ? DateTime.now().microsecondsSinceEpoch.toString()
        : id;
    a.activityType = (map['activity_type'] ?? 'unknown').toString();
    a.activityDate =
        DateTime.tryParse(map['activity_date']?.toString() ?? '') ?? DateTime.now();
    a.distanceKm = (map['distance_km'] as num?)?.toDouble() ?? 0;
    a.durationMinutes = (map['duration_minutes'] as num?)?.toInt() ?? 0;
    a.caloriesBurned = (map['calories_burned'] as num?)?.toInt() ?? 0;
    a.routeData = (map['route_data'] ?? '[]').toString();
    a.note = map['note']?.toString();
    a.createdAt =
        DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now();
    return a;
  }
}
