/// User profile model containing personal information and fitness goals
/// 
/// Default values (can be changed by user in Profile screen):
/// - Name: 'User'
/// - Age: 25 years
/// - Gender: 'male'
/// - Height: 170 cm (~5'7")
/// - Weight: 70 kg (~154 lbs)
/// - Activity Level: 3 (Moderately active)
/// - Goal: 'maintain'
/// 
/// These defaults are used for calculations when user hasn't set their profile yet.
class UserProfile {
  String name;
  int age;
  String gender; // 'male' or 'female'
  double heightCm; // height in centimeters
  double weightKg; // weight in kilograms
  int activityLevel; // 1-5 scale (sedentary to very active)
  String goal; // 'lose_weight', 'maintain', 'gain_muscle'
  double targetWeightKg; // target weight for goals
  DateTime? goalStartDate;
  DateTime? goalEndDate;
  List<UserGoal> goals;

  UserProfile({
    required this.name,
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    this.activityLevel = 3, // moderately active default
    this.goal = 'maintain',
    this.targetWeightKg = 0.0,
    this.goalStartDate,
    this.goalEndDate,
    List<UserGoal>? goals,
  }) : goals = goals ?? <UserGoal>[];

  List<UserGoal> get sortedGoals {
    final copy = [...goals];
    copy.sort((a, b) => a.fromDate.compareTo(b.fromDate));
    return copy;
  }

