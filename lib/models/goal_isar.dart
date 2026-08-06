import 'package:isar/isar.dart';

part 'goal_isar.g.dart';

@Collection()
class Goal {
  Id id = Isar.autoIncrement;

  String type = 'balanced';
  late DateTime fromDate;
  late DateTime toDate;
  int dailyTarget = 2000;

  DateTime? createdAt;

  Goal() {
    createdAt = DateTime.now();
    fromDate = DateTime.now();
    toDate = DateTime.now().add(const Duration(days: 30));
  }

  bool isActiveForDate(DateTime date) {
    return (date.isAfter(fromDate.subtract(const Duration(days: 1))) ||
            date.isAtSameMomentAs(fromDate)) &&
        (date.isBefore(toDate.add(const Duration(days: 1))) ||
            date.isAtSameMomentAs(toDate));
  }
}
