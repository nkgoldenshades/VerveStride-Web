import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../widgets/gradient_scaffold.dart';

/// Simple, user-friendly privacy screen
class SimplePrivacyScreen extends StatelessWidget {
  const SimplePrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Your Privacy'),
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  Icon(Icons.lock, size: 64, color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Your Data is YOURS',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'We protect your privacy. Always.',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // What We DO
            _buildSection(
              icon: Icons.check_circle,
              iconColor: Colors.green,
              title: 'What We DO',
              items: [
                '✅ Store your fitness data securely',
                '✅ Remember your login (so you don\'t have to login every time)',
                '✅ Save your preferences (theme, settings)',
                '✅ Protect your data with encryption',
              ],
            ),
            const SizedBox(height: 24),

            // What We DON'T DO
            _buildSection(
              icon: Icons.block,
              iconColor: Colors.red,
              title: 'What We DON\'T DO',
              items: [
                '❌ We DON\'T sell your data (Never. Not to anyone. Ever.)',
                '❌ We DON\'T share your data with third parties',
                '❌ We DON\'T track you across websites',
                '❌ We DON\'T read your AI conversations',
                '❌ We DON\'T spam you with emails',
              ],
            ),
            const SizedBox(height: 24),

            // Cookies
            _buildSection(
              icon: Icons.cookie,
              iconColor: Colors.orange,
              title: 'About Cookies 🍪',
              items: [
                'We use cookies ONLY for:',
                '• Keep you logged in',
                '• Remember your settings',
                '• Make the app work properly',
                '',
                'No tracking cookies. No advertising cookies. No creepy stuff.',
              ],
            ),
            const SizedBox(height: 24),

            // Your Rights
            _buildSection(
              icon: Icons.verified_user,
              iconColor: AppColors.primary,
              title: 'Your Rights',
              items: [
                '✅ Export your data - Download everything',
                '✅ Delete your account - Remove all data',
                '✅ Control your data - It\'s yours!',
                '✅ Stop using anytime - No questions asked',
              ],
            ),
            const SizedBox(height: 24),

            // Security
            _buildSection(
              icon: Icons.security,
              iconColor: Colors.blue,
              title: 'How We Protect You',
              items: [
                '🔒 HTTPS encryption - All data encrypted',
                '🔒 Firebase security - Bank-level protection',
                '🔒 App Check - Prevents unauthorized access',
                '🔒 Firestore rules - Only YOU can access YOUR data',
              ],
            ),
            const SizedBox(height: 32),

            // Contact
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.email, color: AppColors.primary, size: 32),
                  SizedBox(height: 8),
                  Text(
                    'Questions?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'vervestride.app@gmail.com',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'We\'ll respond within 24 hours!',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Bottom Line
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.2),
                    AppColors.secondary.withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '🎉 Bottom Line',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Your data is YOURS.\nWe protect it. We don\'t sell it.\nWe don\'t share it. We don\'t track you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'You\'re in control. Always. 🔒',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Last updated
            Center(
              child: Text(
                'Last Updated: May 1, 2026',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
