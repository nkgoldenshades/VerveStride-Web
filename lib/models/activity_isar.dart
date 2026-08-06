import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

part 'activity_isar.g.dart';

@Collection(ignore: {'all'})
class ActivityIsar {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uuid;

  ActivityIsar() {
    uuid = const Uuid().v4();
  }

  late String activityType;
  late DateTime activityDate;
  late double distanceKm;
  late int durationMinutes;
  late int caloriesBurned;
  late String routeData; // JSON-encoded list of lat/long points
  String? note;

  @Index()
  late DateTime createdAt;

  factory ActivityIsar.fromMap(Map<String, dynamic> map) {
    final a = ActivityIsar();
    a.uuid = map['id']?.toString() ?? const Uuid().v4();
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
