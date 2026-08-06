import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/storage_tracking_service.dart';
import '../services/user_subscription_service.dart';

/// Widget to display cloud storage usage with upgrade prompt
class StorageUsageWidget extends StatelessWidget {
  final bool showUpgradeButton;
  final VoidCallback? onUpgrade;

  const StorageUsageWidget({
    super.key,
    this.showUpgradeButton = true,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StorageTrackingService.instance,
      builder: (context, _) {
        final storage = StorageTrackingService.instance;
        final usagePercent = storage.usagePercent.clamp(0.0, 1.0);
        final warningLevel = storage.warningLevel;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                storage.indicatorColor.withOpacity(0.15),
                storage.indicatorColor.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: storage.indicatorColor.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: storage.indicatorColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.cloud_outlined,
                      color: storage.indicatorColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cloud Storage',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          storage.tierLabel,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (warningLevel > 0)
                    Icon(
                      warningLevel == 2
                          ? Icons.warning_amber_rounded
                          : Icons.info_outline,
                      color: storage.indicatorColor,
                      size: 22,
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Usage text
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    storage.usageString,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${(usagePercent * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: storage.indicatorColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: usagePercent,
                  minHeight: 10,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    storage.indicatorColor,
                  ),
                ),
              ),

              // Warning message
              if (storage.warningMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: storage.indicatorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: storage.indicatorColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          storage.warningMessage!,
                          style: TextStyle(
                            color: storage.indicatorColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Upgrade button
              if (showUpgradeButton && !UserSubscriptionService.instance.isLifetime) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onUpgrade,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: storage.indicatorColor,
                      side: BorderSide(
                        color: storage.indicatorColor.withOpacity(0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.upgrade, size: 18),
                    label: Text(
                      _getUpgradeText(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _getUpgradeText() {
    final sub = UserSubscriptionService.instance;
    if (sub.isFree) return 'Upgrade to Pro (5GB)';
    if (sub.isPro) return 'Upgrade to Elite (20GB)';
    if (sub.isElite) return 'Get Lifetime (50GB)';
    return 'Upgrade Storage';
  }
}

/// Compact storage indicator for app bar or settings
class StorageIndicator extends StatelessWidget {
  final VoidCallback? onTap;

  const StorageIndicator({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StorageTrackingService.instance,
      builder: (context, _) {
        final storage = StorageTrackingService.instance;
        final usagePercent = storage.usagePercent.clamp(0.0, 1.0);

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: storage.indicatorColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: storage.indicatorColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_outlined,
                  color: storage.indicatorColor,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '${(usagePercent * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: storage.indicatorColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
