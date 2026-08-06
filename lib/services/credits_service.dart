import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/ai_credits.dart';
import 'local_storage_service.dart';
import 'currency_service.dart';

/// Credits are READ from Firestore directly (fast).
/// Credits are WRITTEN only via Cloud Functions (secure — rules block client writes).
class CreditsService extends ChangeNotifier {
  CreditsService._();
  static final CreditsService instance = CreditsService._();

  int _availableCredits = 0; // Will be loaded from Firestore
  double _preciseCredits = 0.0; // Track fractional credits
  bool _loaded = false;

  static const List<CreditPackage> packages = [
    CreditPackage(
        key: 'credits_50',
        name: 'Starter Pack',
        credits: 50,
        priceUsd: 2.99,
        priceInr: 249,
        badge: 'Try it out'),
    CreditPackage(
        key: 'credits_100',
        name: 'Basic Pack',
        credits: 100,
        priceUsd: 4.99,
        priceInr: 415,
        badge: 'Most Popular'),
    CreditPackage(
        key: 'credits_250',
        name: 'Value Pack',
        credits: 250,
        priceUsd: 9.99,
        priceInr: 830,
        bonusCredits: 30,
        badge: '+30 Bonus'),
    CreditPackage(
        key: 'credits_500',
        name: 'Power Pack',
        credits: 500,
        priceUsd: 17.99,
        priceInr: 1499,
        bonusCredits: 75,
        badge: '+75 Bonus'),
  ];

  int get availableCredits => _availableCredits;
  double get preciseCredits => _preciseCredits;
  bool get hasCredits => _preciseCredits > 0;

  void forceSet(int amount) {
    _availableCredits = amount;
    _preciseCredits = amount.toDouble();
    notifyListeners();
  }

  void forceSetPrecise(double amount) {
    _preciseCredits = amount;
    _availableCredits = amount.ceil();
    notifyListeners();
  }

  List<CreditPackageLocalized> get localizedPackages => packages
      .map((p) => CurrencyService.instance.getLocalizedPackage(p))
      .toList();

