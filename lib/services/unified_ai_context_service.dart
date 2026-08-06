import 'package:flutter/foundation.dart';
import 'local_storage_service.dart';
import 'user_subscription_service.dart';
import '../models/user_profile.dart';

/// Unified AI Context Service
/// 
/// Gathers ALL user data into a single context that the AI can reference.
/// This enables the AI to:
/// - Know your profile (age, weight, goals)
/// - Reference your workout history
/// - Consider your meal logs
/// - Track your water intake
/// - Understand your sleep patterns
/// - Provide personalized coaching based on complete context
class UnifiedAIContextService {
  static final UnifiedAIContextService instance = UnifiedAIContextService._internal();
  factory UnifiedAIContextService() => instance;
  UnifiedAIContextService._internal();

  final LocalStorageService _storage = LocalStorageService.instance;

  /// Build complete user context for AI
  /// This is the "brain" of the AI - everything it knows about you
  Future<Map<String, dynamic>> buildUserContext({
    bool includeHistory = true,
    int historyDays = 7,
  }) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // 1. User Profile (who you are)
      final profileJson = await _storage.getUserProfile();
      final profile = profileJson != null ? UserProfile.fromJson(profileJson) : null;

      // 2. Subscription Status (what features you have)
      final sub = UserSubscriptionService.instance;
      await sub.load(force: true);

      // 3. Today's Activities (what you've done today)
      final todayActivities = await _storage.getActivitiesForDate(today);
      final todayCaloriesBurned = todayActivities.fold<int>(0, (sum, a) => sum + a.caloriesBurned);
      final todayDurationMinutes = todayActivities.fold<int>(0, (sum, a) => sum + a.durationMinutes);
      
      // 4. Recent History (your patterns)
      final recentActivities = <Map<String, dynamic>>[];
      if (includeHistory) {
        for (int i = 1; i <= historyDays; i++) {
          final date = today.subtract(Duration(days: i));
          final activities = await _storage.getActivitiesForDate(date);
          for (final activity in activities) {
            recentActivities.add({
              'date': date.toIso8601String(),
              'type': activity.activityType,
              'duration_minutes': activity.durationMinutes,
              'calories': activity.caloriesBurned,
              'distance_km': activity.distanceKm,
            });
          }
        }
      }

      // 5. Water Intake (hydration tracking)
      final totalWaterToday = await _storage.getWaterForDate(today);
      
      final waterHistory = <Map<String, dynamic>>[];
      if (includeHistory) {
        for (int i = 1; i <= historyDays; i++) {
          final date = today.subtract(Duration(days: i));
          final totalMl = await _storage.getWaterForDate(date);
          waterHistory.add({
            'date': date.toIso8601String(),
            'total_ml': totalMl,
          });
        }
      }

      // 6. App Settings & Preferences
      final settings = await _storage.getAppSettings() ?? {};

      // 7. AI Chat History (conversation memory)
      final chatHistory = await _storage.getAIChatHistory();

      // 8. Calculate daily targets from profile
      final dailyTargets = profile?.calculateDailyTargets() ?? {
        'dailyCalories': 2000,
        'waterMl': 3000,
      };

