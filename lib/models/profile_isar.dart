import 'package:isar/isar.dart';

part 'profile_isar.g.dart';

@Collection()
class Profile {
  Id id = Isar.autoIncrement;

  String? name;
  double? heightCm;
  double? weightKg;
  int? age;
  String? gender; // 'male', 'female', 'other'
  String? profilePhotoPath; // Path to profile photo

  DateTime? createdAt;
  DateTime? updatedAt;

  Profile() {
    createdAt = DateTime.now();
    updatedAt = DateTime.now();
  }
}

