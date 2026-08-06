import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// PWA Service web implementation
class PWAService {
  PWAService._();
  static final PWAService instance = PWAService._();

  bool _installPromptAvailable = false;
  bool _isInstalled = false;

  bool get canInstall => _installPromptAvailable && kIsWeb;
  bool get isInstalled => _isInstalled;

  void initialize() {
    if (!kIsWeb) return;

    try {
      // Check first — if already installed, don't register prompt listener
      _checkIfInstalled();
      if (_isInstalled) return;

      // Listen for PWA install prompt availability
      html.window.addEventListener('pwa-install-available', (event) {
        if (!_isInstalled) {
          _installPromptAvailable = true;
        }
      });
    } catch (e) {
      // non-critical
    }
  }

  void _checkIfInstalled() {
    if (!kIsWeb) return;
    try {
      final isStandalone =
          html.window.matchMedia('(display-mode: standalone)').matches;
      final isFullscreen =
          html.window.matchMedia('(display-mode: fullscreen)').matches;
      final isMinimalUI =
          html.window.matchMedia('(display-mode: minimal-ui)').matches;
      _isInstalled = isStandalone || isFullscreen || isMinimalUI;
    } catch (e) {
      _isInstalled = false;
    }
  }

  Future<bool> showInstallPrompt() async {
    if (!kIsWeb || !_installPromptAvailable || _isInstalled) return false;

    try {
      final jsContext = html.window as dynamic;
      if (jsContext.showPWAInstallPrompt != null) {
        jsContext.showPWAInstallPrompt();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  String getInstallInstructions() {
    if (!kIsWeb) return '';

    final userAgent = html.window.navigator.userAgent.toLowerCase();

    if (userAgent.contains('android')) {
      if (userAgent.contains('chrome')) {
        return 'Tap the menu (⋮) → "Add to Home screen" to install VerveStride as an app.';
      } else if (userAgent.contains('firefox')) {
        return 'Tap the menu (⋮) → "Install" to add VerveStride to your home screen.';
      }
      return 'Look for "Add to Home screen" or "Install" option in your browser menu.';
    }

    if (userAgent.contains('iphone') || userAgent.contains('ipad')) {
      return 'Tap the Share button (□↗) → "Add to Home Screen" to install VerveStride.';
    }

    if (userAgent.contains('windows') ||
        userAgent.contains('mac') ||
        userAgent.contains('linux')) {
      if (userAgent.contains('chrome') || userAgent.contains('edge')) {
        return 'Look for the install icon (⊕) in the address bar, or click the menu → "Install VerveStride..."';
      }
      return 'Use Chrome or Edge browser for the best installation experience.';
    }

    return 'Look for "Add to Home Screen" or "Install App" option in your browser.';
  }

  String getDisplayMode() {
    if (!kIsWeb) return 'native';

    try {
      if (html.window.matchMedia('(display-mode: standalone)').matches) {
        return 'standalone';
      }
      if (html.window.matchMedia('(display-mode: fullscreen)').matches) {
        return 'fullscreen';
      }
      if (html.window.matchMedia('(display-mode: minimal-ui)').matches) {
        return 'minimal-ui';
      }
      return 'browser';
    } catch (e) {
      return 'unknown';
    }
  }

  bool get supportsPWA {
    if (!kIsWeb) return false;

    try {
      final userAgent = html.window.navigator.userAgent.toLowerCase();

      // Chrome, Edge, Samsung Internet support PWA
      if (userAgent.contains('chrome') ||
          userAgent.contains('edge') ||
          userAgent.contains('samsungbrowser')) {
        return true;
      }

      // Firefox on Android supports PWA
      if (userAgent.contains('firefox') && userAgent.contains('android')) {
        return true;
      }

      // Safari on iOS supports Add to Home Screen
      if (userAgent.contains('safari') &&
          (userAgent.contains('iphone') || userAgent.contains('ipad'))) {
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  String? getAppStoreLink() {
    if (!kIsWeb) return null;

    final userAgent = html.window.navigator.userAgent.toLowerCase();

    if (userAgent.contains('android')) {
      // Return Google Play Store link when available
      return null; // 'https://play.google.com/store/apps/details?id=com.vervestride.app';
    }

    if (userAgent.contains('iphone') || userAgent.contains('ipad')) {
      // Return App Store link when available
      return null; // 'https://apps.apple.com/app/vervestride/id123456789';
    }

    return null;
  }

  Future<bool> requestNotificationPermission() async {
    if (!kIsWeb) return false;

    try {
      final permission = await html.Notification.requestPermission();
      final granted = permission == 'granted';
      debugPrint('🔔 Notification permission: $permission');
      return granted;
    } catch (e) {
      debugPrint('❌ Notification permission request failed: $e');
      return false;
    }
  }

  void showNotification({
    required String title,
    required String body,
    String? icon,
  }) {
    if (!kIsWeb) return;

    try {
      html.Notification(title, body: body, icon: icon ?? '/icons/Icon-192.png');
      debugPrint('🔔 Notification shown: $title');
    } catch (e) {
      debugPrint('❌ Failed to show notification: $e');
    }
  }
}
