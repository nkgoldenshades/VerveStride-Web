enum MealType { breakfast, lunch, snack, dinner }

class MealItem {
  final String? id;
  final MealType? mealType;
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final int sodium; // mg
  final double addedSugar; // g
  final String? imageUrl;

  MealItem({
    this.id,
    this.mealType,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0.0,
    this.sodium = 0,
    this.addedSugar = 0.0,
    this.imageUrl,
  });
}
