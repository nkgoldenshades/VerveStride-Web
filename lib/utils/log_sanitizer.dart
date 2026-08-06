import 'package:flutter/foundation.dart';

/// Utility class for sanitizing sensitive data before logging
class LogSanitizer {
  /// Sanitize user profile data for logging
  static Map<String, dynamic> sanitizeProfile(Map<String, dynamic> profile) {
    if (kReleaseMode) {
      return {
        'hasName': profile['name'] != null,
        'hasEmail': profile['email'] != null,
        'hasAge': profile['age'] != null,
        'hasWeight': profile['weight'] != null,
        'hasHeight': profile['height'] != null,
      };
    }
    
    // In debug mode, show partial data
    return {
      'name': profile['name'] != null ? '***' : null,
      'email': _maskEmail(profile['email']),
      'age': profile['age'],
      'weight': profile['weight'],
      'height': profile['height'],
      'gender': profile['gender'],
    };
  }

  /// Sanitize app settings for logging
  static Map<String, dynamic> sanitizeSettings(Map<String, dynamic> settings) {
    if (kReleaseMode) {
      return {
        'hasSubscription': settings['subscription_plan_key'] != null,
        'isPremium': settings['is_premium'] ?? false,
        'hasCredits': settings['ai_credits'] != null,
      };
    }
    
    // In debug mode, show structure but not values
    return {
      'subscription_plan_key': settings['subscription_plan_key'] != null ? '***' : null,
      'is_premium': settings['is_premium'],
      'ad_free': settings['ad_free'],
      'ai_credits': settings['ai_credits'],
      'theme': settings['theme'],
      'notifications_enabled': settings['notifications_enabled'],
      // Don't log: reminders, chat history, personal data
    };
  }

  /// Sanitize chat messages for logging
  static Map<String, dynamic> sanitizeMessage(Map<String, dynamic> message) {
    if (kReleaseMode) {
      return {
        'role': message['role'],
        'hasContent': message['content'] != null,
        'timestamp': message['timestamp'],
      };
    }
    
    // In debug mode, show truncated content
    final content = message['content']?.toString() ?? '';
    return {
      'role': message['role'],
      'contentLength': content.length,
      'contentPreview': content.length > 50 ? '${content.substring(0, 50)}...' : content,
      'timestamp': message['timestamp'],
    };
  }

  /// Sanitize Firebase user data
  static Map<String, dynamic> sanitizeUser(dynamic user) {
    if (user == null) return {'authenticated': false};
    
    if (kReleaseMode) {
      return {
        'authenticated': true,
        'hasEmail': true,
      };
    }
    
    // In debug mode, show partial info
    return {
      'authenticated': true,
      'email': _maskEmail(user.email),
      'emailVerified': user.emailVerified,
      'isAnonymous': user.isAnonymous,
    };
  }

  /// Sanitize error messages
  static String sanitizeError(dynamic error) {
    if (error == null) return 'Unknown error';
    
    String errorStr = error.toString();
    
    // Remove sensitive paths
    errorStr = errorStr.replaceAll(RegExp(r'[A-Z]:\\[^:]+'), '***PATH***');
    errorStr = errorStr.replaceAll(RegExp(r'/Users/[^/]+'), '***PATH***');
    errorStr = errorStr.replaceAll(RegExp(r'/home/[^/]+'), '***PATH***');
    
    // Remove UIDs
    errorStr = errorStr.replaceAllMapped(
      RegExp(r'\b[A-Za-z0-9]{20,}\b'),
      (match) => '***ID***',
    );
    
    return errorStr;
  }

  /// Sanitize credits/payment info
  static Map<String, dynamic> sanitizeCredits(Map<String, dynamic> data) {
    if (kReleaseMode) {
      return {
        'hasCredits': data['credits'] != null && (data['credits'] as num) > 0,
      };
    }
    
    return {
      'credits': data['credits'],
      'lastUpdated': data['lastUpdated'],
    };
  }

  /// Mask email addresses
  static String? _maskEmail(dynamic email) {
    if (email == null) return null;
    final emailStr = email.toString();
    if (!emailStr.contains('@')) return '***';
    
    final parts = emailStr.split('@');
    final username = parts[0];
    final domain = parts[1];
    
    if (username.length <= 2) {
      return '***@$domain';
    }
    
    return '${username[0]}***${username[username.length - 1]}@$domain';
  }

  /// Sanitize storage dump (the most dangerous one!)
  static String sanitizeStorageDump(Map<String, dynamic> storage) {
    if (kReleaseMode) {
      return 'Storage keys: ${storage.keys.join(", ")}';
    }
    
    // In debug mode, show structure only
    final sanitized = <String, dynamic>{};
    for (final key in storage.keys) {
      final value = storage[key];
      if (value is Map) {
        sanitized[key] = '{Map with ${value.length} keys}';
      } else if (value is List) {
        sanitized[key] = '[List with ${value.length} items]';
      } else if (value is String && value.length > 50) {
        sanitized[key] = '${value.substring(0, 20)}... (${value.length} chars)';
      } else {
        sanitized[key] = value?.runtimeType.toString() ?? 'null';
      }
    }
    
    return sanitized.toString();
  }
}
