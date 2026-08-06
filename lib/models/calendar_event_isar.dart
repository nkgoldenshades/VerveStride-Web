import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

part 'calendar_event_isar.g.dart';

@Collection(ignore: {'all'})
class CalendarEventIsar {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uuid;

  CalendarEventIsar() {
    uuid = const Uuid().v4();
  }

  /// Format: yyyymmdd
  @Index()
  late String dayKey;

  late String title;
  String? note;

  @Index()
  late DateTime createdAt;

  factory CalendarEventIsar.fromMap(Map<String, dynamic> map) {
    final e = CalendarEventIsar();
    e.uuid = map['id']?.toString() ?? const Uuid().v4();
    e.dayKey = (map['day_key'] ?? '').toString();
    e.title = (map['title'] ?? '').toString();
    e.note = map['note']?.toString();
    e.createdAt = DateTime.tryParse(map['created_at']?.toString() ?? '') ??
        DateTime.now();
    return e;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': uuid,
      'day_key': dayKey,
      'title': title,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
