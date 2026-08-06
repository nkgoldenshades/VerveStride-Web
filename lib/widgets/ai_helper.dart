import 'package:flutter/material.dart';
import 'package:vervestride/core/app_theme.dart';
import 'package:vervestride/services/firebase_ai_service.dart';

class AIHelper {
  /// Shows a banner only if AI is disabled (it's always enabled with VerveStride AI)
  static Widget buildAIStatusBanner({
    required BuildContext context,
    String? message,
    VoidCallback? onSettingsTap,
  }) {
    return FutureBuilder<bool>(
      future: FirebaseAIService.instance.isAIEnabled(),
      builder: (context, snapshot) {
        final isEnabled = snapshot.data ?? true;
        if (isEnabled) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withOpacity(0.1),
                AppColors.secondary.withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.smart_toy_outlined, size: 24, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message ?? 'Powered by VerveStride AI — your private personal assistant.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Wraps a widget and shows a disabled state if the feature is turned off
  static Widget buildAIFeatureWrapper({
    required BuildContext context,
    required Widget child,
    required String feature,
    Widget? fallback,
    String? disabledMessage,
  }) {
    return FutureBuilder<bool>(
      future: FirebaseAIService.instance.isFeatureEnabled(feature),
      builder: (context, snapshot) {
        final isEnabled = snapshot.data ?? true;
        if (isEnabled) return child;
        return fallback ?? _buildDisabledFeature(context, disabledMessage);
      },
    );
  }

  static Widget _buildDisabledFeature(BuildContext context, String? message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Icon(Icons.smart_toy_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'AI Feature Disabled',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message ?? 'This AI feature is currently disabled in settings.',
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  static Future<bool> showAIRequiredDialog({
    required BuildContext context,
    required String feature,
    String? message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            Icon(Icons.smart_toy_outlined, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('AI Required', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: Text(
          message ?? 'This feature requires AI to be enabled.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
