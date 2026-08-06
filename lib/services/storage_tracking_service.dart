import 'package:flutter/material.dart';
import 'local_storage_service.dart';

/// Service to track cloud storage usage for user data
/// Different tiers have different storage limits:
/// - Free: 500MB
/// - Pro: 5GB
/// - Elite: 20GB
/// - Lifetime: 50GB
class StorageTrackingService extends ChangeNotifier {
  StorageTrackingService._();
  static final StorageTrackingService instance = StorageTrackingService._();

  int _usedBytes = 0;
  bool _loaded = false;

  // Storage limits by tier (in bytes)
  static const int freeTierLimit = 500 * 1024 * 1024; // 500MB
  static const int proTierLimit = 5 * 1024 * 1024 * 1024; // 5GB
  static const int eliteTierLimit = 20 * 1024 * 1024 * 1024; // 20GB
  static const int lifetimeTierLimit = 50 * 1024 * 1024 * 1024; // 50GB

  int get usedBytes => _usedBytes;
  double get usedMB => _usedBytes / (1024 * 1024);
  double get usedGB => _usedBytes / (1024 * 1024 * 1024);

  /// All users get 5GB storage
  int get limitBytes => proTierLimit;

  double get limitMB => limitBytes / (1024 * 1024);
  double get limitGB => limitBytes / (1024 * 1024 * 1024);

  String get tierLabel => 'Cloud Storage (5GB)';

  /// Get usage percentage (0.0 to 1.0)
  double get usagePercent => _usedBytes / limitBytes;

  /// Check if user has enough storage space
  bool hasSpace(int bytesNeeded) {
    return (_usedBytes + bytesNeeded) <= limitBytes;
  }

  /// Get remaining storage in bytes
  int get remainingBytes => limitBytes - _usedBytes;
  double get remainingMB => remainingBytes / (1024 * 1024);
  double get remainingGB => remainingBytes / (1024 * 1024 * 1024);

  /// Get formatted storage usage string
  String get usageString {
    if (limitGB >= 1) {
      return '${usedGB.toStringAsFixed(2)} GB / ${limitGB.toStringAsFixed(0)} GB';
    } else {
      return '${usedMB.toStringAsFixed(0)} MB / ${limitMB.toStringAsFixed(0)} MB';
    }
  }

  /// Get formatted remaining storage string
  String get remainingString {
    if (remainingGB >= 1) {
      return '${remainingGB.toStringAsFixed(2)} GB remaining';
    } else {
      return '${remainingMB.toStringAsFixed(0)} MB remaining';
    }
  }

  /// Load storage usage from local storage
  Future<void> load({bool force = false}) async {
    if (_loaded && !force) {
      debugPrint('💾 Storage already loaded, skipping');
      return;
    }

    final settings = await LocalStorageService.instance.getAppSettings();
    _usedBytes = settings?['storage_used_bytes'] as int? ?? 0;
    _loaded = true;
    notifyListeners();
    debugPrint('💾 Storage loaded: ${usageString}');
  }

  /// Add storage usage (e.g., when uploading a photo)
  Future<bool> addUsage(int bytes, {String? description}) async {
    if (!hasSpace(bytes)) {
      debugPrint('❌ Insufficient storage. Need: ${_formatBytes(bytes)}, Available: ${_formatBytes(remainingBytes)}');
      return false;
    }

    _usedBytes += bytes;
    await _saveUsage();
    notifyListeners();
    debugPrint('💾 Added ${_formatBytes(bytes)} storage${description != null ? ' ($description)' : ''}. Total: ${usageString}');
    return true;
  }

  /// Remove storage usage (e.g., when deleting a photo)
  Future<void> removeUsage(int bytes, {String? description}) async {
    _usedBytes = (_usedBytes - bytes).clamp(0, limitBytes);
    await _saveUsage();
    notifyListeners();
    debugPrint('💾 Removed ${_formatBytes(bytes)} storage${description != null ? ' ($description)' : ''}. Total: ${usageString}');
  }

  /// Save storage usage to local storage
  Future<void> _saveUsage() async {
    final settings = await LocalStorageService.instance.getAppSettings() ?? {};
    settings['storage_used_bytes'] = _usedBytes;
    await LocalStorageService.instance.saveAppSettings(settings);
  }

  /// Clear storage usage (sign-out)
  Future<void> clear() async {
    _usedBytes = 0;
    await _saveUsage();
    notifyListeners();
  }

  /// Format bytes to human-readable string
  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } else if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else {
      return '$bytes bytes';
    }
  }

  /// Estimate storage usage for different data types
  static const int avgMealPhotoSize = 2 * 1024 * 1024; // 2MB per photo
  static const int avgWorkoutDataSize = 50 * 1024; // 50KB per workout
  static const int avgActivityDataSize = 10 * 1024; // 10KB per activity
  static const int avgChatMessageSize = 1 * 1024; // 1KB per message

  /// Check if user can upload a meal photo
  bool canUploadMealPhoto() {
    return hasSpace(avgMealPhotoSize);
  }

  /// Check if user can save workout data
  bool canSaveWorkout() {
    return hasSpace(avgWorkoutDataSize);
  }

  /// Get warning level (0 = ok, 1 = warning, 2 = critical)
  int get warningLevel {
    if (usagePercent >= 0.95) return 2; // Critical (95%+)
    if (usagePercent >= 0.80) return 1; // Warning (80%+)
    return 0; // OK
  }

  /// Get warning message
  String? get warningMessage {
    switch (warningLevel) {
      case 2:
        return 'Storage almost full! Upgrade to get more space.';
      case 1:
        return 'Storage running low. Consider upgrading your plan.';
      default:
        return null;
    }
  }

  /// Get color for storage indicator
  Color get indicatorColor {
    switch (warningLevel) {
      case 2:
        return const Color(0xFFFF6584); // Red
      case 1:
        return const Color(0xFFFFB74D); // Orange
      default:
        return const Color(0xFF66BB6A); // Green
    }
  }
}
