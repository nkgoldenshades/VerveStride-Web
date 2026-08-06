import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/ai_credit_costs.dart';
import '../services/credits_service.dart';

/// Shows credit cost hint before AI actions
/// Displays: "💎 2 credits" or "💎 5 credits - Live Coaching"
class CreditCostHint extends StatelessWidget {
  final String feature;
  final bool showDescription;
  final bool showBalance;
  final TextStyle? style;

  const CreditCostHint({
    super.key,
    required this.feature,
    this.showDescription = false,
    this.showBalance = false,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final cost = AICreditCosts.getCost(feature);
    final icon = AICreditCosts.getIcon(feature);
    final description = AICreditCosts.getDescription(feature);
    final balance = CreditsService.instance.availableCredits;
    final hasEnough = balance >= cost;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '💎 $cost ${cost == 1 ? 'credit' : 'credits'}',
          style: style ?? TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: hasEnough ? AppColors.textSecondary : Colors.red,
          ),
        ),
        if (showDescription) ...[
          const SizedBox(width: 4),
          Text(
            '- $icon $description',
            style: style ?? const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (showBalance) ...[
          const SizedBox(width: 8),
          Text(
            '(Balance: $balance)',
            style: TextStyle(
              fontSize: 12,
              color: hasEnough ? AppColors.textSecondary : Colors.red,
            ),
          ),
        ],
      ],
    );
  }
}

/// Confirmation dialog showing credit cost
class CreditCostConfirmDialog extends StatelessWidget {
  final String feature;
  final String title;
  final String message;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;

  const CreditCostConfirmDialog({
    super.key,
    required this.feature,
    required this.title,
    required this.message,
    required this.onConfirm,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final cost = AICreditCosts.getCost(feature);
    final icon = AICreditCosts.getIcon(feature);
    final description = AICreditCosts.getDescription(feature);
    final balance = CreditsService.instance.availableCredits;
    final hasEnough = balance >= cost;
    final remaining = balance - cost;

    return AlertDialog(
      title: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasEnough 
                  ? AppColors.primary.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasEnough ? AppColors.primary : Colors.red,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      description,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '💎 $cost ${cost == 1 ? 'credit' : 'credits'}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: hasEnough ? AppColors.primary : Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Your balance:',
                      style: TextStyle(fontSize: 13),
                    ),
                    Text(
                      '💎 $balance',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (hasEnough) ...[
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'After this action:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '💎 $remaining',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF19E3D6), // AppColors.secondary
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (!hasEnough) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You need ${cost - balance} more ${cost - balance == 1 ? 'credit' : 'credits'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (!hasEnough)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to buy credits
              // Navigator.pushNamed(context, Routes.buyCredits);
            },
            child: const Text('Buy Credits'),
          ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onCancel?.call();
          },
          child: const Text('Cancel'),
        ),
        if (hasEnough)
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Confirm'),
          ),
      ],
    );
  }

  /// Show the dialog
  static Future<void> show({
    required BuildContext context,
    required String feature,
    required String title,
    required String message,
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
  }) {
    return showDialog(
      context: context,
      builder: (context) => CreditCostConfirmDialog(
        feature: feature,
        title: title,
        message: message,
        onConfirm: onConfirm,
        onCancel: onCancel,
      ),
    );
  }
}

/// Bottom sheet showing all credit costs
class CreditCostsSheet extends StatelessWidget {
  const CreditCostsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final features = AICreditCosts.getAllFeatures();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          
          // Title
          const Text(
            'AI Feature Costs',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'See how many credits each feature uses',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          
          // Features list
          Expanded(
            child: ListView.builder(
              itemCount: features.length,
              itemBuilder: (context, index) {
                final category = features.keys.elementAt(index);
                final items = features[category]!;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        category,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6C63FF),
                        ),
                      ),
                    ),
                    ...items.map((item) => ListTile(
                      dense: true,
                      leading: Text(
                        AICreditCosts.getIcon(item['key']),
                        style: const TextStyle(fontSize: 20),
                      ),
                      title: Text(
                        item['desc'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFE0E0E0),
                        ),
                      ),
                      trailing: Text(
                        '💎 ${item['cost']}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF19E3D6),
                        ),
                      ),
                    )),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
          
          // Close button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Got it'),
            ),
          ),
        ],
      ),
    );
  }

  /// Show the bottom sheet
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: const CreditCostsSheet(),
      ),
    );
  }
}

