/// A subscription plan with USD + INR pricing.
class SubscriptionPlan {
  final String key;
  final String tier;
  final String period;
  final double priceUsd; // shown to international users
  final double priceInr; // shown to Indian users
  final bool isOneTime;
  final int? durationDays; // null = permanent
  final List<String> features;
  final String? badge;
  final int? savingsPercent;
  final int? aiMealAnalysisLimit; // null = unlimited
  final bool adFree;
  final bool advancedAnalytics;
  final bool customThemes;
  final bool prioritySupport;
  final bool exportData;
  final bool liveCoaching;
  final int? creditsPerMonth; // null = unlimited

  const SubscriptionPlan({
    required this.key,
    required this.tier,
    required this.period,
    required this.priceUsd,
    required this.priceInr,
    this.isOneTime = false,
    this.durationDays,
    this.features = const [],
    this.badge,
    this.savingsPercent,
    this.aiMealAnalysisLimit,
    this.adFree = false,
    this.advancedAnalytics = false,
    this.customThemes = false,
    this.prioritySupport = false,
    this.exportData = false,
    this.liveCoaching = false,
    this.creditsPerMonth,
  });

  String displayUsd() => '\$${priceUsd.toStringAsFixed(2)}${_suffix()}';
  String displayInr() => '₹${_inrFormatted()}${_suffix()}';

  String _suffix() {
    if (isOneTime) return '';
    switch (period) {
      case 'Monthly': return '/mo';
      case 'Yearly': return '/yr';
      default: return '';
    }
  }

  String _inrFormatted() {
    // Add comma separators for INR
    final s = priceInr.toStringAsFixed(0);
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    final rest = s.substring(0, s.length - 3);
    final withCommas = rest.replaceAllMapped(
      RegExp(r'(\d{1,2})(?=(\d{2})+$)'),
      (m) => '${m[1]},',
    );
    return '$withCommas,$last3';
  }
}

class SubscriptionService {
  // ═══════════════════════════════════════════════════════════════════════
  // MAIN SUBSCRIPTION TIERS (Only Monthly & Yearly - Simplified!)
  // ═══════════════════════════════════════════════════════════════════════
  
