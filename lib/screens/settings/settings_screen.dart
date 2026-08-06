import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';

import '../../controllers/theme_controller.dart';
import '../../core/app_theme.dart';
import '../../core/routes.dart';
import '../../services/local_storage_service.dart';
import '../../services/notification_service.dart';
import '../../services/account_deletion_service.dart';
import 'ai_settings_screen.dart';

import '../../widgets/gradient_scaffold.dart';
import '../../widgets/ad_banner_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ThemeController get _theme => ThemeController.instance;

  final LocalStorageService _storage = LocalStorageService.instance;

  bool _hydrationReminders = true;
  bool _movementReminders = false;
  bool _friendlyReminders = true;
  bool _performanceMode = false;
  int _activeStartMin = 9 * 60;
  int _activeEndMin = 21 * 60;

  @override
  void initState() {
    super.initState();
    _loadReminderSettings();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadReminderSettings() async {
    final settings = await _storage.getAppSettings() ?? <String, dynamic>{};
    if (!mounted) return;
    setState(() {
      _hydrationReminders =
          (settings['reminders_hydration_enabled'] as bool?) ?? true;
      _movementReminders =
          (settings['reminders_movement_enabled'] as bool?) ?? false;
      _friendlyReminders =
          (settings['reminders_friendly_enabled'] as bool?) ?? true;
      _performanceMode =
          (settings['performance_mode_enabled'] as bool?) ?? false;
      _activeStartMin =
          (settings['reminders_active_start_min'] as num?)?.toInt() ?? (9 * 60);
      _activeEndMin =
          (settings['reminders_active_end_min'] as num?)?.toInt() ?? (21 * 60);
    });
  }

  Future<void> _saveReminderSettings() async {
    final settings = await _storage.getAppSettings() ?? <String, dynamic>{};
    settings['reminders_hydration_enabled'] = _hydrationReminders;
    settings['reminders_movement_enabled'] = _movementReminders;
    settings['reminders_friendly_enabled'] = _friendlyReminders;
    settings['performance_mode_enabled'] = _performanceMode;
    settings['reminders_active_start_min'] = _activeStartMin;
    settings['reminders_active_end_min'] = _activeEndMin;
    await _storage.saveAppSettings(settings);
    await NotificationService.instance.rescheduleHumaneReminders();
    await NotificationService.instance.rescheduleFriendlyReminders();
  }

  TimeOfDay _timeOfDayFromMinutes(int minutes) {
    final h = (minutes ~/ 60).clamp(0, 23);
    final m = (minutes % 60).clamp(0, 59);
    return TimeOfDay(hour: h, minute: m);
  }

  int _minutesFromTimeOfDay(TimeOfDay t) => (t.hour * 60) + t.minute;

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeOfDayFromMinutes(_activeStartMin),
    );
    if (picked == null) return;
    setState(() => _activeStartMin = _minutesFromTimeOfDay(picked));
    await _saveReminderSettings();
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _timeOfDayFromMinutes(_activeEndMin),
    );
    if (picked == null) return;
    setState(() => _activeEndMin = _minutesFromTimeOfDay(picked));
    await _saveReminderSettings();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _theme,
      builder: (context, _) {
        return GradientScaffold(
          appBar: AppBar(
            title: const Text('Settings'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildThemeSection(context),
                const SizedBox(height: 16),
                _buildAISection(context),
                const SizedBox(height: 16),
                _buildCloudBackupSection(context),
                const SizedBox(height: 16),
                _buildDownloadsSection(context),
                const SizedBox(height: 16),
                if (kIsWeb) _buildWebSection(context),
                const SizedBox(height: 16),
                _buildRemindersSection(context),
                const SizedBox(height: 16),
                _buildAdFreeSection(context),
                const SizedBox(height: 16),
                _buildAccountSection(context),
                if (!kIsWeb) ...[
                  const SizedBox(height: 24),
                  const SafeArea(
                    top: false,
                    child: Center(
                      child: AdBannerWidget(adUnitId: AdBannerWidget.banner3Id),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWebSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Web Experience',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _performanceMode,
            onChanged: (v) async {
              setState(() => _performanceMode = v);
              await _saveReminderSettings();
            },
            title: const Text(
              'Performance mode',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text(
              'Reduce animations for better performance on slower devices',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemindersSection(BuildContext context) {
    final start = _timeOfDayFromMinutes(_activeStartMin).format(context);
    final end = _timeOfDayFromMinutes(_activeEndMin).format(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reminders',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hydration / movement below are gentle nudges. Custom reminders are separate.',
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.95),
              fontSize: 12,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 16),
          const Text(
            'Gentle app reminders',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _hydrationReminders,
            onChanged: (v) async {
              setState(() => _hydrationReminders = v);
              await _saveReminderSettings();
            },
            title: const Text(
              'Hydration',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _movementReminders,
            onChanged: (v) async {
              setState(() => _movementReminders = v);
              await _saveReminderSettings();
            },
            title: const Text(
              'Movement',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _friendlyReminders,
            onChanged: (v) async {
              setState(() => _friendlyReminders = v);
              await _saveReminderSettings();
            },
            title: const Text(
              'Friendly',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: _pickStartTime,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Active hours start',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    start,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _pickEndTime,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Active hours end',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    end,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Theme Colors',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _buildColorRow(
            label: 'Primary',
            color: _theme.primary,
            onTap: () => _pickColor(
              context,
              title: 'Primary Color',
              current: _theme.primary,
              onSelected: _theme.setPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _buildColorRow(
            label: 'Secondary',
            color: _theme.secondary,
            onTap: () => _pickColor(
              context,
              title: 'Secondary Color',
              current: _theme.secondary,
              onSelected: _theme.setSecondary,
            ),
          ),
          const SizedBox(height: 10),
          _buildColorRow(
            label: 'Accent',
            color: _theme.accent,
            onTap: () => _pickColor(
              context,
              title: 'Accent Color',
              current: _theme.accent,
              onSelected: _theme.setAccent,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _theme.resetDefaults,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: Colors.white.withOpacity(0.15)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Reset to default'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorRow({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Future<void> _pickColor(
    BuildContext context, {
    required String title,
    required Color current,
    required Future<void> Function(Color) onSelected,
  }) async {
    final selected = await showDialog<Color>(
      context: context,
      builder: (context) {
        final palette = _palette();
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            title,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          content: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in palette)
                InkWell(
                  onTap: () => Navigator.pop(context, c),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: c.value == current.value
                            ? Colors.white
                            : Colors.white.withOpacity(0.20),
                        width: c.value == current.value ? 2 : 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (selected == null) return;
    await onSelected(selected);
  }

  List<Color> _palette() {
    return const [
      Color(0xFF7C5CFF),
      Color(0xFF19E3D6),
      Color(0xFFFFC857),
      Color(0xFF4CAF50),
      Color(0xFF2196F3),
      Color(0xFFFF5252),
      Color(0xFF9C27B0),
      Color(0xFFFF9800),
      Color(0xFF00BCD4),
      Color(0xFFE91E63),
    ];
  }

  Widget _buildAdFreeSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No banner ads (lifetime)',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Remove banner ads with a one-time purchase.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Lifetime ad-free option coming soon!')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Lifetime — Coming soon',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'Not signed in';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                const Icon(Icons.email_outlined,
                    color: AppColors.textSecondary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    email,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed:
                  user == null ? null : () => _showDeleteAccountDialog(context),
              icon: const Icon(Icons.delete_forever, size: 20),
              label: const Text(
                'Delete Account',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red, width: 1.5),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Delete Account?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action cannot be undone. All your data will be permanently deleted:',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: 12),
            Text(
              '• Profile information\n'
              '• Activity tracking data\n'
              '• Meal logs\n'
              '• Water intake logs\n'
              '• Streak data\n'
              '• All settings',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      await AccountDeletionService.instance.deleteAccount();

      if (!context.mounted) return;
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);

      navigator.pop(); // Close loading dialog

      // Navigate to login screen
      navigator.pushNamedAndRemoveUntil(
        Routes.login,
        (route) => false,
      );

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Account deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } on AccountDeletionException catch (e) {
      if (!context.mounted) return;
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);

      navigator.pop(); // Close loading dialog

      if (e.requiresReauth) {
        // Show re-authentication dialog
        _showReauthDialog(context);
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);

      navigator.pop(); // Close loading dialog

      messenger.showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showReauthDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Re-authentication Required',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'For security reasons, you need to sign in again and retry account deletion.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // User is already signed out by the service
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                Routes.login,
                (route) => false,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please sign in again to delete your account'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildCloudBackupSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Cloud Backup',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Back up your data to the cloud and restore it on any device.',
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => Navigator.pushNamed(context, Routes.cloudSync),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_sync, size: 18, color: AppColors.primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Manage Cloud Backup',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600)),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.download, size: 20, color: AppColors.secondary),
              const SizedBox(width: 8),
              const Text(
                'Native Apps',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Download native apps for Android, Windows, macOS, and Linux for the best experience.',
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => Navigator.pushNamed(context, Routes.downloads),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.download_for_offline,
                      size: 18, color: AppColors.secondary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Get Native Apps',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600)),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAISection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.smart_toy,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'AI Assistant',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Chat with AI, configure features for meal analysis, voice commands, and personalized fitness insights.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          // AI Chat button — opens full screen chat (synced with floating assistant)
          InkWell(
            onTap: () => Navigator.pushNamed(context, Routes.aiThreads),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'AI Chat',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // AI Settings button
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AISettingsScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.settings,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'AI Settings',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
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
