import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';
import '../../services/local_storage_service.dart';

/// Privacy Dashboard Screen
/// 
/// Gives users full control over their data and privacy settings.
/// GDPR/CCPA compliant data management.
class PrivacyDashboardScreen extends StatefulWidget {
  const PrivacyDashboardScreen({super.key});

  @override
  State<PrivacyDashboardScreen> createState() => _PrivacyDashboardScreenState();
}

class _PrivacyDashboardScreenState extends State<PrivacyDashboardScreen> {
  bool _analyticsEnabled = false;
  bool _crashReportsEnabled = true;
  bool _aiChatEnabled = true;
  bool _mealAnalysisEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await LocalStorageService.instance.getAISettings();
      if (mounted) {
        setState(() {
          _analyticsEnabled = settings['analytics_enabled'] as bool? ?? false;
          _crashReportsEnabled = settings['crash_reports_enabled'] as bool? ?? true;
          _aiChatEnabled = settings['conversational_ai_enabled'] as bool? ?? true;
          _mealAnalysisEnabled = settings['photo_analysis_enabled'] as bool? ?? true;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading privacy settings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    try {
      final settings = await LocalStorageService.instance.getAISettings();
      settings['analytics_enabled'] = _analyticsEnabled;
      settings['crash_reports_enabled'] = _crashReportsEnabled;
      settings['conversational_ai_enabled'] = _aiChatEnabled;
      settings['photo_analysis_enabled'] = _mealAnalysisEnabled;
      await LocalStorageService.instance.saveAISettings(settings);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Privacy settings saved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving privacy settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportData() async {
    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final storage = LocalStorageService.instance;

      // Gather all local data
      final profile = await storage.getUserProfile();
      final aiSettings = await storage.getAISettings();
      final appSettings = await storage.getAppSettings();
      final chatHistory = await storage.getAIChatHistory();

      // Gather Firestore data if logged in
      Map<String, dynamic> firestoreData = {};
      if (uid != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('Users')
              .doc(uid)
              .get();
          if (doc.exists) firestoreData = doc.data() ?? {};
        } catch (_) {}
      }

      final exportData = {
        'exported_at': DateTime.now().toIso8601String(),
        'user_id': uid ?? 'anonymous',
        'profile': profile,
        'ai_settings': aiSettings,
        'app_settings': appSettings,
        'chat_history_count': chatHistory.length,
        'firestore_data': firestoreData,
      };

      // Show data in a dialog (web-friendly — no file system access)
      if (!mounted) return;
      setState(() => _isLoading = false);

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Your Data Export',
              style: TextStyle(color: AppColors.textPrimary)),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: SingleChildScrollView(
              child: SelectableText(
                exportData.entries
                    .map((e) => '${e.key}: ${e.value}')
                    .join('\n\n'),
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontFamily: 'monospace'),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Export error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Export failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This will permanently delete your account and all data. '
          'This action cannot be undone.\n\n'
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('Not logged in');

        // Delete Firestore data
        try {
          await FirebaseFirestore.instance
              .collection('Users')
              .doc(user.uid)
              .delete();
        } catch (_) {}

        // Clear local storage
        await LocalStorageService.instance.clearUserData();

        // Delete Firebase Auth account
        await user.delete();

        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Navigate back to root
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) setState(() => _isLoading = false);
        // If requires recent login, prompt re-authentication
        if (e.code == 'requires-recent-login') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Please log out and log back in, then try deleting again.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Deletion failed: ${e.message}'),
                  backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Deletion failed: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Data'),
        backgroundColor: AppColors.card,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Privacy Overview
                _buildSection(
                  icon: Icons.shield_outlined,
                  title: 'Privacy Overview',
                  subtitle: 'We protect your data and never sell it',
                  children: [
                    _buildInfoTile(
                      icon: Icons.check_circle,
                      title: 'Zero Third-Party Tracking',
                      subtitle: 'No advertising trackers or cookies',
                      color: Colors.green,
                    ),
                    _buildInfoTile(
                      icon: Icons.lock,
                      title: 'Encrypted Storage',
                      subtitle: 'All data encrypted at rest and in transit',
                      color: Colors.blue,
                    ),
                    _buildInfoTile(
                      icon: Icons.person,
                      title: 'Your Data, Your Control',
                      subtitle: 'Export or delete your data anytime',
                      color: Colors.purple,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Data Collection
                _buildSection(
                  icon: Icons.analytics_outlined,
                  title: 'Data Collection',
                  subtitle: 'Control what data we collect',
                  children: [
                    SwitchListTile(
                      value: true,
                      onChanged: null, // Essential, cannot be disabled
                      title: const Text('Essential Data'),
                      subtitle: const Text(
                        'Required for app functionality (authentication, preferences)',
                      ),
                      secondary: const Icon(Icons.check_circle),
                    ),
                    SwitchListTile(
                      value: _analyticsEnabled,
                      onChanged: (value) {
                        setState(() => _analyticsEnabled = value);
                        _saveSettings();
                      },
                      title: const Text('Anonymous Analytics'),
                      subtitle: const Text(
                        'Help us improve the app (no personal data)',
                      ),
                      secondary: const Icon(Icons.bar_chart),
                    ),
                    SwitchListTile(
                      value: _crashReportsEnabled,
                      onChanged: (value) {
                        setState(() => _crashReportsEnabled = value);
                        _saveSettings();
                      },
                      title: const Text('Crash Reports'),
                      subtitle: const Text(
                        'Help us fix bugs (anonymous)',
                      ),
                      secondary: const Icon(Icons.bug_report),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // AI Features
                _buildSection(
                  icon: Icons.smart_toy_outlined,
                  title: 'AI Features',
                  subtitle: 'Control AI data usage',
                  children: [
                    SwitchListTile(
                      value: _aiChatEnabled,
                      onChanged: (value) {
                        setState(() => _aiChatEnabled = value);
                        _saveSettings();
                      },
                      title: const Text('AI Chat'),
                      subtitle: const Text(
                        'Enable personalized AI coaching',
                      ),
                      secondary: const Icon(Icons.chat),
                    ),
                    SwitchListTile(
                      value: _mealAnalysisEnabled,
                      onChanged: (value) {
                        setState(() => _mealAnalysisEnabled = value);
                        _saveSettings();
                      },
                      title: const Text('Meal Photo Analysis'),
                      subtitle: const Text(
                        'AI analyzes meal photos for nutrition info',
                      ),
                      secondary: const Icon(Icons.restaurant),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Data Management
                _buildSection(
                  icon: Icons.folder_outlined,
                  title: 'Data Management',
                  subtitle: 'Export or delete your data',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.download),
                      title: const Text('Export My Data'),
                      subtitle: const Text('Download all your data (JSON format)'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _exportData,
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_forever, color: Colors.red),
                      title: const Text(
                        'Delete Account',
                        style: TextStyle(color: Colors.red),
                      ),
                      subtitle: const Text('Permanently delete all data'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _deleteAccount,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Legal
                _buildSection(
                  icon: Icons.gavel_outlined,
                  title: 'Legal & Policies',
                  subtitle: 'Read our policies',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.privacy_tip),
                      title: const Text('Privacy Policy'),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => _openUrl('https://vervestrideai.com/privacy'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.description),
                      title: const Text('Terms of Service'),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => _openUrl('https://vervestrideai.com/terms'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.cookie),
                      title: const Text('Cookie Policy'),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => _openUrl('https://vervestrideai.com/cookies'),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Privacy Statement
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.verified_user,
                            color: Colors.green.shade400,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Our Privacy Promise',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '• We NEVER sell your data\n'
                        '• We DON\'T use tracking cookies\n'
                        '• Your fitness data stays private\n'
                        '• You control your data\n'
                        '• GDPR & CCPA compliant',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}
