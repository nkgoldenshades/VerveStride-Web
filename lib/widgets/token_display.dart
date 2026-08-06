import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// Displays token usage and credit cost for a message
/// Shows: "📊 20 input + 500 output = 0.00002 credits"
class TokenDisplay extends StatelessWidget {
  final int? inputTokens;
  final int? outputTokens;
  final double? preciseCredits;

  const TokenDisplay({
    super.key,
    this.inputTokens,
    this.outputTokens,
    this.preciseCredits,
  });

  String _formatCredits(double? credits) {
    if (credits == null || credits == 0) return '< 0.001 credits';
    if (credits < 0.0001) return '< 0.0001 credits';
    if (credits < 0.001) return '${credits.toStringAsFixed(4)} credits';
    if (credits < 1) return '${credits.toStringAsFixed(3)} credits';
    return '${credits.toStringAsFixed(2)} credits';
  }

  @override
  Widget build(BuildContext context) {
    if (inputTokens == null || outputTokens == null) {
      return const SizedBox.shrink();
    }

    final totalTokens = inputTokens! + outputTokens!;
    final creditsLabel = _formatCredits(preciseCredits);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.analytics,
            size: 12,
            color: AppColors.textSecondary.withOpacity(0.6),
          ),
          const SizedBox(width: 4),
          Text(
            '📊 ',
            style: TextStyle(
                fontSize: 11, color: AppColors.textSecondary.withOpacity(0.6)),
          ),
          Text(
            '$inputTokens ↪ + $outputTokens ↩ = $creditsLabel',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary.withOpacity(0.6),
              fontFamily: 'Courier',
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact inline token display for message headers
class CompactTokenDisplay extends StatelessWidget {
  final int? inputTokens;
  final int? outputTokens;
  final double? preciseCredits;

  const CompactTokenDisplay({
    super.key,
    this.inputTokens,
    this.outputTokens,
    this.preciseCredits,
  });

  @override
  Widget build(BuildContext context) {
    if (inputTokens == null || outputTokens == null) {
      return const SizedBox.shrink();
    }

    final totalTokens = inputTokens! + outputTokens!;

    return Tooltip(
      message:
          '📊 $inputTokens input tokens + $outputTokens output tokens = ${preciseCredits ?? 0} credits',
      child: Text(
        '📊 $totalTokens tokens',
        style: TextStyle(
          fontSize: 9,
          color: AppColors.textSecondary.withOpacity(0.5),
        ),
      ),
    );
  }
}