      // Build comprehensive context
      final context = <String, dynamic>{
        // === USER IDENTITY ===
        'user_profile': {
          'name': profile?.name ?? 'User',
          'age': profile?.age ?? 30,
          'gender': profile?.gender ?? 'not_specified',
          'height_cm': profile?.heightCm ?? 170,
          'weight_kg': profile?.weightKg ?? 70,
          'activity_level': profile?.activityLevel ?? 3,
          'goal': profile?.goal ?? 'maintain',
          'target_weight_kg': profile?.targetWeightKg ?? 0,
        },

        // === SUBSCRIPTION & FEATURES ===
        'subscription': {
          'tier': sub.isPro ? 'pro' : (sub.isElite ? 'elite' : (sub.isLifetime ? 'lifetime' : 'free')),
          'is_pro': sub.isPro,
          'is_elite': sub.isElite,
          'is_lifetime': sub.isLifetime,
          'expires_at': sub.expiresAt?.toIso8601String(),
          'ai_meal_analysis_limit': sub.aiMealAnalysisLimit,
        },

        // === TODAY'S ACTIVITY ===
        'today': {
          'date': today.toIso8601String(),
          'activities': todayActivities.map((a) => {
            'type': a.activityType,
            'duration_minutes': a.durationMinutes,
            'calories_burned': a.caloriesBurned,
            'distance_km': a.distanceKm,
            'created_at': a.createdAt.toIso8601String(),
          }).toList(),
          'total_calories_burned': todayCaloriesBurned,
          'total_duration_minutes': todayDurationMinutes,
          'water_intake_ml': totalWaterToday,
        },

        // === RECENT HISTORY (patterns & trends) ===
        if (includeHistory) 'history': {
          'days': historyDays,
          'activities': recentActivities,
          'water_intake': waterHistory,
          'total_workouts': recentActivities.where((a) => a['type'] == 'workout').toList().length,
          'total_calories_burned': recentActivities.fold<int>(
            0, 
            (sum, a) => sum + (a['calories'] as int? ?? 0),
          ),
          'average_daily_calories': recentActivities.isEmpty 
            ? 0 
            : (recentActivities.fold<int>(0, (sum, a) => sum + (a['calories'] as int? ?? 0)) / historyDays).round(),
        },

        // === GOALS & TARGETS ===
        'goals': {
          'daily_calorie_target': dailyTargets['dailyCalories'] ?? 2000,
          'daily_water_target_ml': dailyTargets['waterMl'] ?? 3000,
          'weight_goal': profile?.goal ?? 'maintain',
          'target_weight_kg': profile?.targetWeightKg ?? 0,
        },

        // === AI SETTINGS ===
        'ai_settings': {
          'photo_analysis_enabled': settings['photo_analysis_enabled'] ?? true,
          'conversational_ai_enabled': settings['conversational_ai_enabled'] ?? true,
          'data_analytics_enabled': settings['data_analytics_enabled'] ?? true,
        },

        // === CONVERSATION MEMORY ===
        'chat_history': chatHistory.take(20).toList(), // Last 20 messages

        // === METADATA ===
        'context_generated_at': DateTime.now().toIso8601String(),
        'context_version': '1.0',
      };

      if (kDebugMode) {
        final tier = sub.isPro ? 'pro' : (sub.isElite ? 'elite' : (sub.isLifetime ? 'lifetime' : 'free'));
        debugPrint('🧠 AI Context Built:');
        debugPrint('  Profile: ${profile?.name ?? "Unknown"}, ${profile?.age ?? 0}y, ${profile?.weightKg ?? 0}kg');
        debugPrint('  Subscription: $tier');
        debugPrint('  Today: ${todayActivities.length} activities, ${totalWaterToday}ml water');
        debugPrint('  History: ${recentActivities.length} activities over $historyDays days');
      }

