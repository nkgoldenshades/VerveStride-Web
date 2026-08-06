import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'local_storage_service.dart';
import 'subscription_service.dart';
import 'credits_service.dart';
import '../utils/secure_logger.dart';
import '../utils/log_sanitizer.dart';

/// Singleton that tracks the user's active subscription, expiry date,
/// and exposes feature-gate helpers used across the app.
class UserSubscriptionService extends ChangeNotifier {
  UserSubscriptionService._();
  static final UserSubscriptionService instance = UserSubscriptionService._();

  // Development mode removed — all feature gates use real subscription state only.
  static const bool _developmentMode = false;

  String? _planKey;
  DateTime? _startDate;
  DateTime? _expiresAt; // null = permanent (lifetime / remove_ads)
  bool _loaded = false;

  // ── Public state ──────────────────────────────────────────────────────────

  String? get planKey => _planKey;

  SubscriptionPlan? get plan =>
      _planKey != null ? SubscriptionService.getPlanByKey(_planKey!) : null;

  DateTime? get startDate => _startDate;
  DateTime? get expiresAt => _expiresAt;

  /// Whether the subscription has passed its expiry date.
  bool get isExpired {
    if (_planKey == null) return false;
    if (_expiresAt == null) return false; // permanent
    return DateTime.now().isAfter(_expiresAt!);
  }

  /// Days remaining until expiry. Returns null for permanent plans.
  /// Returns 0 if already expired.
  int? get daysRemaining {
    if (_expiresAt == null) return null;
    final diff = _expiresAt!.difference(DateTime.now());
    final days = diff.inSeconds > 0 ? (diff.inSeconds / 86400).ceil() : 0;
    return days;
  }

  /// Human-readable expiry label, e.g. "23 days left" or "Expires today".
  String? get expiryLabel {
    final days = daysRemaining;
    if (days == null) return null; // permanent
    if (days == 0) return 'Expires today';
    if (days == 1) return '1 day left';
    if (days <= 7) return '$days days left ⚠️';
    return '$days days left';
  }

  // ── Tier checks (respects expiry) ─────────────────────────────────────────

  bool get isFree => _developmentMode ? false : (_planKey == null || isExpired);
  bool get hasRemovedAds => _developmentMode ? true : (_planKey == 'remove_ads' && !isExpired);
  
  /// True if user has Pro or higher tier (Pro, Elite, or Lifetime)
  bool get isPro {
    if (_developmentMode) return true; // Enable for testing
    if (isExpired || _planKey == null) return false;
    final tier = plan?.tier;
    return tier == 'Pro' || tier == 'Elite' || tier == 'Lifetime';
  }
  
  /// True if user has Elite or higher tier (Elite or Lifetime)
  bool get isElite {
    if (_developmentMode) return true; // Enable for testing
    if (isExpired || _planKey == null) return false;
    final tier = plan?.tier;
    return tier == 'Elite' || tier == 'Lifetime';
  }
  
  bool get isLifetime => _developmentMode ? true : (_planKey == 'lifetime' && !isExpired);

  String get tierLabel {
    if (_developmentMode) return 'Dev Mode (All Features)';
    if (isExpired && _planKey != null) return 'Expired';
    if (isLifetime) return 'Lifetime';
    if (isElite) return 'Elite';
    if (isPro) return 'Pro';
    if (hasRemovedAds) return 'No Ads';
    return 'Free';
  }

  // ── Feature gates ─────────────────────────────────────────────────────────

  bool get isAdFree => _developmentMode ? true : (!isExpired && (plan?.adFree ?? false));
  bool get hasAdvancedAnalytics => _developmentMode ? true : (!isExpired && (plan?.advancedAnalytics ?? false));
  bool get hasCustomThemes => _developmentMode ? true : (!isExpired && (plan?.customThemes ?? false));
  bool get hasPrioritySupport => _developmentMode ? true : (!isExpired && (plan?.prioritySupport ?? false));
  bool get canExportData => _developmentMode ? true : (!isExpired && (plan?.exportData ?? false));

