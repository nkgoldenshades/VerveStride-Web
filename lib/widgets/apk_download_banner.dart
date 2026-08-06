import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../core/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

/// Multi-Platform Download Banner
/// 
/// Shows on web to promote app downloads (APK, EXE, IPA)
class MultiPlatformDownloadBanner extends StatelessWidget {
  final String? apkUrl;
  final String? exeUrl;
  final String? ipaUrl;
  final bool showOnMobile;
  
  const MultiPlatformDownloadBanner({
    super.key,
    this.apkUrl,
    this.exeUrl,
    this.ipaUrl,
    this.showOnMobile = true,
  });

  @override
  Widget build(BuildContext context) {
    // Only show on web
    if (!kIsWeb) return const SizedBox.shrink();

    // Check if any download link is provided
    if (apkUrl == null && exeUrl == null && ipaUrl == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.2),
            AppColors.secondary.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.download, color: AppColors.primary, size: 32),
              SizedBox(width: 12),
              Text(
                'Download Native App',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Subtitle
          Text(
            'Better experience, offline access, and reliable features!',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          // Platform Buttons
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              if (apkUrl != null)
                _buildPlatformButton(
                  context,
                  icon: Icons.android,
                  label: 'Android',
                  subtitle: 'APK File',
                  url: apkUrl!,
                  color: const Color(0xFF3DDC84),
                ),
              if (exeUrl != null)
                _buildPlatformButton(
                  context,
                  icon: Icons.window,
                  label: 'Windows',
                  subtitle: 'EXE File',
                  url: exeUrl!,
                  color: const Color(0xFF0078D4),
                ),
              if (ipaUrl != null)
                _buildPlatformButton(
                  context,
                  icon: Icons.apple,
                  label: 'iOS',
                  subtitle: 'IPA File',
                  url: ipaUrl!,
                  color: const Color(0xFF000000),
                ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Features
          _buildFeature('🔔', 'Background Alarms', 'Works even when app is closed'),
          const SizedBox(height: 12),
          _buildFeature('⚡', 'Faster Performance', 'Native speed and efficiency'),
          const SizedBox(height: 12),
          _buildFeature('📴', 'Offline Access', 'Use core features without internet'),
          const SizedBox(height: 12),
          _buildFeature('🔋', 'Battery Optimized', 'Efficient background processing'),
          
          const SizedBox(height: 16),
          
          // Info
          Text(
            '💡 Choose your platform above to download',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required String url,
    required Color color,
  }) {
    return SizedBox(
      width: 160,
      child: ElevatedButton(
        onPressed: () => _downloadFile(context, url, label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.15),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: color.withOpacity(0.3)),
          ),
          elevation: 0,
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: color.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadFile(BuildContext context, String url, String platformName) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloading $platformName app...'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open download link'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildFeature(String emoji, String title, String subtitle) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact APK Download Card (for settings/menu)
class APKDownloadCard extends StatelessWidget {
  final String apkUrl;
  
  const APKDownloadCard({
    super.key,
    required this.apkUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    return InkWell(
      onTap: () => _downloadAPK(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.15),
              AppColors.secondary.withOpacity(0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.android,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Android App Available',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Download APK for better experience',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.download,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadAPK(BuildContext context) async {
    try {
      final uri = Uri.parse(apkUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open download link'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
