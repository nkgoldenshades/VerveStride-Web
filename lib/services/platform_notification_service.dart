import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class PlatformNotificationService {
  static final PlatformNotificationService instance = PlatformNotificationService._internal();
  factory PlatformNotificationService() => instance;
  PlatformNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Platform-specific initialization
    if (kIsWeb) {
      await _initializeWeb();
    } else if (Platform.isAndroid) {
      await _initializeAndroid();
    } else if (Platform.isIOS) {
      await _initializeIOS();
    } else {
      await _initializeDesktop();
    }

    _isInitialized = true;
  }

  Future<void> _initializeWeb() async {
    debugPrint('🔔 Initializing Web Notifications');
    
    tz.initializeTimeZones();
    
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    debugPrint('✅ Web Notifications initialized');
  }

  Future<void> _initializeAndroid() async {
    debugPrint('🔔 Initializing Android Notifications');
    
    // Request notification permissions for Android 13+
    if (await _requestAndroidPermissions()) {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channels for Android
      await _createAndroidChannels();
      
      debugPrint('✅ Android Notifications initialized');
    } else {
      debugPrint('❌ Android notification permissions denied');
    }
  }

  Future<void> _initializeIOS() async {
    debugPrint('🔔 Initializing iOS Notifications');
    
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(iOS: iosSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    debugPrint('✅ iOS Notifications initialized');
  }

  Future<void> _initializeDesktop() async {
    debugPrint('🔔 Initializing Desktop Notifications');
    
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    debugPrint('✅ Desktop Notifications initialized');
  }

  Future<bool> _requestAndroidPermissions() async {
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      // Android 13+ (API 33+) requires POST_NOTIFICATIONS permission
      if (sdkInt >= 33) {
        final status = await Permission.notification.request();
        return status.isGranted;
      }
      
      // Older Android versions don't need explicit permission
      return true;
    } catch (e) {
      debugPrint('❌ Error requesting Android permissions: $e');
      return false;
    }
  }

  Future<void> _createAndroidChannels() async {
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // Android 10+ optimized friendly notifications channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'friendly_notifications_channel',
        'Friendly Reminders',
        description: 'Personalized fitness and wellness messages',
        importance: Importance.high,
        showBadge: true,
        enableVibration: true,
        playSound: true,
      ),
    );

    // Activity tracking channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'activity_tracking_channel',
        'Activity Tracking',
        description: 'Workout and activity updates',
        importance: Importance.defaultImportance,
        showBadge: true,
      ),
    );

    // Android 10+ exclusive channel for advanced features
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'android_10_plus_channel',
        'Android 10+ Features',
        description: 'Advanced notifications for Android 10+ devices',
        importance: Importance.high,
        showBadge: true,
        enableLights: true,
        enableVibration: true,
        playSound: true,
      ),
    );

    debugPrint('✅ Android notification channels created (including Android 10+ channel)');
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    // Handle notification tap actions
  }

  Future<void> showFriendlyNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      debugPrint('❌ Notification service not initialized');
      return;
    }

    AndroidNotificationDetails? androidDetails;
    DarwinNotificationDetails? iosDetails;

    if (!kIsWeb && Platform.isAndroid) {
      // Check if Android 10+ for enhanced features
      final isAndroid10PlusDevice = await isAndroid10Plus();
      
      androidDetails = AndroidNotificationDetails(
        isAndroid10PlusDevice ? 'android_10_plus_channel' : 'friendly_notifications_channel',
        'Friendly Reminders',
        channelDescription: 'Personalized fitness and wellness messages',
        importance: Importance.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: const BigTextStyleInformation(''),
        enableVibration: true,
        playSound: true,
        enableLights: isAndroid10PlusDevice,
        color: const Color(0xFF4CAF50), // Green color for fitness theme
        ledColor: const Color(0xFF4CAF50),
        ledOnMs: 1000,
        ledOffMs: 500,
      );
    }

    if (!kIsWeb && Platform.isIOS) {
      iosDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
      );
    }

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );

    debugPrint('🔔 Friendly notification sent: $title - $body');
  }

  Future<bool> isAndroid10Plus() async {
    if (!Platform.isAndroid || kIsWeb) return false;
    
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      return androidInfo.version.sdkInt >= 29; // Android 10+ is API 29+
    } catch (e) {
      debugPrint('Could not detect Android version: $e');
      return false;
    }
  }

  Future<void> showScheduledNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    if (!_isInitialized) return;

    AndroidNotificationDetails? androidDetails;
    DarwinNotificationDetails? iosDetails;

    if (!kIsWeb && Platform.isAndroid) {
      androidDetails = const AndroidNotificationDetails(
        'friendly_notifications_channel',
        'Friendly Reminders',
        channelDescription: 'Personalized fitness and wellness messages',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );
    }

    if (!kIsWeb && Platform.isIOS) {
      iosDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
    }

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.zonedSchedule(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      details,
      payload: payload,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint('🔔 Scheduled notification set for: $scheduledTime');
  }

  Future<bool> hasPermission() async {
    if (kIsWeb) return true; // Web permissions are handled by browser
    
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      return status.isGranted;
    }
    
    if (Platform.isIOS) {
      // iOS permissions are requested during initialization
      return true;
    }
    
    return true; // Desktop platforms
  }

  Future<void> requestPermission() async {
    if (Platform.isAndroid) {
      await _requestAndroidPermissions();
    }
    // iOS permissions are handled during initialization
  }

  String getPlatformInfo() {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }
}
