import 'package:flutter/foundation.dart';

import 'local_storage_service.dart';
import '../models/user_profile.dart';

class StreakService {
  static const String _keyStreakDays = 'streak_days';
  static const String _keyLastActiveDayKey = 'streak_last_active_day_key';

  static String _dayKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  static DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  static String todayKey() {
    final today = _dateOnly(DateTime.now());
    return _dayKey(today);
  }

  static Future<({int streakDays, String? lastActiveDayKey})> load() async {
    final settings = await LocalStorageService.instance.getAppSettings() ?? <String, dynamic>{};
    final streak = (settings[_keyStreakDays] as num?)?.toInt() ?? 0;

    final lastActive = settings[_keyLastActiveDayKey]?.toString() ??
        settings['streak_last_day_key']?.toString();

    return (streakDays: streak, lastActiveDayKey: lastActive);
  }

  static Future<({int streakDays, bool isTodayActive, String? lastActiveDayKey})>
      loadNormalized() async {
    final settings =
        await LocalStorageService.instance.getAppSettings() ?? <String, dynamic>{};

    var streak = (settings[_keyStreakDays] as num?)?.toInt() ?? 0;
    final lastKeyRaw =
        settings[_keyLastActiveDayKey]?.toString() ?? settings['streak_last_day_key']?.toString();

    if (lastKeyRaw == null || lastKeyRaw.isEmpty) {
      return (streakDays: 0, isTodayActive: false, lastActiveDayKey: null);
    }

    final today = _dateOnly(DateTime.now());
    final todayKey = _dayKey(today);
    final yesterdayKey = _dayKey(today.subtract(const Duration(days: 1)));

    final isToday = lastKeyRaw == todayKey;

    // If the last active day is too old, reset the streak.
    if (!isToday && lastKeyRaw != yesterdayKey && streak != 0) {
      streak = 0;
      settings[_keyStreakDays] = 0;
      await LocalStorageService.instance.saveAppSettings(settings);
    }

    return (streakDays: streak, isTodayActive: isToday, lastActiveDayKey: lastKeyRaw);
  }

  static Future<({int streakDays, String lastActiveDayKey})> markActiveToday() async {
    final settings = await LocalStorageService.instance.getAppSettings() ?? <String, dynamic>{};

    var streak = (settings[_keyStreakDays] as num?)?.toInt() ?? 0;
    final lastKeyRaw =
        settings[_keyLastActiveDayKey]?.toString() ?? settings['streak_last_day_key']?.toString();

    final today = _dateOnly(DateTime.now());
    final todayKey = _dayKey(today);
    final yesterdayKey = _dayKey(today.subtract(const Duration(days: 1)));

    // Check if today has 100% completion
    final hasFullCompletion = await _checkDayCompletion(today);
    
    if (!hasFullCompletion) {
      debugPrint('Streak not updated: Day not 100% complete');
      return (streakDays: streak, lastActiveDayKey: lastKeyRaw ?? '');
    }

    if (lastKeyRaw == todayKey) {
      return (streakDays: streak, lastActiveDayKey: todayKey);
    }

    if (lastKeyRaw == yesterdayKey) {
      streak = streak + 1;
    } else {
      streak = 1;
    }

    settings[_keyStreakDays] = streak;
    settings[_keyLastActiveDayKey] = todayKey;

    // Keep legacy key updated for safety/back-compat.
    settings['streak_last_day_key'] = todayKey;

    await LocalStorageService.instance.saveAppSettings(settings);

    debugPrint('Streak updated: $streak (lastActive=$todayKey)');

    return (streakDays: streak, lastActiveDayKey: todayKey);
  }

  /// Check if a day has 100% completion (all enabled rings at 100%)
  static Future<bool> _checkDayCompletion(DateTime day) async {
    try {
      final storage = LocalStorageService.instance;
      
      // Get user profile for targets
      final profileJson = await storage.getUserProfile();
      if (profileJson == null) return false;
      
      final profile = UserProfile.fromJson(profileJson);
      final activeGoal = profile.activeGoalForDate(day);
      final targets = profile.calculateDailyTargets(forDate: day);
      
      // Get ring enabled settings
      final ringEnabled = await storage.getRingEnabled();
      
      // Get actual data for the day
      final meals = await storage.getMealsForDate(day);
      final activities = await storage.getActivitiesForDate(day);
      final waterMl = await storage.getWaterForDate(day);
      
      // Calculate actuals
      final dayCalories = meals.fold<int>(0, (sum, m) => sum + m.calories);
      final dayProtein = meals.fold<double>(0, (sum, m) => sum + m.protein);
      final dayBurned = activities.fold<int>(0, (sum, a) => sum + a.caloriesBurned);
      
      // Get targets
      final overrideCalories = activeGoal?.targetCalories;
      final overrideProtein = activeGoal?.targetProteinGrams;
      final overrideWater = activeGoal?.targetWaterMl;
      final overrideBurn = activeGoal?.targetBurnCalories;
      
      final caloriesTarget = (overrideCalories != null && overrideCalories > 0)
          ? overrideCalories
          : ((targets['dailyCalories'] as num?)?.toInt() ?? 2500);
      final proteinTarget = (overrideProtein != null && overrideProtein > 0)
          ? overrideProtein
          : ((targets['proteinGrams'] as num?)?.toInt() ?? 150);
      final waterTarget = (overrideWater != null && overrideWater > 0)
          ? overrideWater
          : ((targets['waterMl'] as num?)?.toInt() ?? (profile.weightKg * 35).round());
      final burnTarget = (overrideBurn != null && overrideBurn > 0)
          ? overrideBurn
          : _estimateBurnTargetFromActivityLevel(profile.activityLevel);
      
      // Calculate percentages for enabled rings only
      final enabledPercents = <double>[];
      
      if (ringEnabled['calories'] ?? true) {
        final caloriesPercent = caloriesTarget > 0 ? (dayCalories / caloriesTarget) : 0.0;
        enabledPercents.add(caloriesPercent);
      }
      
      if (ringEnabled['protein'] ?? true) {
        final proteinPercent = proteinTarget > 0 ? (dayProtein / proteinTarget) : 0.0;
        enabledPercents.add(proteinPercent);
      }
      
      if (ringEnabled['burn'] ?? true) {
        final burnPercent = burnTarget > 0 ? (dayBurned / burnTarget) : 0.0;
        enabledPercents.add(burnPercent);
      }
      
      if (ringEnabled['water'] ?? true) {
        final waterPercent = waterTarget > 0 ? (waterMl / waterTarget) : 0.0;
        enabledPercents.add(waterPercent);
      }
      
      // Check if ALL enabled rings are at 100% or more
      if (enabledPercents.isEmpty) return false;
      
      final allComplete = enabledPercents.every((percent) => percent >= 1.0);
      
      debugPrint('Day completion check: ${enabledPercents.map((p) => '${(p * 100).toStringAsFixed(0)}%').join(', ')} = ${allComplete ? '100%' : 'incomplete'}');
      
      return allComplete;
    } catch (e) {
      debugPrint('Error checking day completion: $e');
      return false;
    }
  }
  
  static int _estimateBurnTargetFromActivityLevel(int level) {
    switch (level) {
      case 1: return 200;
      case 2: return 300;
      case 3: return 400;
      case 4: return 550;
      case 5: return 700;
      default: return 400;
    }
  }
}
