import 'package:flutter/foundation.dart';

/// Service for managing Progressive Web App (PWA) installation
/// Handles install prompts and provides platform-specific instructions
class PWAService {
  static final PWAService _instance = PWAService._internal();
  static PWAService get instance => _instance;

  PWAService._internal();

  /// Whether the PWA is currently installed
  bool get isInstalled {
    // On web, check if running in standalone mode
    if (kIsWeb) {
      // This would be implemented with JS interop in a real app
      // For now, return false
      return false;
    }
    return false;
  }

  /// Whether the PWA installation prompt is available
  bool get canInstall {
    // This would be set when beforeinstallprompt event fires
    // For now, return false (user needs to use browser menu)
    return false;
  }

  /// Whether PWA features are supported in this browser
  bool get supportsPWA {
    // PWA features are only available on web
    return kIsWeb;
  }

  /// Show the native PWA installation prompt (if available)
  void showInstallPrompt() {
    // This would trigger the native install prompt
    // Requires JS interop to call prompt() on the saved event
    debugPrint('PWA install prompt requested');
  }

  /// Get platform-specific installation instructions
  String getInstallInstructions() {
    if (!kIsWeb) {
      return 'PWA installation is only available on web browsers.';
    }

    // Detect browser/platform (simplified - would use user agent in real app)
    return _getGenericInstructions();
  }

  String _getGenericInstructions() {
    return '''
1. Tap the browser menu (⋮ or share icon)
2. Look for "Install App" or "Add to Home Screen"
3. Follow the prompts to install

Once installed, you can access VerveStride like a native app!''';
  }

  /// Get browser-specific installation instructions
  String _getChromeInstructions() {
    return '''
Chrome:
1. Tap the menu icon (⋮) in the top right
2. Select "Install app" or "Add to Home Screen"
3. Confirm by tapping "Install"''';
  }

  String _getSafariInstructions() {
    return '''
Safari (iOS):
1. Tap the share button (□↑) at the bottom
2. Scroll down and tap "Add to Home Screen"
3. Name the app and tap "Add"''';
  }

  String _getFirefoxInstructions() {
    return '''
Firefox:
1. Tap the menu icon (⋮) in the top right
2. Select "Install" or "Add to Home Screen"
3. Confirm the installation''';
  }

  String _getEdgeInstructions() {
    return '''
Edge:
1. Tap the menu icon (⋮) in the top right
2. Select "Apps" > "Install this site as an app"
3. Confirm by tapping "Install"''';
  }
}
