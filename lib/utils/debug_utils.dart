import 'package:flutter/foundation.dart';
import 'secure_logger.dart';

/// Utility functions for safe debugging
class DebugUtils {
  /// Only execute in debug mode
  static void debugOnly(VoidCallback callback) {
    if (kDebugMode) {
      callback();
    }
  }

  /// Log only in debug mode
  static void debugLog(String message) {
    if (kDebugMode) {
      logger.d(message);
    }
  }

  /// Assert in debug mode, log error in release
  static void debugAssert(bool condition, String message) {
    if (kDebugMode) {
      assert(condition, message);
    } else if (!condition) {
      logger.e('Assertion failed: $message');
    }
  }

  /// Measure performance only in debug mode
  static Future<T> measurePerformance<T>(
    String label,
    Future<T> Function() operation,
  ) async {
    if (!kDebugMode) {
      return operation();
    }

    final stopwatch = Stopwatch()..start();
    try {
      final result = await operation();
      stopwatch.stop();
      logger.d('⏱️ $label took ${stopwatch.elapsedMilliseconds}ms');
      return result;
    } catch (e) {
      stopwatch.stop();
      logger.e('⏱️ $label failed after ${stopwatch.elapsedMilliseconds}ms', e);
      rethrow;
    }
  }

  /// Safe toString that won't expose sensitive data
  static String safeToString(dynamic object) {
    if (object == null) return 'null';
    
    if (kReleaseMode) {
      return object.runtimeType.toString();
    }
    
    // In debug mode, show limited info
    if (object is Map) {
      return 'Map<${object.runtimeType}>(${object.length} entries)';
    } else if (object is List) {
      return 'List<${object.runtimeType}>(${object.length} items)';
    } else if (object is String && object.length > 100) {
      return '${object.substring(0, 100)}... (${object.length} chars)';
    }
    
    return object.toString();
  }
}
