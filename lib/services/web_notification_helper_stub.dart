// Stub for non-web platforms
class WebNotificationHelper {
  static bool get isSupported => false;
  static String get permission => 'denied';
  static Future<String> requestPermission() async => 'denied';
  static Future<void> showNotification({
    required String title,
    String? body,
    String? icon,
    String? badge,
    String? tag,
    bool? requireInteraction,
    List<int>? vibrate,
  }) async {
    // no-op on mobile
  }
}