  int? get aiMealAnalysisLimit =>
      SubscriptionService.getAIMealAnalysisLimit(isExpired ? null : _planKey);

  bool canAccess(String feature) =>
      SubscriptionService.canAccessFeature(isExpired ? null : _planKey, feature);

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Call once at app start (after LocalStorageService is ready).
  /// Pass [force] = true to reload even if already loaded (e.g. after sign-in).
  Future<void> load({bool force = false}) async {
    if (_loaded && !force) {
      logger.d('Subscription already loaded, skipping');
      return;
    }
    final s = await LocalStorageService.instance.getAppSettings();
    logger.d('Settings loaded: ${LogSanitizer.sanitizeSettings(s ?? {})}');
    
    _planKey = s?['subscription_plan_key'] as String?;

    final startRaw = s?['subscription_start_date'] as String?;
    _startDate = startRaw != null ? DateTime.tryParse(startRaw) : null;

    final expiryRaw = s?['subscription_expires_at'] as String?;
    _expiresAt = expiryRaw != null ? DateTime.tryParse(expiryRaw) : null;

    // Sync from Firestore if user is logged in
    await _syncFromFirestore();

    // If subscription expired, remove subscription credits
    if (isExpired && _planKey != null) {
      await _removeSubscriptionCredits();
    }

    _loaded = true;
    
    // Load credits as well
    await CreditsService.instance.load(force: force);
    
    notifyListeners();
    logger.i('Subscription loaded');
  }

  /// Sync subscription state from Firestore Users document
  Future<void> _syncFromFirestore() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
      if (!doc.exists) return;

      final data = doc.data()!;

      // Check Lifetime flag (set by razorpaywebhook)
      final isLifetimeUser = data['Lifetime'] == true;
      if (isLifetimeUser && _planKey != 'lifetime') {
        logger.i('Firestore: Lifetime access detected, syncing locally');
        _planKey = 'lifetime';
        _expiresAt = null;
        _startDate ??= DateTime.now();
        // Persist locally
        final settings = await LocalStorageService.instance.getAppSettings() ?? {};
        settings['subscription_plan_key'] = 'lifetime';
        settings['subscription_expires_at'] = null;
        settings['is_premium'] = true;
        await LocalStorageService.instance.saveAppSettings(settings);
      }

