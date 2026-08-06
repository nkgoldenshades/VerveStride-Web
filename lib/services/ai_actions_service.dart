import 'package:flutter/foundation.dart';
import 'local_storage_service.dart';
import 'custom_reminder_service.dart';
import '../models/user_profile.dart';

/// AI Actions Service
///
/// Gives AI the ability to:
/// - Create, edit, delete goals
/// - Create, edit, delete reminders
/// - Monitor all user data (workouts, meals, water, sleep)
/// - Make data-driven decisions
///
/// This service acts as the "hands" of the AI - it can take actions
/// based on conversations and user context.
class AIActionsService {
  static final AIActionsService instance = AIActionsService._internal();
  factory AIActionsService() => instance;
  AIActionsService._internal();

  final LocalStorageService _storage = LocalStorageService.instance;
  final CustomReminderService _reminderService = CustomReminderService.instance;

  // ═══════════════════════════════════════════════════════════════════════════
  // GOAL MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  /// AI can create a new goal for the user
  Future<Map<String, dynamic>> createGoal({
    required String goalType, // 'lose_weight', 'gain_muscle', 'maintain'
    required DateTime fromDate,
    required DateTime toDate,
    required double targetWeightKg,
    int? targetCalories,
    int? targetProteinGrams,
    int? targetWaterMl,
    int? targetBurnCalories,
    String? reason, // Why AI is suggesting this goal
  }) async {
    try {
      final profileJson = await _storage.getUserProfile();
      final profile = profileJson != null
          ? UserProfile.fromJson(profileJson)
          : UserProfile.defaultProfile();

      final newGoal = UserGoal(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        goalType: goalType,
        targetWeightKg: targetWeightKg,
        fromDate: fromDate,
        toDate: toDate,
        createdAt: DateTime.now(),
        targetCalories: targetCalories,
        targetProteinGrams: targetProteinGrams,
        targetWaterMl: targetWaterMl,
        targetBurnCalories: targetBurnCalories,
      );

      profile.goals.add(newGoal);
      await _storage.saveUserProfile(profile.toJson());

      debugPrint(
          '✅ AI created goal: $goalType from ${fromDate.toIso8601String()} to ${toDate.toIso8601String()}');
      if (reason != null) debugPrint('   Reason: $reason');

      return {
        'success': true,
        'goal_id': newGoal.id,
        'message': 'Goal created successfully',
        'goal': {
          'type': goalType,
          'from': fromDate.toIso8601String(),
          'to': toDate.toIso8601String(),
          'target_weight': targetWeightKg,
        },
      };
    } catch (e) {
      debugPrint('❌ AI failed to create goal: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// AI can edit an existing goal
  Future<Map<String, dynamic>> editGoal({
    required String goalId,
    String? goalType,
    DateTime? fromDate,
    DateTime? toDate,
    double? targetWeightKg,
    int? targetCalories,
    int? targetProteinGrams,
    int? targetWaterMl,
    int? targetBurnCalories,
    String? reason,
  }) async {
    try {
      final profileJson = await _storage.getUserProfile();
      final profile = profileJson != null
          ? UserProfile.fromJson(profileJson)
          : UserProfile.defaultProfile();

      final goalIndex = profile.goals.indexWhere((g) => g.id == goalId);
      if (goalIndex == -1) {
        return {
          'success': false,
          'error': 'Goal not found',
        };
      }

      final goal = profile.goals[goalIndex];

      // Update fields if provided
      if (goalType != null) goal.goalType = goalType;
      if (fromDate != null) goal.fromDate = fromDate;
      if (toDate != null) goal.toDate = toDate;
      if (targetWeightKg != null) goal.targetWeightKg = targetWeightKg;
      if (targetCalories != null) goal.targetCalories = targetCalories;
      if (targetProteinGrams != null)
        goal.targetProteinGrams = targetProteinGrams;
      if (targetWaterMl != null) goal.targetWaterMl = targetWaterMl;
      if (targetBurnCalories != null)
        goal.targetBurnCalories = targetBurnCalories;

      await _storage.saveUserProfile(profile.toJson());

      debugPrint('✅ AI edited goal: $goalId');
      if (reason != null) debugPrint('   Reason: $reason');

      return {
        'success': true,
        'goal_id': goalId,
        'message': 'Goal updated successfully',
      };
    } catch (e) {
      debugPrint('❌ AI failed to edit goal: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// AI can delete a goal
  Future<Map<String, dynamic>> deleteGoal({
    required String goalId,
    String? reason,
  }) async {
    try {
      final profileJson = await _storage.getUserProfile();
      final profile = profileJson != null
          ? UserProfile.fromJson(profileJson)
          : UserProfile.defaultProfile();

      profile.goals.removeWhere((g) => g.id == goalId);
      await _storage.saveUserProfile(profile.toJson());

      debugPrint('✅ AI deleted goal: $goalId');
      if (reason != null) debugPrint('   Reason: $reason');

      return {
        'success': true,
        'goal_id': goalId,
        'message': 'Goal deleted successfully',
      };
    } catch (e) {
      debugPrint('❌ AI failed to delete goal: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// AI can get all goals
  Future<List<Map<String, dynamic>>> getAllGoals() async {
    try {
      final profileJson = await _storage.getUserProfile();
      final profile = profileJson != null
          ? UserProfile.fromJson(profileJson)
          : UserProfile.defaultProfile();

      return profile.goals
          .map((g) => {
                'id': g.id,
                'type': g.goalType,
                'from': g.fromDate.toIso8601String(),
                'to': g.toDate.toIso8601String(),
                'target_weight': g.targetWeightKg,
                'target_calories': g.targetCalories,
                'target_protein': g.targetProteinGrams,
                'target_water': g.targetWaterMl,
                'target_burn': g.targetBurnCalories,
                'created_at': g.createdAt.toIso8601String(),
              })
          .toList();
    } catch (e) {
      debugPrint('❌ AI failed to get goals: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REMINDER MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  /// AI can create a reminder
  Future<Map<String, dynamic>> createReminder({
    required String title,
    required String body,
    required DateTime scheduledTime,
    String repeat = 'once', // 'once', 'daily', 'weekly'
    String category = 'custom',
    String alertType = 'notification', // 'alarm' or 'notification'
    List<int>? weekdays, // For weekly reminders
    String? reason,
  }) async {
    try {
      debugPrint('🔔 [AI Actions] Creating reminder...');
      debugPrint('   Title: $title');
      debugPrint('   Body: $body');
      debugPrint('   Scheduled: ${scheduledTime.toIso8601String()}');
      debugPrint('   Repeat: $repeat');
      debugPrint('   Category: $category');
      debugPrint('   Alert Type: $alertType');
      if (reason != null) debugPrint('   Reason: $reason');

      final id = await _reminderService.scheduleReminder(
        title: title,
        body: body,
        scheduledTime: scheduledTime,
        repeat: repeat,
        category: category,
        alertType: alertType,
        createdBy: 'ai',
        metadata: weekdays != null ? {'weekdays': weekdays} : {},
      );

      debugPrint('✅ [AI Actions] Reminder created successfully! ID: $id');

      return {
        'success': true,
        'reminder_id': id,
        'message': 'Reminder created successfully',
        'reminder': {
          'title': title,
          'scheduled_time': scheduledTime.toIso8601String(),
          'repeat': repeat,
          'alert_type': alertType,
        },
      };
    } catch (e) {
      debugPrint('❌ [AI Actions] Failed to create reminder: $e');
      debugPrint('   Stack trace: ${StackTrace.current}');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// AI can edit a reminder
  Future<Map<String, dynamic>> editReminder({
    required String reminderId,
    String? title,
    String? body,
    DateTime? scheduledTime,
    String? repeat,
    String? category,
    String? alertType,
    List<int>? weekdays,
    String? reason,
  }) async {
    try {
      final reminders = await _reminderService.getAllReminders();
      final reminder = reminders.firstWhere((r) => r.id == reminderId);

      if (title != null) reminder.title = title;
      if (body != null) reminder.body = body;
      if (scheduledTime != null) reminder.scheduledTime = scheduledTime;
      if (repeat != null) reminder.repeat = repeat;
      if (category != null) reminder.category = category;
      if (alertType != null) reminder.alertType = alertType;
      if (weekdays != null) reminder.metadata['weekdays'] = weekdays;

      await _reminderService.updateReminder(reminder);

      debugPrint('✅ AI edited reminder: $reminderId');
      if (reason != null) debugPrint('   Reason: $reason');

      return {
        'success': true,
        'reminder_id': reminderId,
        'message': 'Reminder updated successfully',
      };
    } catch (e) {
      debugPrint('❌ AI failed to edit reminder: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// AI can delete a reminder
  Future<Map<String, dynamic>> deleteReminder({
    required String reminderId,
    String? reason,
  }) async {
    try {
      await _reminderService.deleteReminder(reminderId);

      debugPrint('✅ AI deleted reminder: $reminderId');
      if (reason != null) debugPrint('   Reason: $reason');

      return {
        'success': true,
        'reminder_id': reminderId,
        'message': 'Reminder deleted successfully',
      };
    } catch (e) {
      debugPrint('❌ AI failed to delete reminder: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// AI can get all reminders
  Future<List<Map<String, dynamic>>> getAllReminders() async {
    try {
      final reminders = await _reminderService.getAllReminders();
      return reminders
          .map((r) => {
                'id': r.id,
                'title': r.title,
                'body': r.body,
                'scheduled_time': r.scheduledTime.toIso8601String(),
                'repeat': r.repeat,
                'category': r.category,
                'alert_type': r.alertType,
                'is_active': r.isActive,
                'created_by': r.createdBy,
                'created_at': r.createdAt.toIso8601String(),
              })
          .toList();
    } catch (e) {
      debugPrint('❌ AI failed to get reminders: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DATA MONITORING (Read-only access to all screens)
  // ═══════════════════════════════════════════════════════════════════════════

  /// AI can monitor workout/activity data
  Future<Map<String, dynamic>> monitorWorkoutData({
    int days = 7,
  }) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final activities = <Map<String, dynamic>>[];

      for (int i = 0; i < days; i++) {
        final date = today.subtract(Duration(days: i));
        final dayActivities = await _storage.getActivitiesForDate(date);

        for (final activity in dayActivities) {
          activities.add({
            'date': date.toIso8601String(),
            'type': activity.activityType,
            'duration_minutes': activity.durationMinutes,
            'calories_burned': activity.caloriesBurned,
            'distance_km': activity.distanceKm,
            'created_at': activity.createdAt.toIso8601String(),
          });
        }
      }

      final totalCalories = activities.fold<int>(
        0,
        (sum, a) => sum + (a['calories_burned'] as int),
      );
      final totalDuration = activities.fold<int>(
        0,
        (sum, a) => sum + (a['duration_minutes'] as int),
      );

      return {
        'success': true,
        'days': days,
        'total_activities': activities.length,
        'total_calories_burned': totalCalories,
        'total_duration_minutes': totalDuration,
        'activities': activities,
      };
    } catch (e) {
      debugPrint('❌ AI failed to monitor workout data: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// AI can monitor water intake data
  Future<Map<String, dynamic>> monitorWaterData({
    int days = 7,
  }) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final waterData = <Map<String, dynamic>>[];

      for (int i = 0; i < days; i++) {
        final date = today.subtract(Duration(days: i));
        final totalMl = await _storage.getWaterForDate(date);

        waterData.add({
          'date': date.toIso8601String(),
          'total_ml': totalMl,
        });
      }

      final totalWater = waterData.fold<int>(
        0,
        (sum, d) => sum + (d['total_ml'] as int),
      );
      final avgDaily = (totalWater / days).round();

      return {
        'success': true,
        'days': days,
        'total_water_ml': totalWater,
        'average_daily_ml': avgDaily,
        'daily_data': waterData,
      };
    } catch (e) {
      debugPrint('❌ AI failed to monitor water data: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// AI can monitor user profile changes
  Future<Map<String, dynamic>> monitorProfile() async {
    try {
      final profileJson = await _storage.getUserProfile();
      final profile = profileJson != null
          ? UserProfile.fromJson(profileJson)
          : UserProfile.defaultProfile();

      return {
        'success': true,
        'profile': {
          'name': profile.name,
          'age': profile.age,
          'gender': profile.gender,
          'height_cm': profile.heightCm,
          'weight_kg': profile.weightKg,
          'activity_level': profile.activityLevel,
          'goal': profile.goal,
          'target_weight_kg': profile.targetWeightKg,
          'goal_start_date': profile.goalStartDate?.toIso8601String(),
          'goal_end_date': profile.goalEndDate?.toIso8601String(),
        },
      };
    } catch (e) {
      debugPrint('❌ AI failed to monitor profile: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// AI can get comprehensive dashboard data
  Future<Map<String, dynamic>> getFullDashboard() async {
    try {
      final workoutData = await monitorWorkoutData(days: 7);
      final waterData = await monitorWaterData(days: 7);
      final profileData = await monitorProfile();
      final goals = await getAllGoals();
      final reminders = await getAllReminders();

      return {
        'success': true,
        'timestamp': DateTime.now().toIso8601String(),
        'profile': profileData['profile'],
        'workouts': workoutData,
        'water': waterData,
        'goals': goals,
        'reminders': reminders,
      };
    } catch (e) {
      debugPrint('❌ AI failed to get full dashboard: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LOGGING ACTIONS — AI can log data directly
// ═══════════════════════════════════════════════════════════════════════════

extension AIActionsLogging on AIActionsService {
  /// AI logs water intake for the user
  Future<Map<String, dynamic>> logWater({
    required int amountMl,
    String? reason,
  }) async {
    try {
      final settings = await _storage.getAppSettings() ?? {};
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final key = 'water_$today';
      final current = settings[key] as int? ?? 0;
      settings[key] = current + amountMl;
      await _storage.saveAppSettings(settings);
      debugPrint(
          '✅ AI logged ${amountMl}ml water. Total today: ${current + amountMl}ml');
      return {
        'success': true,
        'logged_ml': amountMl,
        'total_today_ml': current + amountMl,
        'message': 'Logged ${amountMl}ml of water',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// AI logs a meal for the user
  Future<Map<String, dynamic>> logMeal({
    required String mealName,
    required int calories,
    String mealType = 'meal', // breakfast, lunch, dinner, snack
    int? proteinG,
    int? carbsG,
    int? fatG,
    String? reason,
  }) async {
    try {
      final settings = await _storage.getAppSettings() ?? {};
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final key = 'meals_$today';
      final meals =
          (settings[key] as List?)?.cast<Map<String, dynamic>>() ?? [];
      meals.add({
        'name': mealName,
        'calories': calories,
        'type': mealType,
        'protein': proteinG,
        'carbs': carbsG,
        'fat': fatG,
        'logged_at': DateTime.now().toIso8601String(),
        'logged_by': 'ai',
      });
      settings[key] = meals;
      await _storage.saveAppSettings(settings);
      final totalCals =
          meals.fold<int>(0, (sum, m) => sum + (m['calories'] as int? ?? 0));
      debugPrint(
          '✅ AI logged meal: $mealName ($calories kcal). Total today: ${totalCals}kcal');
      return {
        'success': true,
        'meal': mealName,
        'calories': calories,
        'total_calories_today': totalCals,
        'message': 'Logged $mealName ($calories kcal)',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// AI logs a workout session
  Future<Map<String, dynamic>> logWorkout({
    required String workoutType,
    required int durationMinutes,
    int? caloriesBurned,
    String? notes,
    String? reason,
  }) async {
    try {
      final settings = await _storage.getAppSettings() ?? {};
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final key = 'workouts_$today';
      final workouts =
          (settings[key] as List?)?.cast<Map<String, dynamic>>() ?? [];
      workouts.add({
        'type': workoutType,
        'duration_minutes': durationMinutes,
        'calories_burned': caloriesBurned,
        'notes': notes,
        'logged_at': DateTime.now().toIso8601String(),
        'logged_by': 'ai',
      });
      settings[key] = workouts;
      await _storage.saveAppSettings(settings);
      debugPrint('✅ AI logged workout: $workoutType ${durationMinutes}min');
      return {
        'success': true,
        'workout': workoutType,
        'duration_minutes': durationMinutes,
        'calories_burned': caloriesBurned,
        'message': 'Logged $workoutType workout ($durationMinutes min)',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// AI updates user profile (weight, goals, etc.)
  Future<Map<String, dynamic>> updateProfile({
    double? weightKg,
    double? heightCm,
    int? age,
    String? goal, // lose_weight, gain_muscle, maintain
    String? activityLevel,
    String? reason,
  }) async {
    try {
      final profileJson = await _storage.getUserProfile();
      final profile = profileJson != null
          ? UserProfile.fromJson(profileJson)
          : UserProfile.defaultProfile();

      if (weightKg != null) profile.weightKg = weightKg;
      if (heightCm != null) profile.heightCm = heightCm;
      if (age != null) profile.age = age;
      if (goal != null) profile.goal = goal;
      if (activityLevel != null) {
        // Map string activity level to int (1-5)
        final levelMap = {
          'sedentary': 1,
          'light': 2,
          'moderate': 3,
          'active': 4,
          'very_active': 5,
        };
        profile.activityLevel =
            levelMap[activityLevel] ?? profile.activityLevel;
      }

      await _storage.saveUserProfile(profile.toJson());
      debugPrint('✅ AI updated profile');
      return {
        'success': true,
        'message': 'Profile updated successfully',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
