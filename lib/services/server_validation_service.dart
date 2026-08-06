import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Server Validation Service
/// 
/// Calls Firebase Functions for server-side validation and calculations
/// This ensures accuracy and prevents client-side manipulation
class ServerValidationService {
  static final ServerValidationService instance = ServerValidationService._internal();
  factory ServerValidationService() => instance;
  ServerValidationService._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Calculate daily calorie needs (BMR + TDEE) on server
  Future<Map<String, dynamic>> calculateDailyCalories({
    required double weightKg,
    required double heightCm,
    required int age,
    required String gender, // 'male', 'female', 'other'
    required String activityLevel, // 'sedentary', 'light', 'moderate', 'active', 'very_active'
  }) async {
    try {
      final result = await _functions.httpsCallable('calculateDailyCalories').call({
        'weightKg': weightKg,
        'heightCm': heightCm,
        'age': age,
        'gender': gender,
        'activityLevel': activityLevel,
      });

      debugPrint('✅ Server calculated calories: ${result.data}');
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('❌ Failed to calculate calories: $e');
      rethrow;
    }
  }

  /// Calculate workout calories burned on server (more accurate)
  Future<Map<String, dynamic>> calculateWorkoutCalories({
    required double weightKg,
    required int durationMinutes,
    required String activityType, // 'cardio', 'strength', 'yoga', 'hiit', 'walking', 'running', 'cycling'
    required String intensity, // 'low', 'moderate', 'high'
    Map<String, dynamic>? movementData,
  }) async {
    try {
      final result = await _functions.httpsCallable('calculateWorkoutCalories').call({
        'weightKg': weightKg,
        'durationMinutes': durationMinutes,
        'activityType': activityType,
        'intensity': intensity,
        if (movementData != null) 'movementData': movementData,
      });

      debugPrint('✅ Server calculated workout calories: ${result.data}');
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('❌ Failed to calculate workout calories: $e');
      rethrow;
    }
  }

  /// Validate and save activity on server (prevents manipulation)
  Future<Map<String, dynamic>> validateAndSaveActivity({
    required String type, // 'workout', 'meal', 'water'
    required double value,
    required String unit,
    String? note,
    required DateTime timestamp,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final result = await _functions.httpsCallable('validateAndSaveActivity').call({
        'type': type,
        'value': value,
        'unit': unit,
        if (note != null) 'note': note,
        'timestamp': timestamp.millisecondsSinceEpoch,
        if (metadata != null) 'metadata': metadata,
      });

      debugPrint('✅ Activity validated and saved: ${result.data}');
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('❌ Failed to validate activity: $e');
      rethrow;
    }
  }

  /// Get user statistics from server (accurate calculations)
  Future<Map<String, dynamic>> getUserStatistics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final result = await _functions.httpsCallable('getUserStatistics').call({
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      });

      debugPrint('✅ Server calculated statistics: ${result.data}');
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('❌ Failed to get statistics: $e');
      rethrow;
    }
  }

  /// Verify subscription status on server (source of truth)
  Future<Map<String, dynamic>> verifySubscription() async {
    try {
      final result = await _functions.httpsCallable('verifySubscription').call();

      debugPrint('✅ Subscription verified: ${result.data}');
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('❌ Failed to verify subscription: $e');
      rethrow;
    }
  }

  /// Check if user can access a specific feature
  Future<Map<String, dynamic>> checkFeatureAccess(String feature) async {
    try {
      final result = await _functions.httpsCallable('checkFeatureAccess').call({
        'feature': feature,
      });

      debugPrint('✅ Feature access checked: ${result.data}');
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('❌ Failed to check feature access: $e');
      rethrow;
    }
  }

  /// Track AI usage (token counting)
  Future<Map<String, dynamic>> trackAIUsage({
    required String feature,
    required int tokensUsed,
    required String model,
  }) async {
    try {
      final result = await _functions.httpsCallable('trackAIUsage').call({
        'feature': feature,
        'tokensUsed': tokensUsed,
        'model': model,
      });

      debugPrint('✅ AI usage tracked: ${result.data}');
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('❌ Failed to track AI usage: $e');
      rethrow;
    }
  }

  /// Get AI usage statistics
  Future<Map<String, dynamic>> getAIUsageStats({int days = 30}) async {
    try {
      final result = await _functions.httpsCallable('getAIUsageStats').call({
        'days': days,
      });

      debugPrint('✅ AI usage stats retrieved: ${result.data}');
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      debugPrint('❌ Failed to get AI usage stats: $e');
      rethrow;
    }
  }
}
