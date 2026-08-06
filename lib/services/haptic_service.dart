import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Centralized haptic feedback service
/// Provides tactile responses for mobile interactions
class HapticService {
  HapticService._();
  static final HapticService instance = HapticService._();

  // Haptic settings
  bool _enabled = true;

  bool get isEnabled => _enabled;
  set enabled(bool value) => _enabled = value;

  /// Light impact - subtle feedback for minor interactions
  Future<void> light() async {
    if (!_enabled || kIsWeb) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {
      // Silently fail if haptics not supported
    }
  }

  /// Medium impact - standard feedback for button taps
  Future<void> medium() async {
    if (!_enabled || kIsWeb) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Heavy impact - strong feedback for important actions
  Future<void> heavy() async {
    if (!_enabled || kIsWeb) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Selection - feedback for selecting items
  Future<void> selection() async {
    if (!_enabled || kIsWeb) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Success - celebration feedback for achievements
  Future<void> success() async {
    if (!_enabled || kIsWeb) return;
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Error - alert feedback for errors
  Future<void> error() async {
    if (!_enabled || kIsWeb) return;
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Vibrate - custom vibration pattern (requires vibration package)
  /// For now, falls back to heavy impact
  Future<void> vibrate(
      {Duration duration = const Duration(milliseconds: 100)}) async {
    if (!_enabled || kIsWeb) return;
    await heavy();
  }
}
