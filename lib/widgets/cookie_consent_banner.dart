import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import '../services/local_storage_service.dart';

/// Cookie Consent Banner (Web Only)
/// 
/// Displays a GDPR/CCPA compliant cookie consent banner on web.
/// Only shows essential cookies notice since we don't use tracking cookies.
class CookieConsentBanner extends StatefulWidget {
  const CookieConsentBanner({super.key});

  @override
  State<CookieConsentBanner> createState() => _CookieConsentBannerState();
}

class _CookieConsentBannerState extends State<CookieConsentBanner> {
  bool _showBanner = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkConsent();
  }

  Future<void> _checkConsent() async {
    // Only show on web
    if (!kIsWeb) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final settings = await LocalStorageService.instance.getAppSettings();
      final hasConsented = settings?['cookie_consent_given'] as bool? ?? false;
      
      if (mounted) {
        setState(() {
          _showBanner = !hasConsented;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking cookie consent: $e');
      if (mounted) {
        setState(() {
          _showBanner = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _acceptCookies() async {
    try {
      final settings = await LocalStorageService.instance.getAppSettings() ?? {};
      settings['cookie_consent_given'] = true;
      settings['cookie_consent_date'] = DateTime.now().toIso8601String();
      await LocalStorageService.instance.saveAppSettings(settings);
      
      if (mounted) {
        setState(() => _showBanner = false);
      }
    } catch (e) {
      debugPrint('Error saving cookie consent: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || !_showBanner) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Material(
        elevation: 8,
        color: const Color(0xFF1E1E2E),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.cookie_outlined,
                      color: Colors.white.withOpacity(0.9),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Privacy-First Cookies',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'We use essential cookies to make VerveStride work. '
                  'We DON\'T use tracking cookies, advertising cookies, or sell your data. '
                  'Your fitness data stays private and secure.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse('https://vervestrideai.com/privacy');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                          _acceptCookies();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.3),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: const Text('Learn More'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _acceptCookies,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF6B46C1),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Accept & Continue'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _acceptCookies,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: const Text(
                      'Essential cookies only (required for app to work)',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
