import 'package:flutter/material.dart';
import '../services/credits_service.dart';
import '../core/app_theme.dart';

/// Shows a confirmation dialog before any AI action that costs credits.
/// For image/video, also shows how many the user can generate with current balance.
/// Returns true if user confirms, false if cancelled.
Future<bool> showCreditConfirmDialog(
  BuildContext context, {
  required String featureName,
  required int creditCost,
  String? description,
  bool showMaxCount = false,
  double? preciseCost, // optional fractional cost
}) async {
  final available = CreditsService.instance.preciseCredits;
  final cost = preciseCost ?? creditCost.toDouble();
  final hasEnough = available >= cost || cost == 0;
  final maxCount = cost > 0 ? (available ~/ cost) : 0;
  final costLabel = cost == 0
      ? '~0.01 credits'
      : cost < 1
          ? '${cost.toStringAsFixed(3)} credits'
          : '${cost.toStringAsFixed(0)} credits';
  final balanceLabel = available < 1
      ? '${available.toStringAsFixed(2)} credits'
      : '${available.toStringAsFixed(0)} credits';

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Text('⚡', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(
            featureName,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description != null) ...[
            Text(
              description,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
          ],

          // Cost + balance row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasEnough
                  ? AppColors.primary.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasEnough ? AppColors.primary : Colors.red,
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cost', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    Text(
                      costLabel,
                      style: TextStyle(
                        color: hasEnough ? AppColors.primary : Colors.red,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Your balance', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    Text(
                      balanceLabel,
                      style: TextStyle(
                        color: hasEnough ? AppColors.textPrimary : Colors.red,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Max count hint — only for image/video
          if (showMaxCount && hasEnough) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Text('💡', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'With your balance you can generate up to $maxCount more',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (!hasEnough) ...[
            const SizedBox(height: 12),
            const Text(
              'Not enough credits. Purchase more to continue.',
              style: TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        if (hasEnough)
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm'),
          )
        else
          ElevatedButton(
            onPressed: () => Navigator.pop(context, false),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Buy Credits'),
          ),
      ],
    ),
  );

  return result ?? false;
}
