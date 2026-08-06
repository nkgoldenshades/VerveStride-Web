import 'package:uuid/uuid.dart';

class CalendarEventIsar {
  late String uuid;

  /// Format: yyyymmdd
  late String dayKey;

  late String title;
  String? note;

  late DateTime createdAt;

  CalendarEventIsar() {
    uuid = const Uuid().v4();
  }

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
