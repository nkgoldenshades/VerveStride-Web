import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../core/app_theme.dart';
import '../services/local_storage_service.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final ThemeController instance = ThemeController._();

  final LocalStorageService _storage = LocalStorageService.instance;

  Color _primary = AppColors.primary;
  Color _secondary = AppColors.secondary;
  Color _accent = AppColors.accent;
  bool _isPremium = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _premiumSub;

  Color get primary => _primary;
  Color get secondary => _secondary;
  Color get accent => _accent;
  bool get isPremium => _isPremium;

  ThemeData get theme => AppTheme.darkThemeWith(
    primary: _primary,
    secondary: _secondary,
    accent: _accent,
  );

  Future<void> load([String? userId]) async {
    // userId parameter kept for backward compatibility but no longer used
    // Subscription data is now device-local, not user-specific

    try {
      final settings = await _storage.getAppSettings();
      if (settings == null) {
        _applyColors(primary: _primary, secondary: _secondary, accent: _accent);
        return;
      }

      final p = _tryParseColor(settings['primary']);
      final s = _tryParseColor(settings['secondary']);
      final a = _tryParseColor(settings['accent']);

      _primary = p ?? _primary;
      _secondary = s ?? _secondary;
      _accent = a ?? _accent;
      // Premium is Firestore-driven (Users/{uid}).
      // Do not trust local cache for lifetime status.
      _isPremium = false;

      _applyColors(primary: _primary, secondary: _secondary, accent: _accent);
      notifyListeners();
    } catch (_) {
      _applyColors(primary: _primary, secondary: _secondary, accent: _accent);
    }
  }

  Future<void> setPrimary(Color color) async {
    _primary = color;
    _applyColors(primary: _primary, secondary: _secondary, accent: _accent);
    notifyListeners();
    await _persist();
  }

  Future<void> setSecondary(Color color) async {
    _secondary = color;
    _applyColors(primary: _primary, secondary: _secondary, accent: _accent);
    notifyListeners();
    await _persist();
  }

  Future<void> setAccent(Color color) async {
    _accent = color;
    _applyColors(primary: _primary, secondary: _secondary, accent: _accent);
    notifyListeners();
    await _persist();
  }

  Future<void> setPremium(bool value) async {
    _isPremium = value;
    notifyListeners();
    await _persist();
  }

  Future<void> resetDefaults() async {
    _primary = const Color(0xFF7C5CFF);
    _secondary = const Color(0xFF19E3D6);
    _accent = const Color(0xFFFFC857);
    _isPremium = false;

    _applyColors(primary: _primary, secondary: _secondary, accent: _accent);
    notifyListeners();
    await _persist();
  }

  void reset() {
    debugPrint('🎨 Resetting ThemeController for logout');
    stopListening();
    _isPremium = false;
    notifyListeners();
  }

  Future<void> _persist() async {
    final settings = await _storage.getAppSettings() ?? <String, dynamic>{};
    settings['primary'] = _primary.value;
    settings['secondary'] = _secondary.value;
    settings['accent'] = _accent.value;
    settings['is_premium'] = _isPremium;
    // Keep ad_free synced for legacy support if needed
    settings['ad_free'] = _isPremium;
    await _storage.saveAppSettings(settings);
  }

  void _applyColors({
    required Color primary,
    required Color secondary,
    required Color accent,
  }) {
    AppColors.primary = primary;
    AppColors.secondary = secondary;
    AppColors.accent = accent;
  }

  Color? _tryParseColor(dynamic value) {
    if (value is int) return Color(value);
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return Color(parsed);
    }
    return null;
  }

  // --- Premium Status Listener ---

  void listenToPremiumStatus(String userId) {
    debugPrint('🔔 Starting premium status listener for user: $userId');
    // userId is used for Firestore listener, not for local storage

    _premiumSub?.cancel();

    _premiumSub = FirebaseFirestore.instance
        .collection('Users')
        .doc(userId)
        .snapshots()
        .listen(
          (snap) async {
            bool premium = false;
            final data = snap.data();
            if (data != null) {
              final direct = <String>[
                'isPremium',
                'is_premium',
                'premium',
                'ad_free',
                'lifetime',
                'Lifetime',
              ];
              for (final k in direct) {
                final v = data[k];
                if (v is bool && v == true) {
                  premium = true;
                  break;
                }
              }

              if (!premium) {
                final status = data['subscriptionStatus'];
                if (status is String && status.toLowerCase() == 'active') {
                  premium = true;
                }
              }

              if (!premium) {
                final end = data['currentPeriodEnd'] ?? data['premiumUntil'];
                DateTime? until;
                if (end is Timestamp) {
                  until = end.toDate();
                } else if (end is DateTime) {
                  until = end;
                } else if (end is String) {
                  until = DateTime.tryParse(end);
                }
                if (until != null && until.isAfter(DateTime.now())) {
                  premium = true;
                }
              }
            }

            await setPremium(premium);
            try {
              await _storage.setIsPremium(premium);
            } catch (_) {}
          },
          onError: (e) {
            debugPrint('⚠️ Premium status listener error: $e');
          },
        );
  }

  void stopListening() {
    debugPrint('🔕 Stopping premium status listener');
    _premiumSub?.cancel();
    _premiumSub = null;
  }
}