      return context;
    } catch (e) {
      debugPrint('❌ Error building AI context: $e');
      return _getMinimalContext();
    }
  }

  /// Build a minimal context if full context fails
  Map<String, dynamic> _getMinimalContext() {
    return {
      'user_profile': {
        'name': 'User',
        'age': 30,
        'gender': 'not_specified',
        'weight_kg': 70,
      },
      'subscription': {
        'tier': 'free',
        'is_pro': false,
        'is_elite': false,
      },
      'today': {
        'date': DateTime.now().toIso8601String(),
        'activities': [],
        'total_calories_burned': 0,
        'water_intake_ml': 0,
      },
      'context_generated_at': DateTime.now().toIso8601String(),
      'error': 'Failed to load full context',
    };
  }

  /// Generate a natural language summary of user context for AI system prompt
  Future<String> buildContextSummary({int historyDays = 7}) async {
    final context = await buildUserContext(includeHistory: true, historyDays: historyDays);
    
    final profile = context['user_profile'] as Map<String, dynamic>;
    final today = context['today'] as Map<String, dynamic>;
    final subscription = context['subscription'] as Map<String, dynamic>;
    final goals = context['goals'] as Map<String, dynamic>;
    final history = context['history'] as Map<String, dynamic>?;

    final summary = StringBuffer();
    
    // User Identity
    summary.writeln('USER PROFILE:');
    summary.writeln('- Name: ${profile['name']}');
    summary.writeln('- Age: ${profile['age']} years, Gender: ${profile['gender']}');
    summary.writeln('- Weight: ${profile['weight_kg']} kg, Height: ${profile['height_cm']} cm');
    summary.writeln('- Goal: ${profile['goal']}');
    if ((profile['target_weight_kg'] as num) > 0) {
      summary.writeln('- Target Weight: ${profile['target_weight_kg']} kg');
    }
    summary.writeln('');

    // Subscription
    final tier = subscription['tier'] as String? ?? 'free';
    summary.writeln('SUBSCRIPTION: $tier tier');
    summary.writeln('');

    // Today's Activity
    summary.writeln('TODAY (${today['date']}):');
    final todayActivities = today['activities'] as List;
    if (todayActivities.isEmpty) {
      summary.writeln('- No activities logged yet');
    } else {
      summary.writeln('- ${todayActivities.length} activities logged');
      summary.writeln('- Total calories burned: ${today['total_calories_burned']} kcal');
      summary.writeln('- Total duration: ${today['total_duration_minutes']} minutes');
    }
    summary.writeln('- Water intake: ${today['water_intake_ml']} ml / ${goals['daily_water_target_ml']} ml goal');
    summary.writeln('');

    // Recent History
    if (history != null) {
      final totalWorkouts = history['total_workouts'] as int? ?? 0;
      final totalCalories = history['total_calories_burned'] as int? ?? 0;
      final avgCalories = history['average_daily_calories'] as int? ?? 0;
      final days = history['days'] as int? ?? 0;
      
      summary.writeln('RECENT HISTORY (last $days days):');
      summary.writeln('- Total workouts: $totalWorkouts');
      summary.writeln('- Total calories burned: $totalCalories kcal');
      summary.writeln('- Average daily calories: $avgCalories kcal');
      summary.writeln('');
    }

    // Goals
    summary.writeln('DAILY GOALS:');
    summary.writeln('- Calorie target: ${goals['daily_calorie_target']} kcal');
    summary.writeln('- Water target: ${goals['daily_water_target_ml']} ml');
    summary.writeln('');

    return summary.toString();
  }

  /// Get context for a specific feature (optimized for that use case)
  Future<Map<String, dynamic>> getContextForFeature(String feature) async {
    final fullContext = await buildUserContext(includeHistory: true, historyDays: 7);

    switch (feature) {
      case 'meal_analysis':
        // For meal analysis, focus on nutrition goals and recent meals
        return {
          'user_profile': fullContext['user_profile'],
          'goals': fullContext['goals'],
          'today': fullContext['today'],
          'subscription': fullContext['subscription'],
        };

      case 'workout_coaching':
        // For workout coaching, focus on fitness level and recent workouts
        return {
          'user_profile': fullContext['user_profile'],
          'today': fullContext['today'],
          'history': fullContext['history'],
          'subscription': fullContext['subscription'],
        };

      case 'chat':
        // For chat, include everything
        return fullContext;

      case 'insights':
        // For insights, focus on patterns and trends
        return {
          'user_profile': fullContext['user_profile'],
          'today': fullContext['today'],
          'history': fullContext['history'],
          'goals': fullContext['goals'],
        };

      default:
        return fullContext;
    }
  }

  /// Clear cached context (call when user data changes significantly)
  void invalidateContext() {
    debugPrint('🔄 AI context invalidated - will rebuild on next request');
    // Future: implement caching here if needed
  }
}
