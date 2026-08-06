import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import 'package:vervestride/models/meal_models.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../services/local_storage_service.dart';

class MealsListPage extends StatefulWidget {
  final DateTime selectedDate;

  const MealsListPage({
    super.key,
    required this.selectedDate,
  });

  @override
  State<MealsListPage> createState() => _MealsListPageState();
}

class _MealsListPageState extends State<MealsListPage> {
  final LocalStorageService _storage = LocalStorageService.instance;
  List<MealItem> _meals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMeals();
  }

  Future<void> _loadMeals() async {
    try {
      final meals = await _storage.getMealsForDate(widget.selectedDate);
      if (!mounted) return;
      setState(() {
        _meals = meals
            .map(
              (m) => MealItem(
                id: m.uuid,
                name: m.name,
                mealType: _parseMealType(m.mealTypeKey),
                calories: m.calories,
                protein: m.protein,
                carbs: m.carbs,
                fat: m.fat,
                fiber: m.fiber,
                sodium: m.sodium,
                addedSugar: m.addedSugar,
                imageUrl: m.imageUrl,
              ),
            )
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  MealType _parseMealType(String key) {
    switch (key.toLowerCase()) {
      case 'breakfast':
        return MealType.breakfast;
      case 'lunch':
        return MealType.lunch;
      case 'snack':
        return MealType.snack;
      case 'dinner':
        return MealType.dinner;
      default:
        return MealType.breakfast;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCalories =
        _meals.fold<int>(0, (sum, meal) => sum + meal.calories);
    final dateStr = DateFormat('EEEE, MMM d').format(widget.selectedDate);

    return GradientScaffold(
      appBar: AppBar(
        title: Text(
          dateStr,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_meals.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Total: ',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '$totalCalories kcal',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: _meals.isEmpty
                      ? const Center(
                          child: Text(
                            'No meals for this day',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _meals.length,
                          itemBuilder: (context, index) {
                            final meal = _meals[index];
                            return _MealListItem(meal: meal);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _MealListItem extends StatelessWidget {
  final MealItem meal;

  const _MealListItem({required this.meal});

  String _getMealTypeDisplay(MealType? type) {
    if (type == null) return 'Meal';
    switch (type) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.snack:
        return 'Snack';
      case MealType.dinner:
        return 'Dinner';
    }
  }

  IconData _getMealTypeIcon(MealType? type) {
    if (type == null) return Icons.restaurant;
    switch (type) {
      case MealType.breakfast:
        return Icons.free_breakfast;
      case MealType.lunch:
        return Icons.lunch_dining;
      case MealType.snack:
        return Icons.cookie;
      case MealType.dinner:
        return Icons.dinner_dining;
    }
  }

  Color _getMealTypeColor(MealType? type) {
    if (type == null) return AppColors.accent;
    switch (type) {
      case MealType.breakfast:
        return const Color(0xFFFFB74D); // Orange
      case MealType.lunch:
        return const Color(0xFF4FC3F7); // Light Blue
      case MealType.snack:
        return const Color(0xFFBA68C8); // Purple
      case MealType.dinner:
        return const Color(0xFF81C784); // Green
    }
  }

  @override
  Widget build(BuildContext context) {
    final mealTypeColor = _getMealTypeColor(meal.mealType);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          // Meal type icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: mealTypeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getMealTypeIcon(meal.mealType),
              color: mealTypeColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meal type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: mealTypeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getMealTypeDisplay(meal.mealType).toUpperCase(),
                    style: TextStyle(
                      color: mealTypeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Meal name
                Text(
                  meal.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                // Calories
                Text(
                  '${meal.calories} calories',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