  UserGoal? activeGoalForDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    for (final g in sortedGoals) {
      if (g.isActiveForDate(day)) return g;
    }
    return null;
  }

  double calculateMaintenanceCalories() {
    // Mifflin–St Jeor (BMR) then activity multiplier to estimate maintenance.
    final isMale = gender.toLowerCase().trim() == 'male';
    final basalBmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) + (isMale ? 5 : -161);

    final activityFactors = [1.2, 1.375, 1.55, 1.725, 1.9];
    final activityMultiplier = activityLevel > 0 && activityLevel <= 5
        ? activityFactors[activityLevel - 1]
        : 1.55;

    return basalBmr * activityMultiplier;
  }

  double calculateBMR() {
    return calculateMaintenanceCalories();
  }

  // Calculate daily calorie needs based on goal
  Map<String, dynamic> calculateDailyTargets({DateTime? forDate}) {
    final maintenanceCalories = calculateMaintenanceCalories();
    final checkDate = forDate ?? DateTime.now();
    final day = DateTime(checkDate.year, checkDate.month, checkDate.day);

    final active = activeGoalForDate(day);
    final requestedGoalText = (active?.goalType ?? goal).toLowerCase().trim();
    final activeTargetWeightKg = active?.targetWeightKg ?? targetWeightKg;
    final startDate = active?.fromDate ?? goalStartDate;
    final endDate = active?.toDate ?? goalEndDate;

    final hasGoalRange = startDate != null && endDate != null;
    final isWithinRange = hasGoalRange
        ? (() {
            final start = DateTime(
              startDate.year,
              startDate.month,
              startDate.day,
            );
            final end = DateTime(
              endDate.year,
              endDate.month,
              endDate.day,
            );
            return !day.isBefore(start) && !day.isAfter(end);
          })()
        : false;

    final goalText = isWithinRange ? requestedGoalText : 'maintain';
    final deltaKg = (goalText != 'maintain' && activeTargetWeightKg > 0)
        ? (activeTargetWeightKg - weightKg)
        : 0.0;

    final recommendedWeeklyWeightChange = goalText == 'lose_weight'
        ? -1.0
        : (goalText == 'gain_muscle')
            ? 0.5
            : 0.0;

    // Calculate kcal adjustment from goal timeline if provided.
    // Rough estimate: 1kg ~= 7700 kcal
    int? recommendedKcalAdjustment;
    if (startDate != null &&
        endDate != null &&
        deltaKg != 0 &&
        goalText != 'maintain') {
      final start = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      final end = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
      );
      final days = end.difference(start).inDays + 1;
      if (days > 0) {
        final dailyKg = deltaKg / days;

        // kcal per day needed to hit the goal
        final kcalPerDay = (dailyKg * 7700).round();

        // Clamp to safer bounds so targets stay reasonable.
        // Lose: up to ~1000 kcal deficit; Gain: up to ~750 kcal surplus.
        if (goalText == 'lose_weight') {
          recommendedKcalAdjustment = kcalPerDay.clamp(-1000, -100);
        } else if (goalText == 'gain_muscle') {
          recommendedKcalAdjustment = kcalPerDay.clamp(100, 750);
        }
      }
    }

    double dailyCalories = maintenanceCalories;
    if (goalText == 'lose_weight') {
      dailyCalories = maintenanceCalories + (recommendedKcalAdjustment ?? -500);
    } else if (goalText == 'gain_muscle') {
      dailyCalories = maintenanceCalories + (recommendedKcalAdjustment ?? 300);
    }

    final proteinGPerKg = goalText == 'gain_muscle' ? 2.0 : 1.6;
    final proteinGrams = (weightKg * proteinGPerKg).clamp(0, double.infinity);
    final proteinCalories = proteinGrams * 4;

    final remainingCalories =
        (dailyCalories - proteinCalories).clamp(0, double.infinity);
    final carbGrams = (remainingCalories * 0.55) / 4;
    final fatGrams = (remainingCalories * 0.45) / 9;

    // Water target (ml): base 35ml/kg (activity level removed)
    final waterMl = (weightKg * 35).round();

    // Steps target: basic scaling (activity level removed)
    int stepsTarget = 8000;
    if (goalText == 'lose_weight') stepsTarget += 1000;
    if (goalText == 'gain_muscle') stepsTarget += 500;

    // Nutrition targets (allow overrides from active goal)
    final fiberTarget = active?.targetFiberGrams ?? ((dailyCalories / 1000.0) * 14.0);
    final sodiumTarget = (active?.targetSodiumMg ?? 2300).toDouble();
    final addedSugarTarget = (active?.targetAddedSugarGrams ?? 50.0);

    return {
      'bmr': maintenanceCalories.round(),
      'maintenanceCalories': maintenanceCalories.round(),
      'dailyCalories': dailyCalories.round(),
      'proteinGrams': proteinGrams.round(),
      'carbGrams': carbGrams.round(),
      'fatGrams': fatGrams.round(),
      'waterMl': waterMl,
      'stepsTarget': stepsTarget,
      'fiberTarget': fiberTarget,
      'sodiumTarget': sodiumTarget,
      'addedSugarTarget': addedSugarTarget,
      'goalApplied': goalText != 'maintain' && isWithinRange,
      'weeklyWeightChange': recommendedWeeklyWeightChange,
      'kcalAdjustment': recommendedKcalAdjustment,
    };
  }

  // Calculate BMI
  double calculateBMI() {
    final heightM = heightCm / 100;
    return weightKg / (heightM * heightM);
  }

  String getBMICategory() {
    final bmi = calculateBMI();
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal weight';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  Map<String, dynamic> toJson() {
    return {
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
      'goals': goals.map((g) => g.toJson()).toList(),
      'bmi': calculateBMI(),
      'bmiCategory': getBMICategory(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawGoals = json['goals'];
    final parsedGoals = <UserGoal>[];
    if (rawGoals is List) {
      for (final e in rawGoals) {
        if (e is Map) {
          parsedGoals.add(UserGoal.fromJson(e.cast<String, dynamic>()));
        }
      }
    }

    final legacyGoal = (json['goal'] ?? 'maintain').toString() == 'gain_weight'
        ? 'gain_muscle'
        : (json['goal'] ?? 'maintain').toString();
    final legacyTarget = (json['targetWeightKg'] as num?)?.toDouble() ?? 0.0;
    final legacyStartRaw = json['goalStartDate'];
    final legacyEndRaw = json['goalEndDate'];
    final legacyStart = legacyStartRaw != null
        ? DateTime.tryParse(legacyStartRaw.toString())
        : null;
    final legacyEnd =
        legacyEndRaw != null ? DateTime.tryParse(legacyEndRaw.toString()) : null;

    if (parsedGoals.isEmpty &&
        legacyGoal != 'maintain' &&
        legacyTarget > 0 &&
        legacyStart != null &&
        legacyEnd != null) {
      parsedGoals.add(
        UserGoal(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          goalType: legacyGoal,
          targetWeightKg: legacyTarget,
          fromDate: legacyStart,
          toDate: legacyEnd,
          createdAt: DateTime.now(),
        ),
      );
    }

    return UserProfile(
      name: json['name']?.toString() ?? 'User',
      age: (json['age'] as num?)?.toInt() ?? 25,
      gender: json['gender']?.toString() ?? 'male',
      heightCm: (json['heightCm'] as num?)?.toDouble() ?? 170.0,
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 70.0,
      activityLevel: (json['activityLevel'] as num?)?.toInt() ?? 3,
      goal: json['goal']?.toString() ?? 'maintain',
      targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble() ?? 0.0,
      goalStartDate: json['goalStartDate'] != null
          ? DateTime.tryParse(json['goalStartDate'].toString())
          : null,
      goalEndDate: json['goalEndDate'] != null
          ? DateTime.tryParse(json['goalEndDate'].toString())
          : null,
      goals: parsedGoals,
    );
  }

  /// Creates a default profile with sensible starting values
  /// Users can customize these values in the Profile screen
  factory UserProfile.defaultProfile() {
    return UserProfile(
      name: 'User',
      age: 25,
      gender: 'male',
      heightCm: 170.0, // ~5'7"
      weightKg: 70.0,   // ~154 lbs
      activityLevel: 3, // Moderately active
      goal: 'maintain',
      targetWeightKg: 0.0,
    );
  }
}

class UserGoal {
  String id;
  String goalType;
  double targetWeightKg;
  DateTime fromDate;
  DateTime toDate;
  DateTime createdAt;

  int? targetCalories;
  int? targetProteinGrams;
  int? targetWaterMl;
  int? targetBurnCalories;
  double? targetFiberGrams;
  int? targetSodiumMg;
  double? targetAddedSugarGrams;

  UserGoal({
    required this.id,
    required this.goalType,
    required this.targetWeightKg,
    required this.fromDate,
    required this.toDate,
    required this.createdAt,
    this.targetCalories,
    this.targetProteinGrams,
    this.targetWaterMl,
    this.targetBurnCalories,
    this.targetFiberGrams,
    this.targetSodiumMg,
    this.targetAddedSugarGrams,
  });

  bool isActiveForDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final e = DateTime(toDate.year, toDate.month, toDate.day);
    return !d.isBefore(s) && !d.isAfter(e);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'goalType': goalType,
      'targetWeightKg': targetWeightKg,
      'fromDate': fromDate.toIso8601String(),
      'toDate': toDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'targetCalories': targetCalories,
      'targetProteinGrams': targetProteinGrams,
      'targetWaterMl': targetWaterMl,
      'targetBurnCalories': targetBurnCalories,
      'targetFiberGrams': targetFiberGrams,
      'targetSodiumMg': targetSodiumMg,
      'targetAddedSugarGrams': targetAddedSugarGrams,
    };
  }

  factory UserGoal.fromJson(Map<String, dynamic> json) {
    return UserGoal(
      id: (json['id'] ?? '').toString(),
      goalType: (json['goalType'] ?? 'maintain').toString(),
      targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble() ?? 0.0,
      fromDate: DateTime.tryParse((json['fromDate'] ?? '').toString()) ??
          DateTime.now(),
      toDate:
          DateTime.tryParse((json['toDate'] ?? '').toString()) ?? DateTime.now(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      targetCalories: (json['targetCalories'] as num?)?.toInt(),
      targetProteinGrams: (json['targetProteinGrams'] as num?)?.toInt(),
      targetWaterMl: (json['targetWaterMl'] as num?)?.toInt(),
      targetBurnCalories: (json['targetBurnCalories'] as num?)?.toInt(),
      targetFiberGrams: (json['targetFiberGrams'] as num?)?.toDouble(),
      targetSodiumMg: (json['targetSodiumMg'] as num?)?.toInt(),
      targetAddedSugarGrams: (json['targetAddedSugarGrams'] as num?)?.toDouble(),
    );
  }
}
