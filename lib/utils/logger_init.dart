import 'package:flutter/foundation.dart';
import 'secure_logger.dart';

/// Initialize secure logging for the app
/// Call this ONCE at app startup, before any other code runs
void initializeSecureLogging() {
  logger.init();
  
  // Log initialization only in debug mode
  if (kDebugMode) {
    logger.i('🔒 Secure logging initialized');
    logger.i('Build mode: ${kReleaseMode ? "RELEASE" : "DEBUG"}');
    logger.i('Platform: ${kIsWeb ? "WEB" : "NATIVE"}');
  }
}

/// Disable all Flutter framework debug prints in release mode
void disableDebugPrintsInRelease() {
  if (kReleaseMode) {
    // Override debugPrint to do nothing in release mode
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
}
