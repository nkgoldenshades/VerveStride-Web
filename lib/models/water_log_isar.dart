import 'package:isar/isar.dart';

part 'water_log_isar.g.dart';

@Collection()
class WaterLogIsar {
  Id id = Isar.autoIncrement;

  /// Format: yyyymmdd
  @Index(unique: true)
  late String dayKey;

  int amountMl = 0;

  DateTime updatedAt = DateTime.now();
}
