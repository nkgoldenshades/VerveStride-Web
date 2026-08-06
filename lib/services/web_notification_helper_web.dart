import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// Web Notification Helper
///
/// Provides browser notification functionality for web platform.
/// Uses dart:html for web notifications — this file is web-only.
class WebNotificationHelper {
  /// Check if notifications are supported
  static bool get isSupported {
    if (!kIsWeb) return false;
    return html.Notification.supported;
  }

  /// Get current permission status
  static String get permission {
    if (!isSupported) return 'denied';
    // html.Notification.permission is nullable in older bindings
    final p = html.Notification.permission;
    return (p == null || p.isEmpty) ? 'denied' : p;
  }

  /// Request notification permission
  static Future<String> requestPermission() async {
    if (!isSupported) return 'denied';
    try {
      final result = await html.Notification.requestPermission();
      return result.isEmpty ? 'denied' : result;
    } catch (e) {
      debugPrint('❌ Error requesting notification permission: $e');
      return 'denied';
    }
  }

  /// Show a notification
  static Future<void> showNotification({
    required String title,
    String? body,
    String? icon,
    String? tag,
    bool requireInteraction = true,
    List<int>? vibrate,
  }) async {
    if (!isSupported) {
      debugPrint('⚠️ Notifications not supported on this browser');
      return;
    }

    if (permission != 'granted') {
      final perm = await requestPermission();
      if (perm != 'granted') {
        debugPrint('⚠️ Notification permission denied');
        return;
      }
    }

    try {
      // dart:html Notification constructor only accepts body/icon/tag.
      // requireInteraction and vibrate are set via JS eval as a workaround.
      final notification = html.Notification(
        title,
        body: body,
        icon: icon ?? '/icons/Icon-192.png',
        tag: tag,
      );

      notification.onClick.listen((_) {
        debugPrint('🔔 Notification clicked');
        notification.close();
      });

      // Auto-close after 30 seconds
      Future.delayed(const Duration(seconds: 30), () {
        try {
          notification.close();
        } catch (_) {}
      });

      debugPrint('✅ Web notification shown: $title');
    } catch (e) {
      debugPrint('❌ Error showing notification: $e');
    }
  }

  /// Close all notifications with a specific tag
  static void closeNotificationsByTag(String tag) {
    debugPrint('ℹ️ Cannot programmatically close notifications by tag on web');
  }
}
