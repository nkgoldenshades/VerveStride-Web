import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/credits_service.dart';
import '../../services/user_subscription_service.dart';
import '../../widgets/gradient_scaffold.dart';

class CloudSyncScreen extends StatefulWidget {
  const CloudSyncScreen({super.key});

  @override
  State<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends State<CloudSyncScreen> {
  @override
  void initState() {
    super.initState();
    CloudSyncService.instance.load();
  }

  Future<void> _showResult(SyncResult result) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Delete cloud data?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This permanently deletes your cloud backup. '
          'Your local data on this device is NOT affected.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final result = await CloudSyncService.instance.deleteFromCloud();
      _showResult(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        CloudSyncService.instance,
        UserSubscriptionService.instance,
      ]),
      builder: (context, _) {
        final sync = CloudSyncService.instance;
        final canSync = sync.canUseCloudSync;

        return GradientScaffold(
          appBar: AppBar(
            title: const Text('Cloud Backup'),
            backgroundColor: Colors.transparent,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [

              // ── Status card ─────────────────────────────────────────
              _StatusCard(sync: sync, canSync: canSync),
              const SizedBox(height: 20),

              // ── Upgrade prompt (free users) ─────────────────────────
              if (!canSync) ...[
                _UpgradePrompt(),
                const SizedBox(height: 20),
              ],

              // ── Sync toggle ─────────────────────────────────────────
              if (canSync) ...[
                _SectionTitle('Auto Sync'),
                _SettingTile(
                  icon: Icons.sync,
                  title: 'Automatic cloud sync',
                  subtitle: 'Sync your data to cloud automatically',
                  trailing: Switch(
                    value: sync.syncEnabled,
                    onChanged: canSync
                        ? (v) => CloudSyncService.instance.setSyncEnabled(v)
                        : null,
                    activeThumbColor: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Actions ─────────────────────────────────────────────
              _SectionTitle('Actions'),
              const SizedBox(height: 8),

              // Sync now
              if (canSync)
                _ActionButton(
                  icon: Icons.cloud_upload_outlined,
                  label: 'Sync to cloud now',
                  subtitle: 'Upload your local data to cloud',
                  color: AppColors.primary,
                  loading: sync.isSyncing,
                  onTap: () async {
                    final result = await CloudSyncService.instance.syncToCloud();
                    _showResult(result);
                  },
                ),

              const SizedBox(height: 10),

              // Download
              _ActionButton(
                icon: Icons.cloud_download_outlined,
                label: 'Download from cloud',
                subtitle: canSync
                    ? 'Restore your cloud backup to this device'
                    : 'Requires ${CreditsService.creditsPerCloudBackup} credits',
                color: canSync ? AppColors.secondary : AppColors.textSecondary,
                loading: sync.isSyncing,
                onTap: canSync
                    ? () async {
                        final result =
                            await CloudSyncService.instance.downloadFromCloud();
                        _showResult(result);
                      }
                    : null,
              ),

              const SizedBox(height: 10),

              // Delete
              _ActionButton(
                icon: Icons.delete_outline,
                label: 'Delete cloud data',
                subtitle: 'Permanently remove your cloud backup',
                color: Colors.red,
                loading: false,
                onTap: canSync ? _confirmDelete : null,
              ),

              const SizedBox(height: 32),

              // ── Info ────────────────────────────────────────────────
              _InfoCard(),
            ],
          ),
        );
      },
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final CloudSyncService sync;
  final bool canSync;

  const _StatusCard({required this.sync, required this.canSync});

  @override
  Widget build(BuildContext context) {
    final color = canSync
        ? (sync.syncEnabled ? Colors.green : AppColors.primary)
        : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              canSync
                  ? (sync.syncEnabled
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_outlined)
                  : Icons.cloud_off_outlined,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  canSync
                      ? (sync.syncEnabled ? 'Cloud sync on' : 'Cloud sync off')
                      : 'Local storage only',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  canSync
                      ? 'Last sync: ${sync.lastSyncLabel}'
                      : 'Your data stays on this device',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (sync.isSyncing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

class _UpgradePrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt_outlined, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cloud backup costs ${CreditsService.creditsPerCloudBackup} credits per sync. You don\'t have enough credits right now.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/credits'),
            child: const Text('Get Credits'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool loading;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: onTap != null
              ? color.withOpacity(0.08)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: onTap != null
                ? color.withOpacity(0.25)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: onTap != null ? color : AppColors.textSecondary,
                size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: onTap != null ? color : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (loading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: color),
              )
            else
              Icon(Icons.chevron_right,
                  color: onTap != null
                      ? color.withOpacity(0.6)
                      : AppColors.textSecondary,
                  size: 20),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.textSecondary, size: 16),
              SizedBox(width: 8),
              Text(
                'How it works',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _infoRow('📱', 'Local by default',
              'All your data stays on this device. No cloud required.'),
          _infoRow('☁️', 'Cloud backup (5 credits per sync)',
              'Each sync costs ${CreditsService.creditsPerCloudBackup} credits. Earn credits daily or purchase more.'),
          _infoRow('⬇️', 'Download anytime',
              'Restore your cloud backup to any device you sign in to.'),
          _infoRow('🗑️', 'Delete anytime',
              'Remove your cloud data permanently. Local data is unaffected.'),
          _infoRow('🔒', 'Private',
              'Only you can access your data. Never shared or sold.'),
        ],
      ),
    );
  }

  Widget _infoRow(String emoji, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$title — ',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: desc,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
