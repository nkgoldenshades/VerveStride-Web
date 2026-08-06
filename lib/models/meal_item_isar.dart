import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

part 'meal_item_isar.g.dart';

@Collection(ignore: {'all'})
class MealItemIsar {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String uuid;

  MealItemIsar() {
    uuid = const Uuid().v4();
  }

  late String name;
  @Index()
  String mealTypeKey = 'breakfast';
  late int calories;
  late double protein;
  late double carbs;
  late double fat;
  late double fiber;
  late int sodium; // mg
  late double addedSugar; // g
  String? imageUrl;
  String? note;

  @Index()
  late DateTime createdAt;

  factory MealItemIsar.fromMap(Map<String, dynamic> map) {
    final m = MealItemIsar();
    m.uuid = map['id']?.toString() ?? const Uuid().v4();
    m.name = (map['name'] ?? 'Meal').toString();
    m.mealTypeKey = (map['meal_type'] ?? map['mealType'] ?? 'breakfast').toString();
    m.calories = (map['calories'] as num?)?.toInt() ?? 0;
    m.protein = (map['protein'] as num?)?.toDouble() ?? 0;
    m.carbs = (map['carbs'] as num?)?.toDouble() ?? 0;
    m.fat = (map['fat'] as num?)?.toDouble() ?? 0;
    m.fiber = (map['fiber'] as num?)?.toDouble() ?? 0;
    m.sodium = (map['sodium'] as num?)?.toInt() ?? 0;
    m.addedSugar = (map['added_sugar'] as num?)?.toDouble() ?? 0;
    m.imageUrl = map['image_url']?.toString();
    m.note = map['note']?.toString();
    m.createdAt =
        DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now();
    return m;
  }
}
