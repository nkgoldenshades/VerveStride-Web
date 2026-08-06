import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_theme.dart';

// Conditional import for web-only functionality
import 'download_helper.dart';

/// Download Native Apps Screen
/// Shows download links for Android, iOS, Windows, macOS, Linux apps
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Download Native Apps'),
        backgroundColor: AppColors.card,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.download, color: Colors.white, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Get Native Apps',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'For best experience with alarms, reminders, and offline features, download the native app for your device.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Why Download section
            _buildInfoCard(
              icon: Icons.star,
              title: 'Why Native Apps?',
              items: [
                '✓ Reliable alarms & reminders (works with screen off)',
                '✓ Better performance & battery life',
                '✓ Offline workout tracking',
                '✓ System integration (widgets, shortcuts)',
                '✓ No browser limitations',
              ],
            ),

            const SizedBox(height: 24),

            // Mobile Apps
            Text(
              'Mobile',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            _buildDownloadCard(
              context: context,
              icon: Icons.android,
              title: 'Android',
              subtitle: 'APK for Android 8.0+',
              color: Color(0xFF3DDC84),
              downloadUrl: _DownloadConfig.androidUrl,
              badge: 'Recommended for MIUI',
            ),

            const SizedBox(height: 12),

            _buildDownloadCard(
              context: context,
              icon: Icons.apple,
              title: 'iOS',
              subtitle: 'Coming to App Store',
              color: Color(0xFF000000),
              downloadUrl: null, // Will add App Store link later
              badge: 'Coming Soon',
            ),

            const SizedBox(height: 24),

            // Desktop Apps
            Text(
              'Desktop',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            _buildDownloadCard(
              context: context,
              icon: Icons.desktop_windows,
              title: 'Windows',
              subtitle: 'Installer for Windows 10/11',
              color: Color(0xFF0078D4),
              downloadUrl: _DownloadConfig.windowsUrl,
            ),

            const SizedBox(height: 12),

            _buildDownloadCard(
              context: context,
              icon: Icons.laptop_mac,
              title: 'macOS',
              subtitle: 'DMG for macOS 11+',
              color: Color(0xFF000000),
              downloadUrl: _DownloadConfig.macosUrl,
            ),

            const SizedBox(height: 12),

            _buildDownloadCard(
              context: context,
              icon: Icons.desktop_mac,
              title: 'Linux',
              subtitle: 'AppImage / Snap',
              color: Color(0xFFFCC624),
              downloadUrl: _DownloadConfig.linuxUrl,
            ),

            const SizedBox(height: 24),

            // Note
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'All apps sync with your account. Your data stays private and secure.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 100), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                item,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    String? downloadUrl,
    String? badge,
  }) {
    final isAvailable = downloadUrl != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAvailable
              ? color.withOpacity(0.3)
              : AppColors.textSecondary.withOpacity(0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isAvailable
              ? () => _handleDownload(context, downloadUrl, title)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: badge == 'Coming Soon'
                                    ? AppColors.textSecondary.withOpacity(0.2)
                                    : AppColors.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                badge,
                                style: TextStyle(
                                  color: badge == 'Coming Soon'
                                      ? AppColors.textSecondary
                                      : AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isAvailable ? Icons.download : Icons.lock,
                  color: isAvailable ? color : AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleDownload(
    BuildContext context,
    String url,
    String platform,
  ) async {
    try {
      if (kIsWeb) {
        // For web: Direct download using helper
        triggerDownload(url, url.split('/').last);

        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download started for $platform'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // For mobile/desktop: Use url_launcher
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Download link will be available soon!'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not start download: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DOWNLOAD CONFIGURATION (Centralized)
// ═══════════════════════════════════════════════════════════════════════════

/// Central config for all download URLs
/// Hosted on Cloudflare R2 with custom domain (downloads.vervestrideai.com)
/// Update version here and all download links update automatically
class _DownloadConfig {
  static const String _version = 'v1.0.0';
  static const String _baseUrl = 'https://downloads.vervestrideai.com';

  // Direct download URLs (Cloudflare R2 - clean, professional, no GitHub exposure)
  static String get androidUrl => '$_baseUrl/vervestride-$_version.apk';
  static String get windowsUrl => '$_baseUrl/vervestride-windows-$_version.zip';
  static String get macosUrl => '$_baseUrl/vervestride-macos-$_version.zip';
  static String get linuxUrl => '$_baseUrl/vervestride-linux-$_version.tar.gz';
}