      // Check subscription map (set by activateSubscription function)
      final sub = data['subscription'] as Map<String, dynamic>?;
      if (sub != null && sub['status'] == 'active') {
        final planKey = sub['planKey'] as String?;
        if (planKey != null && planKey != _planKey) {
          logger.i('Firestore: Active subscription detected, syncing locally');
          _planKey = planKey;
          final expiresAtMs = sub['expiresAt'];
          if (expiresAtMs != null) {
            _expiresAt = DateTime.fromMillisecondsSinceEpoch(
              expiresAtMs is int ? expiresAtMs : (expiresAtMs as num).toInt()
            );
          } else {
            _expiresAt = null;
          }
          final settings = await LocalStorageService.instance.getAppSettings() ?? {};
          settings['subscription_plan_key'] = planKey;
          settings['subscription_expires_at'] = _expiresAt?.toIso8601String();
          settings['is_premium'] = true;
          await LocalStorageService.instance.saveAppSettings(settings);
        }
      }
    } catch (e) {
      logger.w('Firestore subscription sync failed', e);
    }
  }

  /// Called after a successful Razorpay payment.
  Future<void> activatePlan(String planKey, String paymentId) async {
    final plan = SubscriptionService.getPlanByKey(planKey);
    if (plan == null) {
      logger.e('Unknown planKey: $planKey');
      return;
    }

    final now = DateTime.now();
    final expiresAt = plan.durationDays != null
        ? now.add(Duration(days: plan.durationDays!))
        : null; // permanent

    final settings = await LocalStorageService.instance.getAppSettings() ?? {};
    settings['subscription_plan_key'] = planKey;
    settings['subscription_payment_id'] = paymentId;
    settings['subscription_start_date'] = now.toIso8601String();
    settings['subscription_expires_at'] =
        expiresAt?.toIso8601String(); // null stored as null
    settings['is_premium'] = true;
    settings['ad_free'] = plan.adFree;
    
    logger.i('Saving subscription to storage');
    await LocalStorageService.instance.saveAppSettings(settings);
    logger.i('Subscription saved to storage');

    _planKey = planKey;
    _startDate = now;
    _expiresAt = expiresAt;
    _loaded = true;
    notifyListeners();

    // Grant credits immediately on plan activation
    await _grantPlanCredits(planKey, now);

    logger.i('Subscription activated');
  }

  /// Remove subscription credits when plan expires
  /// Keeps any purchased credits (totalPurchased - totalUsed remainder)
  Future<void> _removeSubscriptionCredits() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final ref = FirebaseFirestore.instance.collection('Users').doc(uid);
      final doc = await ref.get();
      final data = doc.data();
      final creditsRaw = data?['credits'];
      if (creditsRaw is! Map) return;
      final credits = Map<String, dynamic>.from(creditsRaw);

      // Keep only purchased credits (what they bought separately)
      final totalPurchased = (credits['totalPurchased'] as num?)?.toInt() ?? 0;
      final totalUsed = (credits['totalUsed'] as num?)?.toInt() ?? 0;
      final purchasedRemaining = (totalPurchased - totalUsed).clamp(0, totalPurchased);

      await ref.set({
        'credits': {
          'available': purchasedRemaining,
          'totalPurchased': totalPurchased,
          'totalUsed': totalUsed,
          'welcomeGranted': credits['welcomeGranted'] ?? true,
          'lastResetDate': credits['lastResetDate'],
          'monthlyAllowance': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));

      logger.i('Subscription expired: credits reset to purchased remainder');
    } catch (e) {
      logger.w('Failed to remove subscription credits', e);
    }
  }

  /// Grant credits when a plan is activated
  Future<void> _grantPlanCredits(String planKey, DateTime activatedAt) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = FirebaseFirestore.instance.collection('Users').doc(uid);

    try {
      if (planKey.startsWith('pro_')) {
        // Pro: set 200 credits + reset date
        await ref.set({
          'credits': {
            'available': 200,
            'totalPurchased': 0,
            'totalUsed': 0,
            'welcomeGranted': true,
            'lastResetDate': activatedAt.toIso8601String(),
            'monthlyAllowance': 200,
            'updatedAt': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));
        CreditsService.instance.forceSet(200);
        logger.i('Pro plan activated: 200 credits granted');

      } else if (planKey.startsWith('elite_')) {
        await ref.set({
          'credits': {
            'available': 1000,
            'totalPurchased': 0,
            'totalUsed': 0,
            'welcomeGranted': true,
            'lastResetDate': activatedAt.toIso8601String(),
            'monthlyAllowance': 1000,
            'updatedAt': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));
        CreditsService.instance.forceSet(1000);
        logger.i('Elite plan activated: 1000 credits granted');
      }
      // Lifetime credits are granted separately via grantLifetimeCredits()
    } catch (e) {
      logger.w('Failed to grant plan credits', e);
    }
  }

  /// Clears the subscription (sign-out / cancellation).
  Future<void> clear() async {
    final settings = await LocalStorageService.instance.getAppSettings() ?? {};
    settings.remove('subscription_plan_key');
    settings.remove('subscription_payment_id');
    settings.remove('subscription_start_date');
    settings.remove('subscription_expires_at');
    settings['is_premium'] = false;
    settings['ad_free'] = false;
    await LocalStorageService.instance.saveAppSettings(settings);

    _planKey = null;
    _startDate = null;
    _expiresAt = null;
    
    // Clear credits as well
    await CreditsService.instance.clear();
    
    notifyListeners();
  }
}