  static const List<SubscriptionPlan> subscriptionPlans = [
    // ── PRO TIER ──────────────────────────────────────────────────────────
    SubscriptionPlan(
      key: 'pro_monthly',
      tier: 'Pro',
      period: 'Monthly',
      priceUsd: 4.99,
      priceInr: 415,
      durationDays: 30,
      creditsPerMonth: 200,
      features: [
        '200 credits/month included',
        'Ad-free experience',
        '5GB cloud storage',
        'Advanced workout analytics',
        'Export data (CSV)',
        'Custom themes',
        '90-day activity history',
      ],
      aiMealAnalysisLimit: 50,
      adFree: true,
      advancedAnalytics: true,
      customThemes: true,
      exportData: true,
    ),
    SubscriptionPlan(
      key: 'pro_yearly',
      tier: 'Pro',
      period: 'Yearly',
      priceUsd: 39.99,
      priceInr: 3320,
      durationDays: 365,
      creditsPerMonth: 200,
      badge: 'SAVE 33%',
      savingsPercent: 33,
      features: [
        '200 credits/month included',
        'Ad-free experience',
        '5GB cloud storage',
        'Advanced workout analytics',
        'Export data (CSV)',
        'Custom themes',
        'Unlimited activity history',
        'Priority email support',
        '2 months free',
      ],
      aiMealAnalysisLimit: 50,
      adFree: true,
      advancedAnalytics: true,
      customThemes: true,
      prioritySupport: true,
      exportData: true,
    ),

    // ── ELITE TIER ────────────────────────────────────────────────────────
    SubscriptionPlan(
      key: 'elite_monthly',
      tier: 'Elite',
      period: 'Monthly',
      priceUsd: 9.99,
      priceInr: 830,
      durationDays: 30,
      creditsPerMonth: 1000,
      features: [
        '1,000 credits/month',
        'Everything in Pro',
        '20GB cloud storage',
        'Live AI workout coaching',
        'Advanced form analysis',
        'Priority support',
        'Custom workout plans',
      ],
      aiMealAnalysisLimit: null,
      adFree: true,
      advancedAnalytics: true,
      customThemes: true,
      prioritySupport: true,
      exportData: true,
      liveCoaching: true,
    ),
    SubscriptionPlan(
      key: 'elite_yearly',
      tier: 'Elite',
      period: 'Yearly',
      priceUsd: 79.99,
      priceInr: 6640,
      durationDays: 365,
      creditsPerMonth: 1000,
      badge: 'BEST VALUE',
      savingsPercent: 33,
      features: [
        '1,000 credits/month',
        'Everything in Pro',
        '20GB cloud storage',
        'Live AI workout coaching',
        'Advanced form analysis',
        'Priority support',
        'Custom workout plans',
        '2 months free',
      ],
      aiMealAnalysisLimit: null,
      adFree: true,
      advancedAnalytics: true,
      customThemes: true,
      prioritySupport: true,
      exportData: true,
      liveCoaching: true,
    ),

    // ── LIFETIME TIER ─────────────────────────────────────────────────────
    SubscriptionPlan(
      key: 'lifetime',
      tier: 'Lifetime',
      period: 'One-time',
      priceUsd: 149.99,
      priceInr: 12450,
      isOneTime: true,
      creditsPerMonth: 500,
      badge: 'LIFETIME ACCESS',
      features: [
        '500 credits/month forever',
        'All Elite features forever',
        '50GB cloud storage',
        'No recurring payments',
        'All future updates included',
        'Priority support for life',
        'Best value — save \$1,000+ vs yearly',
      ],
      aiMealAnalysisLimit: 100, // 100 meal analyses/month for Lifetime
      adFree: true,
      advancedAnalytics: true,
      customThemes: true,
      prioritySupport: true,
      exportData: true,
      liveCoaching: true,
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════
  // ADD-ONS (Not subscription tiers - properly classified!)
  // ═══════════════════════════════════════════════════════════════════════
  
  static const List<SubscriptionPlan> addOns = [
    // Remove Ads Only (for users who don't want AI features)
    SubscriptionPlan(
      key: 'remove_ads',
      tier: 'Add-on',
      period: 'One-time',
      priceUsd: 1.99,
      priceInr: 166,
      isOneTime: true,
      features: [
        'Remove all ads permanently',
        'Clean, distraction-free experience',
        'No AI features included',
      ],
      adFree: true,
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════

  /// Get all plans (subscriptions + add-ons)
  static List<SubscriptionPlan> get allPlans => [...subscriptionPlans, ...addOns];

  /// Get only subscription plans (Pro, Elite, Lifetime)
  static List<SubscriptionPlan> get mainPlans => subscriptionPlans;

  /// Legacy getter for backward compatibility
  @Deprecated('Use subscriptionPlans or allPlans instead')
  static List<SubscriptionPlan> get plans => allPlans;

  /// Get plans by tier
  static List<SubscriptionPlan> getPlansByTier(String tier) =>
      subscriptionPlans.where((p) => p.tier == tier).toList();

  /// Get plan by key
  static SubscriptionPlan? getPlanByKey(String key) {
    try {
      return allPlans.firstWhere((p) => p.key == key);
    } catch (_) {
      return null;
    }
  }

  /// Check if user can access a feature
  static bool canAccessFeature(String? userPlanKey, String feature) {
    if (userPlanKey == null) return false;
    final plan = getPlanByKey(userPlanKey);
    if (plan == null) return false;
    
    switch (feature) {
      case 'ad_free': return plan.adFree;
      case 'advanced_analytics': return plan.advancedAnalytics;
      case 'custom_themes': return plan.customThemes;
      case 'priority_support': return plan.prioritySupport;
      case 'export_data': return plan.exportData;
      case 'live_coaching': return plan.liveCoaching;
      case 'unlimited_ai_meals': return plan.aiMealAnalysisLimit == null;
      default: return false;
    }
  }

  /// Get AI meal analysis limit for user
  /// Free: 10/month, Pro: 50/month, Elite/Lifetime: unlimited
  static int? getAIMealAnalysisLimit(String? userPlanKey) {
    if (userPlanKey == null) return 10; // Free tier
    final plan = getPlanByKey(userPlanKey);
    return plan?.aiMealAnalysisLimit ?? 10;
  }

  /// Check if plan is a subscription (vs one-time purchase)
  static bool isSubscription(String planKey) {
    final plan = getPlanByKey(planKey);
    return plan != null && !plan.isOneTime;
  }

  /// Get tier hierarchy (for upgrade logic)
  /// Returns: 0=Free, 1=Add-on, 2=Pro, 3=Elite, 4=Lifetime
  static int getTierLevel(String? planKey) {
    if (planKey == null) return 0; // Free
    if (planKey == 'remove_ads') return 1; // Add-on
    if (planKey.startsWith('pro_')) return 2; // Pro
    if (planKey.startsWith('elite_')) return 3; // Elite
    if (planKey == 'lifetime') return 4; // Lifetime
    return 0;
  }

  /// Check if user can upgrade to a plan
  static bool canUpgradeTo(String? currentPlanKey, String targetPlanKey) {
    final currentLevel = getTierLevel(currentPlanKey);
    final targetLevel = getTierLevel(targetPlanKey);
    return targetLevel > currentLevel;
  }
}
