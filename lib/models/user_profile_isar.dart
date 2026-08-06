import 'package:isar/isar.dart';
import 'dart:convert';
part 'user_profile_isar.g.dart';

@Collection()
class UserProfileIsar {
  UserProfileIsar({
    required this.uuid,
    required this.name,
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.activityLevel,
    required this.goal,
    required this.targetWeightKg,
    this.goalStartDate,
    this.goalEndDate,
    this.goalsJson,
  });

  Id id = Isar.autoIncrement;

  late String uuid;
  late String name;
  late int age;
  late String gender;
  late double heightCm;
  late double weightKg;
  late int activityLevel;
  late String goal;
  late double targetWeightKg;
  DateTime? goalStartDate;
  DateTime? goalEndDate;
  String? goalsJson; // JSON-serialized List<UserGoal>

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'name': name,
      'age': age,
      'gender': gender,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'activityLevel': activityLevel,
      'goal': goal,
      'targetWeightKg': targetWeightKg,
      'goalStartDate': goalStartDate?.toIso8601String(),
      'goalEndDate': goalEndDate?.toIso8601String(),
      'goals': goalsJson != null ? jsonDecode(goalsJson!) : [],
    };
  }
}