  DocumentReference? get _userRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('Users').doc(uid);
  }

  // ── Load (read-only from Firestore) ───────────────────────────────────────

  Future<void> load({bool force = false}) async {
    if (_loaded && !force) {
      debugPrint('💳 Credits already loaded, skipping');
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      await _loadLocal();
      return;
    }

    try {
      final doc = await _userRef!.get();
      final data = doc.data() as Map<String, dynamic>?;
      final credits = data?['credits'];

      if (credits is Map) {
        _availableCredits = (credits['available'] as num?)?.toInt() ?? 0;
        _preciseCredits = (credits['precise'] as num?)?.toDouble() ??
            _availableCredits.toDouble();
        debugPrint(
            '💳 Credits loaded from Firestore: $_availableCredits (${_preciseCredits.toStringAsFixed(4)} precise)');
        _loaded = true;
        await _saveLocal();
        notifyListeners();
      } else {
        // New user — grant welcome credits via backend
        await _grantWelcomeCredits();
      }
    } catch (e) {
      debugPrint('⚠️ Firestore credits load failed, using local: $e');
      await _loadLocal();
    }
  }

  Future<void> _grantWelcomeCredits() async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('grantWelcomeCredits')
          .call();
      final credits = result.data?['credits'];
      if (credits != null) {
        _availableCredits = (credits['available'] as num?)?.toInt() ?? 20;
        _preciseCredits = (credits['precise'] as num?)?.toDouble() ??
            _availableCredits.toDouble();
      } else {
        _availableCredits = 20;
        _preciseCredits = 20.0;
      }
      debugPrint(
          '🎁 Welcome credits granted: $_availableCredits (${_preciseCredits.toStringAsFixed(4)} precise)');
      _loaded = true;
      await _saveLocal();
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Welcome credits function failed, using local: $e');
      await _loadLocal();
    }
  }

  Future<void> _loadLocal() async {
    final settings = await LocalStorageService.instance.getAppSettings();
    final stored = settings?['ai_credits'] as int?;
    final hasWelcome = settings?['received_welcome_credits'] as bool? ?? false;

    if (stored == null && !hasWelcome) {
      _availableCredits = 20;
      _preciseCredits = 20.0;
      final updated = await LocalStorageService.instance.getAppSettings() ?? {};
      updated['ai_credits'] = 20;
      updated['ai_precise_credits'] = 20.0;
      updated['received_welcome_credits'] = true;
      await LocalStorageService.instance.saveAppSettings(updated);
      debugPrint('🎁 Welcome credits granted locally: 20 (20.0 precise)');
    } else {
      _availableCredits = stored ?? 0;
      final storedPrecise = settings?['ai_precise_credits'] as double?;
      _preciseCredits = storedPrecise ?? _availableCredits.toDouble();
      debugPrint(
          '💳 Credits loaded locally: $_availableCredits (${_preciseCredits.toStringAsFixed(4)} precise)');
    }
    _loaded = true;
    notifyListeners();
  }

  // ── Use credits (via Cloud Function — backend transaction) ────────────────

  Future<bool> useCredits(int amount, {String? description}) async {
    if (_availableCredits < amount) {
      debugPrint(
          '❌ Insufficient credits. Need: $amount, Have: $_availableCredits');
      return false;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // Offline fallback
      _availableCredits -= amount;
      _preciseCredits -= amount.toDouble();
      await _saveLocal();
      notifyListeners();
      return true;
    }

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('deductCredits')
          .call({'amount': amount, 'description': description ?? 'AI usage'});

      final remaining =
          (result.data?['credits']?['remaining'] as num?)?.toInt();
      final precise = (result.data?['credits']?['precise'] as num?)?.toDouble();

      if (remaining != null) {
        _availableCredits = remaining;
        _preciseCredits = precise ?? remaining.toDouble();
      } else {
        _availableCredits -= amount;
        _preciseCredits -= amount.toDouble();
      }
      await _saveLocal();
      await _logUsage(amount, description ?? 'AI usage');
      notifyListeners();
      debugPrint(
          '💳 Used $amount credits. Remaining: $_availableCredits (${_preciseCredits.toStringAsFixed(4)} precise)');
      return true;
    } catch (e) {
      debugPrint('❌ deductCredits function failed: $e');
      // Reload to get accurate balance
      await load(force: true);
      return false;
    }
  }

  /// Use precise fractional credits (for accurate API cost tracking)
  Future<bool> usePreciseCredits(double amount, {String? description}) async {
    if (_preciseCredits < amount && amount > 0.001) {
      debugPrint(
          '❌ Insufficient precise credits. Need: $amount, Have: $_preciseCredits');
      return false;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // Offline fallback — deduct locally only
      _preciseCredits = (_preciseCredits - amount).clamp(0.0, double.infinity);
      _availableCredits = _preciseCredits.ceil();
      await _saveLocal();
      notifyListeners();
      return true;
    }

    try {
      // Deduct via Cloud Function (server-side, secure)
      final result = await FirebaseFunctions.instance
          .httpsCallable('deductCredits')
          .call({'amount': amount, 'description': description ?? 'AI Chat'});

      final remaining =
          (result.data?['credits']?['remaining'] as num?)?.toDouble();
      final precise = (result.data?['credits']?['precise'] as num?)?.toDouble();

      if (precise != null) {
        _preciseCredits = precise;
        _availableCredits = precise.ceil();
      } else if (remaining != null) {
        _preciseCredits = remaining;
        _availableCredits = remaining.ceil();
      } else {
        _preciseCredits =
            (_preciseCredits - amount).clamp(0.0, double.infinity);
        _availableCredits = _preciseCredits.ceil();
      }

      await _saveLocal();
      notifyListeners();
      debugPrint(
          '💳 Used ${amount.toStringAsFixed(4)} precise credits. Remaining: ${_preciseCredits.toStringAsFixed(4)}');
      return true;
    } catch (e) {
      debugPrint('❌ deductCredits (precise) failed: $e');
      await load(force: true);
      return false;
    }
  }

  // ── Add credits after purchase (REMOVED - now handled by Firebase service) ───────────────────────

  // This method is deprecated - use FirebaseSubscriptionService.addCredits instead
  // Kept for backward compatibility only
  @Deprecated('Use FirebaseSubscriptionService.addCredits with real paymentId')
  Future<void> addCreditsAfterPurchase(int amount, String packageKey) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // Offline — just add locally
      _availableCredits += amount;
      _preciseCredits += amount.toDouble();
      await _saveLocal();
      notifyListeners();
      return;
    }

    // This should not be used anymore - Cloud Function call requires real payment ID
    debugPrint(
        '⚠️ DEPRECATED: addCreditsAfterPurchase called. Use FirebaseSubscriptionService.addCredits instead.');

    // Reload from Firestore to get accurate balance
    await load(force: true);
  }

  @Deprecated('Use FirebaseSubscriptionService.addCredits with real paymentId')
  Future<void> addCredits(int amount, String paymentId) async {
    await addCreditsAfterPurchase(amount, paymentId);
  }

  // ── Refund credits (via Cloud Function) ───────────────────────────────────

  Future<void> refundCredits(int amount) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _availableCredits += amount;
      await _saveLocal();
      notifyListeners();
      return;
    }

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('refundCredits')
          .call({'amount': amount, 'reason': 'AI operation failed'});

      final total = (result.data?['credits']?['total'] as num?)?.toInt();
      if (total != null) {
        _availableCredits = total;
      } else {
        _availableCredits += amount;
      }
      await _saveLocal();
      notifyListeners();
      debugPrint('💳 Refunded $amount credits. Total: $_availableCredits');
    } catch (e) {
      debugPrint('❌ refundCredits function failed: $e');
      await load(force: true);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _saveLocal() async {
    final settings = await LocalStorageService.instance.getAppSettings() ?? {};
    settings['ai_credits'] = _availableCredits;
    settings['ai_precise_credits'] = _preciseCredits;
    await LocalStorageService.instance.saveAppSettings(settings);
  }

  Future<void> _logUsage(num amount, String description) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('credit_usage').add({
        'userId': uid,
        'amount': amount,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        'remainingCredits': _availableCredits,
        'remainingPreciseCredits': _preciseCredits,
      });
    } catch (e) {
      debugPrint('⚠️ Failed to log credit usage: $e');
    }
  }

  /// Call on every app open — grants 1 credit if not already claimed today
  Future<bool> claimDailyBonus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('claimDailyBonus')
          .call();
      final granted = result.data?['granted'] == true;
      if (granted) {
        final available = (result.data?['available'] as num?)?.toInt();
        if (available != null) {
          _availableCredits = available;
          await _saveLocal();
          notifyListeners();
        }
        debugPrint('🎁 Daily bonus claimed: +1 credit');
      } else {
        debugPrint('💳 Daily bonus already claimed today');
      }
      return granted;
    } catch (e) {
      debugPrint('⚠️ Daily bonus failed: $e');
      return false;
    }
  }

  Future<void> clear() async {
    _availableCredits = 0;
    _loaded = false;
    await _saveLocal();
    notifyListeners();
  }

  static CreditPackage? getPackageByKey(String key) {
    try {
      return packages.firstWhere((p) => p.key == key);
    } catch (_) {
      return null;
    }
  }

  // ── DEPRECATED: Use AIFeatureCosts instead ──────────────────────────────────
  // These constants are kept for backward compatibility only.
  // New code should import and use AIFeatureCosts.* instead.

  @Deprecated('Use AIFeatureCosts.imageAnalysis (0 credits - FREE)')
  static const int creditsPerMealAnalysis = 0;

  @Deprecated('Use AIFeatureCosts.chatFlash (0 credits - FREE)')
  static const int creditsPerWorkoutCoaching = 0;

  @Deprecated('Use AIFeatureCosts.chatFlash (0 credits - FREE)')
  static const int creditsPerChatMessage = 0;

  @Deprecated('Use AIFeatureCosts.formAnalysisPhoto (0 credits - FREE)')
  static const int creditsPerFormAnalysis = 0;

  @Deprecated('Use AIFeatureCosts.imageGeneration')
  static const int creditsPerImageGeneration = 1;

  @Deprecated('Use AIFeatureCosts.videoGeneration')
  static const int creditsPerVideoGeneration = 8;

  @Deprecated('Use AIFeatureCosts.audioGeneration')
  static const int creditsPerAudioGeneration = 3;

  @Deprecated('Use AIFeatureCosts.progressReport')
  static const int creditsPerProgressAnalysis = 1;

  static const int creditsPerCloudBackup =
      5; // Cloud backup sync cost (not in AIFeatureCosts yet)
}
