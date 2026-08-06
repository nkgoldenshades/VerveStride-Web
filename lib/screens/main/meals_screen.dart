import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openfoodfacts/openfoodfacts.dart' as off;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/app_theme.dart';
import 'package:vervestride/models/meal_models.dart';
import '../../services/local_storage_service.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/section_card.dart';
import '../../services/streak_service.dart';
import '../../services/nutrition_service.dart';
import '../../services/openfoodfacts_service.dart';
import '../../services/excel_service.dart';
import '../../services/firebase_ai_service.dart';
import 'home_screen.dart';
import '../../widgets/shooting_stars_background.dart';
import '../../widgets/ad_banner_widget.dart';

class MealsScreen extends StatefulWidget {
  final VoidCallback? onRefresh;
  const MealsScreen({super.key, this.onRefresh});

  @override
  State<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends State<MealsScreen> {
  final ImagePicker _picker = ImagePicker();
  final LocalStorageService _storage = LocalStorageService.instance;
  MealType _selectedMealType = MealType.breakfast;
  XFile? _selectedImage;
  bool _isSavingMeal = false;
  bool _isLoadingMeals = false;
  final List<MealItem> _todayMeals = [];

  bool _isOnline = true;
  bool _isSearchingNutrition = false;
  String? _nutritionError;

  bool _showAdvancedNutrition = false;

  static const String _settingsKeyShowAdvancedNutrition =
      'ui_show_advanced_nutrition';

  String? _editingMealId;

  final TextEditingController _mealNameCtrl = TextEditingController();
  final TextEditingController _mealCaloriesCtrl = TextEditingController();
  final TextEditingController _mealProteinCtrl = TextEditingController();
  final TextEditingController _mealCarbsCtrl = TextEditingController();
  final TextEditingController _mealFatCtrl = TextEditingController();
  final TextEditingController _mealFiberCtrl = TextEditingController();
  final TextEditingController _mealSodiumCtrl = TextEditingController();
  final TextEditingController _mealAddedSugarCtrl = TextEditingController();
  final TextEditingController _mealNoteCtrl = TextEditingController();

  bool _isUpdatingCalories = false;
  bool _isAutofillingMacrosFromCalories = false;

  @override
  void initState() {
    super.initState();
    _refreshMeals();
    _loadAdvancedNutritionPreference();
    _mealProteinCtrl.addListener(_recalculateCaloriesFromMacros);
    _mealCarbsCtrl.addListener(_recalculateCaloriesFromMacros);
    _mealFatCtrl.addListener(_recalculateCaloriesFromMacros);
    // Delay connectivity check to avoid blocking UI
    Future.delayed(const Duration(milliseconds: 500), _checkConnectivity);
  }

  void _recalculateCaloriesFromMacros() {
    if (_isUpdatingCalories) return;
    if (_isAutofillingMacrosFromCalories) return;

    final protein = double.tryParse(_mealProteinCtrl.text.trim());
    final carbs = double.tryParse(_mealCarbsCtrl.text.trim());
    final fat = double.tryParse(_mealFatCtrl.text.trim());

    if (protein == null && carbs == null && fat == null) return;

    final p = protein ?? 0;
    final c = carbs ?? 0;
    final f = fat ?? 0;

    final calories = (p * 4) + (c * 4) + (f * 9);
    final rounded = calories.isFinite ? calories.round() : 0;
    final next = rounded <= 0 ? '' : rounded.toString();

    if (_mealCaloriesCtrl.text.trim() == next) return;

    _isUpdatingCalories = true;
    _mealCaloriesCtrl.text = next;
    _isUpdatingCalories = false;
  }

  void _autofillMacrosFromCalories() {
    final calories = double.tryParse(_mealCaloriesCtrl.text.trim());
    if (calories == null || calories <= 0) {
      setState(() {
        _nutritionError = 'Enter calories first';
      });
      return;
    }

    // Simple macro split from calories: 30% protein, 40% carbs, 30% fat.
    final proteinGrams = (calories * 0.30) / 4.0;
    final carbsGrams = (calories * 0.40) / 4.0;
    final fatGrams = (calories * 0.30) / 9.0;

    setState(() {
      _isAutofillingMacrosFromCalories = true;
      _nutritionError = null;

      _mealProteinCtrl.text = proteinGrams.toStringAsFixed(1);
      _mealCarbsCtrl.text = carbsGrams.toStringAsFixed(1);
      _mealFatCtrl.text = fatGrams.toStringAsFixed(1);

      _isAutofillingMacrosFromCalories = false;
    });
  }

  Future<void> _loadAdvancedNutritionPreference() async {
    try {
      final settings = await _storage.getAppSettings();
      final raw = settings?[_settingsKeyShowAdvancedNutrition];
      if (!mounted) return;
      if (raw is bool) {
        setState(() {
          _showAdvancedNutrition = raw;
        });
      }
    } catch (_) {
      // Ignore
    }
  }

  Future<void> _persistAdvancedNutritionPreference(bool value) async {
    try {
      final settings = await _storage.getAppSettings() ?? <String, dynamic>{};
      settings[_settingsKeyShowAdvancedNutrition] = value;
      await _storage.saveAppSettings(settings);
    } catch (_) {
      // Ignore
    }
  }

  Future<void> _checkConnectivity() async {
    if (kIsWeb) {
      setState(() {
        _isOnline = true; // Assume online on web since HTTP calls will work
      });
      return;
    }

    // Try multiple reliable endpoints to avoid false negatives
    const endpoints = [
      'https://world.openfoodfacts.org',
      'https://www.google.com',
      'https://jsonplaceholder.typicode.com/posts/1',
    ];

    bool isOnline = false;

    for (final url in endpoints) {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode >= 200 && response.statusCode < 400) {
          isOnline = true;
          break;
        }
      } catch (e) {
        debugPrint('Connectivity check failed for $url: $e');
        // Continue to next endpoint
      }
    }

