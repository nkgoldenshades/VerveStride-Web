class MealItemWeb {
  final String id;
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final int sodium; // mg
  final double addedSugar; // g
  final String? imageUrl;
  final DateTime createdAt;

  MealItemWeb({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0.0,
    this.sodium = 0,
    this.addedSugar = 0.0,
    this.imageUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  MealItemWeb.fromMap(Map<String, dynamic> map)
      : id = map['id']?.toString() ?? '',
        name = map['name'] ?? 'Meal',
        calories = map['calories'] ?? 0,
        protein = (map['protein'] ?? 0).toDouble(),
        carbs = (map['carbs'] ?? 0).toDouble(),
        fat = (map['fat'] ?? 0).toDouble(),
        fiber = (map['fiber'] ?? 0).toDouble(),
        sodium = (map['sodium'] ?? 0).toInt(),
        addedSugar = (map['added_sugar'] ?? 0).toDouble(),
        imageUrl = map['image_url'],
        createdAt = DateTime.tryParse(map['created_at']) ?? DateTime.now();
}

class MealItemIsar {
  late String uuid;
  late String mealTypeKey;
  late String name;
  late int calories;
  late double protein;
  late double carbs;
  late double fat;
  late double fiber;
  late int sodium; // mg
  late double addedSugar; // g
  String? imageUrl;
  String? note;
  late DateTime createdAt;

  MealItemIsar();

  factory MealItemIsar.fromMap(Map<String, dynamic> map) {
    final m = MealItemIsar();
    final id = map['id']?.toString();
    m.uuid = (id == null || id.isEmpty)
        ? DateTime.now().microsecondsSinceEpoch.toString()
        : id;
    m.mealTypeKey =
        (map['meal_type'] ?? map['mealType'] ?? 'breakfast').toString();
    m.name = (map['name'] ?? 'Meal').toString();
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
