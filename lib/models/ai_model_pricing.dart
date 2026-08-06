/// AI Model Pricing with Credit Multipliers
/// Different models cost different amounts of credits
library;

class AIModelPricing {
  // ═══════════════════════════════════════════════════════════════════════════
  // MODEL DEFINITIONS
  // ═══════════════════════════════════════════════════════════════════════════

  static const Map<String, AIModelInfo> models = {
    'auto': AIModelInfo(
      id: 'auto',
      name: 'Auto (Fastest)',
      displayName: 'Auto',
      description: 'Fast, economical, good quality',
      creditMultiplier: 1.0,
      badge: 'Most Economical',
      color: 0xFF4CAF50,
    ),
    'gemini-1.5-flash': AIModelInfo(
      id: 'gemini-1.5-flash',
      name: 'Gemini 1.5 Flash',
      displayName: 'G1.5',
      description: 'Balanced speed & quality',
      creditMultiplier: 1.5,
      badge: 'Recommended',
      color: 0xFF2196F3,
    ),
    'gemini-2.5-flash': AIModelInfo(
      id: 'gemini-2.5-flash',
      name: 'Gemini 2.5 Flash',
      displayName: 'G2.5',
      description: 'Latest, best quality',
      creditMultiplier: 2.5,
      badge: 'Premium',
      color: 0xFFFF6B00,
    ),
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // CREDIT CALCULATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get base credit cost for a feature
  /// Then multiply by model multiplier
  static double calculateCredits(
    String feature,
    String modelId, {
    double? preciseCost, // Exact token-based cost
  }) {
    final model = models[modelId];
    if (model == null) {
      throw Exception('Unknown model: $modelId');
    }

    double baseCost = 0;

    // Base costs for common features
    if (preciseCost != null) {
      // Token-based precise cost
      baseCost = preciseCost;
    } else {
      // Fallback to fixed costs
      switch (feature) {
        case 'chat':
          baseCost = 1.0;
          break;
        case 'meal_analysis':
          baseCost = 2.0;
          break;
        case 'form_check':
          baseCost = 3.0;
          break;
        case 'video_analysis':
          baseCost = 5.0;
          break;
        default:
          baseCost = 1.0;
      }
    }

    // Apply model multiplier
    final finalCost = baseCost * model.creditMultiplier;

    return finalCost;
  }

  /// Get model info
  static AIModelInfo? getModel(String modelId) {
    return models[modelId];
  }

  /// Get all available models
  static List<AIModelInfo> getAllModels() {
    return models.values.toList();
  }

  /// Get cheapest model
  static AIModelInfo getCheapestModel() {
    return models['auto']!;
  }

  /// Get recommended model
  static AIModelInfo getRecommendedModel() {
    return models['gemini-1.5-flash']!;
  }

  /// Get premium model
  static AIModelInfo getPremiumModel() {
    return models['gemini-2.5-flash']!;
  }
}

/// Model Information Class
class AIModelInfo {
  final String id;
  final String name;
  final String displayName;
  final String description;
  final double creditMultiplier;
  final String badge;
  final int color;

  const AIModelInfo({
    required this.id,
    required this.name,
    required this.displayName,
    required this.description,
    required this.creditMultiplier,
    required this.badge,
    required this.color,
  });

  /// Get cost multiplier as text (e.g., "1.0x", "1.5x", "2.5x")
  String get multiplierText => '${creditMultiplier}x Credit';

  /// Get price estimate for a feature
  String getPriceEstimate(String feature) {
    final base = _getBaseFeatureCost(feature);
    final total = base * creditMultiplier;
    return '${total.toStringAsFixed(2)} cr';
  }

  static double _getBaseFeatureCost(String feature) {
    switch (feature) {
      case 'chat':
        return 1.0;
      case 'meal_analysis':
        return 2.0;
      case 'form_check':
        return 3.0;
      case 'video_analysis':
        return 5.0;
      default:
        return 1.0;
    }
  }
}