    if (!mounted) return;
    setState(() {
      _isOnline = isOnline;
    });
  }

  Future<void> _searchNutrition() async {
    final name = _mealNameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nutritionError = 'Enter a food name first');
      return;
    }
    setState(() {
      _isSearchingNutrition = true;
      _nutritionError = null;
    });

    try {
      // First try OpenFoodFacts for multiple options
      final offProducts = await OpenFoodFactsService.searchFood(name);
      debugPrint('Nutrition search found ${offProducts.length} products');

      if (offProducts.isNotEmpty) {
        // Show selection dialog with multiple options
        final selectedProduct = await _showOpenFoodFactsPickDialog(offProducts);
        if (selectedProduct == null) {
          setState(() => _isSearchingNutrition = false);
          return;
        }

        // Convert to nutrition data and show portion dialog
        final nutritionData =
            OpenFoodFactsService.productToNutritionData(selectedProduct);
        final selectedPortion = await _showPortionDialog(nutritionData);
        if (selectedPortion == null) {
          setState(() => _isSearchingNutrition = false);
          return;
        }

        if (!mounted) return;
        setState(() {
          _mealNameCtrl.text = nutritionData['name'];
          _mealProteinCtrl.text =
              selectedPortion['protein']?.toStringAsFixed(1) ?? '';
          _mealCarbsCtrl.text =
              selectedPortion['carbs']?.toStringAsFixed(1) ?? '';
          _mealFatCtrl.text = selectedPortion['fat']?.toStringAsFixed(1) ?? '';
          _mealFiberCtrl.text =
              selectedPortion['fiber']?.toStringAsFixed(1) ?? '';
          _mealSodiumCtrl.text =
              selectedPortion['sodium']?.toStringAsFixed(0) ?? '';
          _mealAddedSugarCtrl.text =
              selectedPortion['addedSugar']?.toStringAsFixed(1) ?? '';
          final hasAnyAdvanced =
              (selectedPortion['fiber'] ?? 0) != 0 ||
              (selectedPortion['sodium'] ?? 0) != 0 ||
              (selectedPortion['addedSugar'] ?? 0) != 0;
          if (hasAnyAdvanced) {
            _showAdvancedNutrition = true;
          }
          _nutritionError = null;
        });
        _recalculateCaloriesFromMacros();
        return;
      }

      // Fallback to legacy service
      debugPrint('Trying legacy NutritionService...');
      final nutritionData = await NutritionService.searchFood(name);
      if (nutritionData == null) {
        setState(() {
          _nutritionError = 'No nutrition data found for "$name"';
        });
        return;
      }

      // Show portion dialog
      final selectedPortion = await _showPortionDialog(nutritionData);
      if (selectedPortion == null) {
        setState(() => _isSearchingNutrition = false);
        return;
      }

      if (!mounted) return;

      setState(() {
        _mealNameCtrl.text = nutritionData['name'];
        _mealProteinCtrl.text =
            selectedPortion['protein']?.toStringAsFixed(1) ?? '';
        _mealCarbsCtrl.text =
            selectedPortion['carbs']?.toStringAsFixed(1) ?? '';
        _mealFatCtrl.text = selectedPortion['fat']?.toStringAsFixed(1) ?? '';
        _mealFiberCtrl.text =
            selectedPortion['fiber']?.toStringAsFixed(1) ?? '';
        _mealSodiumCtrl.text =
            selectedPortion['sodium']?.toStringAsFixed(0) ?? '';
        _mealAddedSugarCtrl.text =
            selectedPortion['addedSugar']?.toStringAsFixed(1) ?? '';
        final hasAnyAdvanced =
            (selectedPortion['fiber'] ?? 0) != 0 ||
            (selectedPortion['sodium'] ?? 0) != 0 ||
            (selectedPortion['addedSugar'] ?? 0) != 0;
        if (hasAnyAdvanced) {
          _showAdvancedNutrition = true;
        }
        _nutritionError = null;
      });
      _recalculateCaloriesFromMacros();
    } catch (e) {
      debugPrint('Nutrition search error: $e');
      if (!mounted) return;
      setState(() {
        // Provide clearer error messages based on exception type
        String errorMsg = 'Search failed';
        if (e.toString().toLowerCase().contains('timeout')) {
          errorMsg = 'Request timed out. Try again.';
        } else if (e.toString().toLowerCase().contains('connection') ||
                   e.toString().toLowerCase().contains('network')) {
          errorMsg = 'Network error. Check your internet.';
        } else if (e.toString().toLowerCase().contains('404')) {
          errorMsg = 'Service unavailable. Try later.';
        } else {
          errorMsg = 'Search failed: ${e.toString().replaceAll('Exception: ', '')}';
        }
        _nutritionError = errorMsg;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingNutrition = false;
        });
      }
    }
  }

  Future<off.Product?> _showOpenFoodFactsPickDialog(
      List<off.Product> products) async {
    return showDialog<off.Product>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose a match'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final nutriments = product.nutriments;
              final nutrimentsJson = nutriments?.toJson() ?? {};
              final kcal =
                  nutrimentsJson['energy-kcal_100g']?.toStringAsFixed(0) ??
                      nutrimentsJson['energy-kcal']?.toStringAsFixed(0) ??
                      'N/A';
              final brand = product.brands?.isNotEmpty == true
                  ? product.brands!
                  : 'Generic';
              final nutriScore = product.nutriscore?.toUpperCase() ?? 'N/A';

              return ListTile(
                title: Text(product.productName ?? 'Unknown Product'),
                subtitle: Text('$brand • $kcal kcal per 100g'),
                trailing: nutriScore != 'N/A'
                    ? Text('Nutri-Score: $nutriScore')
                    : null,
                onTap: () => Navigator.pop(context, product),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _showPortionDialog(
      Map<String, dynamic> nutritionData) async {
    final baseCalories = nutritionData['calories'] as double;
    final baseProtein = nutritionData['protein'] as double;
    final baseCarbs = nutritionData['carbs'] as double;
    final baseFat = nutritionData['fat'] as double;
    final baseFiber = (nutritionData['fiber'] as num?)?.toDouble() ?? 0.0;
    final baseSodium = (nutritionData['sodium'] as num?)?.toDouble() ?? 0.0;
    final baseAddedSugar =
        (nutritionData['addedSugar'] as num?)?.toDouble() ?? 0.0;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final customController = TextEditingController();

          return AlertDialog(
            title: Text('Select portion for ${nutritionData['name']}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Base nutrition per 100g:',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Calories: ${baseCalories.toStringAsFixed(0)} kcal'),
                  Text('Protein: ${baseProtein.toStringAsFixed(1)} g'),
                  Text('Carbs: ${baseCarbs.toStringAsFixed(1)} g'),
                  Text('Fat: ${baseFat.toStringAsFixed(1)} g'),
                  Text('Fiber: ${baseFiber.toStringAsFixed(1)} g'),
                  Text('Sodium: ${baseSodium.toStringAsFixed(0)} mg'),
                  Text('Added Sugar: ${baseAddedSugar.toStringAsFixed(1)} g'),
                  const SizedBox(height: 16),
                  const Text('Choose portion:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _multiplyNutrition(baseCalories, baseProtein, baseCarbs,
                          baseFat, baseFiber, baseSodium, baseAddedSugar, 1.0),
                    ),
                    child: const Text('100g (standard)'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _multiplyNutrition(baseCalories, baseProtein, baseCarbs,
                          baseFat, baseFiber, baseSodium, baseAddedSugar, 2.5),
                    ),
                    child: const Text('250g (typical serving)'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _multiplyNutrition(baseCalories, baseProtein, baseCarbs,
                          baseFat, baseFiber, baseSodium, baseAddedSugar, 5.0),
                    ),
                    child: const Text('500g (large serving)'),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: customController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Custom amount (grams)',
                            hintText: 'e.g., 150',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final grams =
                              double.tryParse(customController.text.trim());
                          if (grams != null && grams > 0) {
                            final multiplier = grams / 100.0;
                            Navigator.pop(
                              context,
                              _multiplyNutrition(
                                baseCalories,
                                baseProtein,
                                baseCarbs,
                                baseFat,
                                baseFiber,
                                baseSodium,
                                baseAddedSugar,
                                multiplier,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a valid number'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        child: const Text('Use'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  Map<String, double> _multiplyNutrition(
    double calories,
    double protein,
    double carbs,
    double fat,
    double fiber,
    double sodium,
    double addedSugar,
    double multiplier,
  ) {
    return {
      'calories': calories * multiplier,
      'protein': protein * multiplier,
      'carbs': carbs * multiplier,
      'fat': fat * multiplier,
      'fiber': fiber * multiplier,
      'sodium': sodium * multiplier,
      'addedSugar': addedSugar * multiplier,
    };
  }

  @override
  void dispose() {
    _mealProteinCtrl.removeListener(_recalculateCaloriesFromMacros);
    _mealCarbsCtrl.removeListener(_recalculateCaloriesFromMacros);
    _mealFatCtrl.removeListener(_recalculateCaloriesFromMacros);
    _mealNameCtrl.dispose();
    _mealCaloriesCtrl.dispose();
    _mealProteinCtrl.dispose();
    _mealCarbsCtrl.dispose();
    _mealFatCtrl.dispose();
    _mealFiberCtrl.dispose();
    _mealSodiumCtrl.dispose();
    _mealAddedSugarCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShootingStarsAmbientBackground(
      child: GradientScaffold(
        appBar: AppBar(
          title: const Text(
            'Meals',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMealTypeSelector(),
              const SizedBox(height: 20),
              _buildPhotoArea(),
              const SizedBox(height: 20),
              _buildManualEntryForm(),
              const SizedBox(height: 20),
              _buildTodayMealsSummary(),
              const SizedBox(height: 16),
              _buildExportButton(),
              const SizedBox(height: 20),
              _buildTodayMealsList(),
              if (!kIsWeb) ...[
                const SizedBox(height: 16),
                SafeArea(
                  top: false,
                  child: Center(
                    child: AdBannerWidget(
                      adUnitId: AdBannerWidget.bannerMealsId,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Meal Type',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: MealType.values.map((type) {
            final isSelected = _selectedMealType == type;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: type != MealType.dinner ? 8 : 0,
                ),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMealType = type;
                      _selectedImage = null;
                    });
                    _refreshMeals();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.secondary
                          : AppColors.card.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.secondary
                            : Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: Text(
                      _getMealTypeLabel(type),
                      style: TextStyle(
                        color:
                            isSelected ? Colors.black : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPhotoArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add Meal Photo',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          width: double.infinity,
          child: SectionCard(
            padding: const EdgeInsets.all(16),
            child: _selectedImage != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: kIsWeb
                            ? Image.network(
                                _selectedImage!.path,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              )
                            : Image.file(
                                File(_selectedImage!.path),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedImage = null;
                            });
                          },
                          child: CircleAvatar(
                            backgroundColor: Colors.black.withOpacity(0.45),
                            child: const Icon(Icons.close, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.camera_alt,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Take or upload a photo of your meal',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _takePhoto,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Camera'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: Colors.black,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _uploadPhoto,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualEntryForm() {
    return SectionCard(
      highlighted: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Meal details',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_editingMealId != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Editing saved meal',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_editingMealId != null) {
                          // Revert to original meal values
                          final meal = _todayMeals.firstWhere(
                            (m) => m.id == _editingMealId,
                            orElse: () => MealItem(
                              name: '',
                              calories: 0,
                              protein: 0,
                              carbs: 0,
                              fat: 0,
                            ),
                          );
                          _startEditMeal(meal);
                        } else {
                          // Clear only if not editing
                          _clearForm();
                        }
                      });
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _mealNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Meal name',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 11,
                    color: _isOnline ? Colors.greenAccent : Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_isOnline && !_isSearchingNutrition)
                TextButton(
                  onPressed: _searchNutrition,
                  child: const Text('Find nutrition'),
                ),
              if (_isSearchingNutrition)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (_nutritionError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _nutritionError!,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.redAccent,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _mealCaloriesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Calories',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _autofillMacrosFromCalories,
                  child: const Text('System auto-fill'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mealProteinCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Protein (g)',
            ),
          ),
          const SizedBox(height: 12),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: ValueKey('advancedNutrition_$_showAdvancedNutrition'),
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: _showAdvancedNutrition,
              onExpansionChanged: (expanded) {
                setState(() {
                  _showAdvancedNutrition = expanded;
                });
                _persistAdvancedNutritionPreference(expanded);
              },
              title: Text(
                _showAdvancedNutrition
                    ? 'Hide advanced nutrition'
                    : 'Show advanced nutrition',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _mealCarbsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Carbs (g)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _mealFatCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Fat (g)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _mealFiberCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Fiber (g)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _mealSodiumCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Sodium (mg)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _mealAddedSugarCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Added Sugar (g)',
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _mealNoteCtrl,
            decoration: InputDecoration(
              labelText: 'Quick note (optional)',
              hintText: 'How did this feel? Context?',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              alignLabelWithHint: true,
              filled: true,
              fillColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            ),
            maxLines: 4,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSavingMeal ? null : _saveManualMeal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                _isSavingMeal
                    ? 'Saving...'
                    : (_editingMealId == null
                        ? 'Add to Today\'s Meals'
                        : 'Update Meal'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayMealsSummary() {
    final totalCalories = _todayMeals.fold<int>(
      0,
      (sum, meal) => sum + meal.calories,
    );
    final totalProtein = _todayMeals.fold<double>(
      0,
      (sum, meal) => sum + meal.protein,
    );
    final totalCarbs = _todayMeals.fold<double>(
      0,
      (sum, meal) => sum + meal.carbs,
    );
    final totalFat = _todayMeals.fold<double>(0, (sum, meal) => sum + meal.fat);
    final totalFiber =
        _todayMeals.fold<double>(0, (sum, meal) => sum + meal.fiber);
    final totalSodium =
        _todayMeals.fold<int>(0, (sum, meal) => sum + meal.sodium);
    final totalAddedSugar =
        _todayMeals.fold<double>(0, (sum, meal) => sum + meal.addedSugar);

    return SectionCard(
      child: Column(
        children: [
          const Text(
            'Today\'s Summary',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItemWithIcon(
                  icon: Icons.local_fire_department,
                  label: 'Calories',
                  value: '$totalCalories',
                  color: AppColors.accent,
                ),
              ),
              Expanded(
                child: _buildSummaryItemWithIcon(
                  icon: Icons.fitness_center,
                  label: 'Protein',
                  value: '${totalProtein.toStringAsFixed(1)}g',
                  color: Colors.redAccent,
                ),
              ),
              Expanded(
                child: _buildSummaryItemWithIcon(
                  icon: Icons.grain,
                  label: 'Carbs',
                  value: '${totalCarbs.toStringAsFixed(1)}g',
                  color: AppColors.primary,
                ),
              ),
              Expanded(
                child: _buildSummaryItemWithIcon(
                  icon: Icons.water_drop,
                  label: 'Fat',
                  value: '${totalFat.toStringAsFixed(1)}g',
                  color: Colors.yellowAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                'Fiber',
                '${totalFiber.toStringAsFixed(1)}g',
                Colors.greenAccent,
              ),
              _buildSummaryItem(
                'Sodium',
                '${totalSodium}mg',
                Colors.orangeAccent,
              ),
              _buildSummaryItem(
                'Added Sugar',
                '${totalAddedSugar.toStringAsFixed(1)}g',
                Colors.purpleAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItemWithIcon({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildTodayMealsList() {
    if (_isLoadingMeals) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_todayMeals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: const Center(
          child: Text(
            'No meals added today yet',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today\'s Meals',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._todayMeals.map((meal) => _buildMealItem(meal)),
      ],
    );
  }

  Widget _buildMealItem(MealItem meal) {
    return SectionCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () => _startEditMeal(meal),
        child: Row(
          children: [
            if (meal.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: meal.imageUrl!.startsWith('http')
                    ? Image.network(
                        meal.imageUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _placeholderBox();
                        },
                      )
                    : (kIsWeb
                        ? Image.network(
                            meal.imageUrl!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _placeholderBox();
                            },
                          )
                        : Image.file(
                            File(meal.imageUrl!),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _placeholderBox();
                            },
                          )),
              )
            else
              _placeholderBox(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${meal.calories} calories',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'P: ${meal.protein}g • C: ${meal.carbs}g • F: ${meal.fat}g',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit_outlined, color: AppColors.secondary),
              onPressed: () => _startEditMeal(meal),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => _deleteMeal(meal),
            ),
          ],
        ),
      ),
    );
  }

  void _startEditMeal(MealItem meal) {
    if (meal.id == null) return;
    setState(() {
      _editingMealId = meal.id;
      _mealNameCtrl.text = meal.name;
      _mealCaloriesCtrl.text = meal.calories.toString();
      _mealProteinCtrl.text = meal.protein.toString();
      _mealCarbsCtrl.text = meal.carbs.toString();
      _mealFatCtrl.text = meal.fat.toString();
      _mealFiberCtrl.text = meal.fiber.toString();
      _mealSodiumCtrl.text = meal.sodium.toString();
      _mealAddedSugarCtrl.text = meal.addedSugar.toString();
      _selectedImage = meal.imageUrl != null ? XFile(meal.imageUrl!) : null;

      final hasAnyAdvanced = meal.carbs != 0 ||
          meal.fat != 0 ||
          meal.fiber != 0 ||
          meal.sodium != 0 ||
          meal.addedSugar != 0;
      if (hasAnyAdvanced) {
        _showAdvancedNutrition = true;
      }
    });
  }

  Widget _placeholderBox() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.restaurant, color: AppColors.textSecondary),
    );
  }

  void _clearForm() {
    _editingMealId = null;
    _selectedImage = null;
    _mealNameCtrl.clear();
    _mealCaloriesCtrl.clear();
    _mealProteinCtrl.clear();
    _mealCarbsCtrl.clear();
    _mealFatCtrl.clear();
    _mealFiberCtrl.clear();
    _mealSodiumCtrl.clear();
    _mealAddedSugarCtrl.clear();
    _mealNoteCtrl.clear();
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (!mounted) return;
      if (photo != null) {
        setState(() {
          _selectedImage = photo;
        });
        await _maybeAnalyzePhotoWithAI(photo);
      }
    } catch (e) {
      _showError('Error taking photo: $e');
    }
  }

  Future<void> _uploadPhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
      if (!mounted) return;
      if (photo != null) {
        setState(() {
          _selectedImage = photo;
        });
        await _maybeAnalyzePhotoWithAI(photo);
      }
    } catch (e) {
      _showError('Error uploading photo: $e');
    }
  }

  Future<void> _maybeAnalyzePhotoWithAI(XFile photo) async {
    if (kIsWeb) return;
    
    // Capture navigator reference before any async operations
    final navigator = Navigator.of(context);
    
    try {
      final enabled = await FirebaseAIService.instance.isFeatureEnabled('photo_analysis');
      if (!enabled) return;

      _showLoading('Analyzing meal photo...');

      final analysis = await FirebaseAIService.instance.analyzeMealPhoto(File(photo.path));

      if (!mounted) return;
      navigator.pop();

      if (analysis != null) {
        _populateFromAIAnalysis(analysis);
      }
    } catch (_) {
      if (!mounted) return;
      navigator.pop();
    }
  }

  void _populateFromAIAnalysis(dynamic analysis) {
    setState(() {
      _mealNameCtrl.text = analysis.name ?? '';
      _mealCaloriesCtrl.text = analysis.calories?.toString() ?? '';
      _mealProteinCtrl.text = analysis.protein?.toString() ?? '';
      _mealCarbsCtrl.text = analysis.carbs?.toString() ?? '';
      _mealFatCtrl.text = analysis.fat?.toString() ?? '';
      _mealFiberCtrl.text = analysis.fiber?.toString() ?? '';
      _mealSodiumCtrl.text = analysis.sodium?.toString() ?? '';
      _mealAddedSugarCtrl.text = analysis.sugar?.toString() ?? '';
      _mealNoteCtrl.text = 'AI Analysis: ${analysis.description ?? ''}';

      final hasAnyAdvanced =
          (_mealFiberCtrl.text.trim().isNotEmpty && _mealFiberCtrl.text.trim() != '0') ||
          (_mealSodiumCtrl.text.trim().isNotEmpty && _mealSodiumCtrl.text.trim() != '0') ||
          (_mealAddedSugarCtrl.text.trim().isNotEmpty && _mealAddedSugarCtrl.text.trim() != '0');
      if (hasAnyAdvanced) {
        _showAdvancedNutrition = true;
      }
    });
  }

  Future<void> _saveManualMeal() async {
    final name = _mealNameCtrl.text.trim();
    final calories = int.tryParse(_mealCaloriesCtrl.text.trim()) ?? 0;
    final protein = double.tryParse(_mealProteinCtrl.text.trim()) ?? 0;
    final carbs = double.tryParse(_mealCarbsCtrl.text.trim()) ?? 0;
    final fat = double.tryParse(_mealFatCtrl.text.trim()) ?? 0;
    final fiber = double.tryParse(_mealFiberCtrl.text.trim()) ?? 0;
    final sodium = int.tryParse(_mealSodiumCtrl.text.trim()) ?? 0;
    final addedSugar = double.tryParse(_mealAddedSugarCtrl.text.trim()) ?? 0;

    if (name.isEmpty) {
      _showError('Please enter meal name');
      return;
    }
    if (calories <= 0) {
      _showError('Please enter calories');
      return;
    }

    setState(() {
      _isSavingMeal = true;
    });

    final date = DateTime.now();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isSavingMeal = false;
      });
      _showError('Please sign in to save meals.');
      return;
    }

    final mealToAdd = MealItem(
      mealType: _selectedMealType,
      name: name,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      sodium: sodium,
      addedSugar: addedSugar,
      imageUrl: _selectedImage?.path,
    );

    try {
      final payload = {
        'meal_type': _selectedMealType.name,
        'name': mealToAdd.name,
        'calories': mealToAdd.calories,
        'protein': mealToAdd.protein,
        'carbs': mealToAdd.carbs,
        'fat': mealToAdd.fat,
        'fiber': mealToAdd.fiber,
        'sodium': mealToAdd.sodium,
        'added_sugar': mealToAdd.addedSugar,
        'image_url': mealToAdd.imageUrl,
        'note': _mealNoteCtrl.text.trim().isEmpty
            ? null
            : _mealNoteCtrl.text.trim(),
        'created_at': date.toIso8601String(),
      };

      if (_editingMealId != null) {
        await _storage.updateMeal(_editingMealId!, payload);
      } else {
        await _storage.addMeal(payload);
      }

      await StreakService.markActiveToday();

      await _refreshMeals();

      if (!mounted) return;
      setState(() {
        _clearForm();
        _isSavingMeal = false;
      });

      _showSuccess('Meal saved!');
      return;
    } catch (e) {
      _showError('Failed to save meal: $e');
    }

    setState(() {
      _selectedImage = null;
      _isSavingMeal = false;
    });
  }

  Future<void> _refreshMeals() async {
    setState(() {
      _isLoadingMeals = true;
    });

    try {
      final meals = await _storage.getMealsForDate(DateTime.now());
      if (!mounted) return;
      final selectedKey = _selectedMealType.name;
      setState(() {
        _todayMeals
          ..clear()
          ..addAll(
            meals
                .where((m) => (m.mealTypeKey).toLowerCase() == selectedKey)
                .map(
                  (m) => MealItem(
                    id: m.uuid,
                    mealType: MealType.values.firstWhere(
                      (e) => e.name == (m.mealTypeKey).toLowerCase(),
                      orElse: () => MealType.breakfast,
                    ),
                    name: m.name,
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
                .toList(),
          );
        _isLoadingMeals = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMeals = false;
      });
      _showError('Failed to load meals: $e');
    }
  }

  void _refreshHomeScreen() {
    HomeScreen.globalRefresh();
  }

  Future<void> _deleteMeal(MealItem meal) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Please sign in to delete meals.');
      return;
    }

    final mealId = meal.id;
    if (mealId == null) {
      setState(() {
        _todayMeals.remove(meal);
      });
      // Notify home screen to refresh
      if (mounted) _refreshHomeScreen();
      return;
    }

    try {
      await _storage.deleteMeal(mealId);
      if (!mounted) return;
      setState(() {
        _todayMeals.remove(meal);
      });
      // Notify home screen to refresh
      if (mounted) _refreshHomeScreen();
    } catch (e) {
      _showError('Failed to delete meal: $e');
    }
  }

  String _getMealTypeLabel(MealType type) {
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showLoading(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        content: Row(
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportButton() {
    final isDisabled = _todayMeals.isEmpty;
    final colors = isDisabled
        ? <Color>[Colors.grey.shade700, Colors.grey.shade600]
        : <Color>[
            AppColors.secondary,
            AppColors.secondary.withOpacity(0.85),
          ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(colors: colors),
      ),
      child: ElevatedButton(
        onPressed: isDisabled ? null : _exportMealsToExcel,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.file_download, size: 24),
            const SizedBox(width: 12),
            const Text(
              'EXPORT TO EXCEL',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportMealsToExcel() async {
    try {
      final mealsData = _todayMeals
          .map(
            (meal) => {
              'date': DateTime.now().toString().split(' ')[0],
              'mealType': _getMealTypeLabel(_selectedMealType),
              'foodItem': meal.name,
              'calories': meal.calories,
              'protein': meal.protein,
              'carbs': meal.carbs,
              'fat': meal.fat,
              'fiber': meal.fiber,
              'sodium': meal.sodium,
              'added_sugar': meal.addedSugar,
            },
          )
          .toList();

      await ExcelService.exportMealsToExcel(mealsData);

      if (mounted) {
        _showSuccess('Meals exported to Excel successfully!');
      }
    } catch (e) {
      debugPrint('Error exporting meals to Excel: $e');
      if (mounted) {
        _showError('Failed to export to Excel: $e');
      }
    }
  }
}

