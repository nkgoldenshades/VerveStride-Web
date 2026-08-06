import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../core/routes.dart';
import 'package:vervestride/models/activity_data.dart';
import 'package:vervestride/models/user_profile.dart';
import '../services/local_storage_service.dart';
import 'friendly_notification_service.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  GlobalKey<NavigatorState>? navigatorKey;

  FirebaseMessaging get _firebaseMessaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const int _hydrationReminderId1 = 51001;
  static const int _hydrationReminderId2 = 51002;
  static const int _movementReminderId = 52001;

  static const int _friendlyReminderId1 = 54001;
  static const int _friendlyReminderId2 = 54002;

  static const String _humaneChannelId = 'humane_reminders_channel';
  static const String _humaneChannelName = 'Reminders';

  static const int _activityNotificationId = 53001;
  static const String _activityChannelId = 'activity_tracking_channel_v2';
  static const String _activityChannelName = 'Activity Tracking';

  VoidCallback? onActivityPause;
  VoidCallback? onActivityResume;
  VoidCallback? onActivityStop;

  String? _fcmToken;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _backgroundMessageSubscription;

  String? get fcmToken => _fcmToken;

  RemoteMessage? _latestMessage;
  RemoteMessage? get latestMessage => _latestMessage;

  bool _tzInitialized = false;

  Future<void> _ensureTzInitialized() async {
    if (_tzInitialized) return;
    tz.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // If we can't resolve local tz, tz.local stays as-is.
    }
    _tzInitialized = true;
  }

  Future<void> rescheduleFriendlyReminders() async {
    if (kIsWeb) return;
    await _ensureTzInitialized();

    try {
      await _localNotifications.cancel(_friendlyReminderId1);
      await _localNotifications.cancel(_friendlyReminderId2);
    } catch (_) {
      // no-op
    }

    final settings = await LocalStorageService.instance.getAppSettings() ??
        <String, dynamic>{};

    final enabled = (settings['reminders_friendly_enabled'] as bool?) ?? true;
    if (!enabled) return;

    final startMin =
        (settings['reminders_active_start_min'] as num?)?.toInt() ?? (9 * 60);
    final endMin =
        (settings['reminders_active_end_min'] as num?)?.toInt() ?? (21 * 60);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    var start = startMin;
    var end = endMin;
    if (end <= start) {
      start = 9 * 60;
      end = 21 * 60;
    }

    final startTime = today.add(Duration(minutes: start));
    final endTime = today.add(Duration(minutes: end));

    DateTime? pick(double t) {
      final when = today.add(
        Duration(minutes: start + ((end - start) * t).round()),
      );
      final clamped = _clampToWindow(when, startTime, endTime);
      if (clamped == null) return null;
      if (!clamped.isAfter(now)) return null;
      return clamped;
    }

    final candidates = <DateTime?>[
      pick(0.30),
      pick(0.70),
    ].whereType<DateTime>().toList();

    if (candidates.isEmpty) return;

    await _scheduleOne(
      id: _friendlyReminderId1,
      when: candidates.first,
      title: 'VerveStride',
      body: 'Quick check-in: how are your goals going?',
      payload: 'friendly',
    );

    if (candidates.length >= 2) {
      await _scheduleOne(
        id: _friendlyReminderId2,
        when: candidates[1],
        title: 'VerveStride',
        body: 'Small steps count. Want to log water or a quick walk?',
        payload: 'friendly',
      );
    }
  }

  Future<void> initialize() async {
    // Initialize local notifications for all platforms
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Android notification channels for scheduled reminders and activity tracking
    if (!kIsWeb) {
      try {
        final android =
            _localNotifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        
        // Create humane reminders channel
        await android?.createNotificationChannel(
          const AndroidNotificationChannel(
            _humaneChannelId,
            _humaneChannelName,
            description: 'Hydration and movement reminders',
            importance: Importance.defaultImportance,
          ),
        );
        
        // Create activity tracking channel
        await android?.createNotificationChannel(
          const AndroidNotificationChannel(
            _activityChannelId,
            _activityChannelName,
            description: 'Ongoing activity tracking status',
            importance: Importance.low,
          ),
        );
      } catch (_) {
        // no-op
      }
    }

    if (kIsWeb) {
      debugPrint('NotificationService: web mode - using local notifications only.');
      await rescheduleHumaneReminders();
      return;
    }

    // Request permission for iOS
    await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // Get FCM token
    _fcmToken = await _firebaseMessaging.getToken();
    if (kDebugMode) debugPrint('FCM Token: $_fcmToken');

    // Handle foreground messages
    await _messageSubscription?.cancel();
    _messageSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle message when app is opened from notification
    await _backgroundMessageSubscription?.cancel();
    _backgroundMessageSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(
      _handleMessageOpenedApp,
    );

    // Check for initial message if app was opened from notification
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    // Schedule reminders after Firebase initialization
    await rescheduleHumaneReminders();

    // Schedule friendly reminders (timely scheduled notifications, not hourly timers)
    await rescheduleFriendlyReminders();
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Received foreground message: ${message.messageId}');
    _latestMessage = message;
    notifyListeners();

    // Show local notification for foreground messages
    _showLocalNotification(message);
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('App opened from notification: ${message.messageId}');
    _latestMessage = message;
    notifyListeners();
    // Handle navigation or other actions when app is opened from notification
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'activity_monitoring_channel',
      'Activity Monitoring',
      channelDescription: 'Notifications for activity monitoring',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Activity Update',
      message.notification?.body ?? 'Your activity status has been updated',
      details,
      payload: message.data.toString(),
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint(
        'Notification tapped: ${response.payload}, actionId: ${response.actionId}');

    if (response.actionId == 'activity_pause') {
      onActivityPause?.call();
    } else if (response.actionId == 'activity_resume') {
      onActivityResume?.call();
    } else if (response.actionId == 'activity_stop') {
      onActivityStop?.call();
    } else {
      try {
        navigatorKey?.currentState?.pushNamedAndRemoveUntil(
          Routes.navigation,
          (route) => false,
        );
      } catch (_) {
        // no-op
      }
    }
  }

  Future<void> rescheduleHumaneReminders() async {
    if (kIsWeb) return; // Web doesn't support OS-level scheduled notifications

    await _ensureTzInitialized();

    // Always cancel existing ones first to keep the system boring.
    try {
      await _localNotifications.cancel(_hydrationReminderId1);
      await _localNotifications.cancel(_hydrationReminderId2);
      await _localNotifications.cancel(_movementReminderId);
    } catch (_) {
      // no-op
    }

    final settings = await LocalStorageService.instance.getAppSettings() ??
        <String, dynamic>{};

    final hydrationEnabled =
        (settings['reminders_hydration_enabled'] as bool?) ?? true;
    final movementEnabled =
        (settings['reminders_movement_enabled'] as bool?) ?? false;
    final startMin =
        (settings['reminders_active_start_min'] as num?)?.toInt() ?? (9 * 60);
    final endMin =
        (settings['reminders_active_end_min'] as num?)?.toInt() ?? (21 * 60);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    var start = startMin;
    var end = endMin;
    if (end <= start) {
      start = 9 * 60;
      end = 21 * 60;
    }

    final startTime = today.add(Duration(minutes: start));
    final endTime = today.add(Duration(minutes: end));

    final hydrationDone = await _isHydrationDoneToday(today);
    final movementDone = await _isMovementDoneToday(today);

    if (hydrationEnabled && !hydrationDone) {
      final candidates = <DateTime?>[
        _clampToWindow(
          today.add(Duration(minutes: start + ((end - start) * 0.55).round())),
          startTime,
          endTime,
        ),
        _clampToWindow(
          today.add(Duration(minutes: start + ((end - start) * 0.85).round())),
          startTime,
          endTime,
        ),
      ].whereType<DateTime>().where((t) => t.isAfter(now)).toList();

      if (candidates.isNotEmpty) {
        await _scheduleOne(
          id: _hydrationReminderId1,
          when: candidates.first,
          title: 'Hydration',
          body: 'Quick water break?',
          payload: 'hydration',
        );
      }
      if (candidates.length >= 2) {
        await _scheduleOne(
          id: _hydrationReminderId2,
          when: candidates[1],
          title: 'Hydration',
          body: 'A glass of water could help right now.',
          payload: 'hydration',
        );
      }
    }

    if (movementEnabled && !movementDone) {
      final when =
          today.add(Duration(minutes: (end - 90).clamp(start + 30, end - 1)));
      final candidate = _clampToWindow(when, startTime, endTime);
      if (candidate != null && candidate.isAfter(now)) {
        await _scheduleOne(
          id: _movementReminderId,
          when: candidate,
          title: 'Movement',
          body: 'A short walk still counts.',
          payload: 'movement',
        );
      }
    }
  }

  DateTime? _clampToWindow(DateTime t, DateTime start, DateTime end) {
    if (t.isBefore(start)) return start;
    if (t.isAfter(end)) return null;
    return t;
  }

  Future<void> _scheduleOne({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    required String payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _humaneChannelId,
      _humaneChannelName,
      channelDescription: 'Hydration and movement reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final whenTz = tz.TZDateTime.from(when, tz.local);
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      whenTz,
      details,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  Future<bool> _isHydrationDoneToday(DateTime today) async {
    final profileJson = await LocalStorageService.instance.getUserProfile();
    if (profileJson == null) return true;
    final profile = UserProfile.fromJson(profileJson);

    final targets = profile.calculateDailyTargets(forDate: today);
    final active = profile.activeGoalForDate(today);

    final drunk = await LocalStorageService.instance.getWaterForDate(today);
    final targetWater =
        (active?.targetWaterMl != null && active!.targetWaterMl! > 0)
            ? active.targetWaterMl!
            : ((targets['waterMl'] as num?)?.toInt() ??
                (profile.weightKg * 35).round());

    final rawWaterRatio = targetWater > 0 ? (drunk / targetWater) : 0.0;
    return rawWaterRatio >= 0.70;
  }

  int _estimateBurnTargetFromActivityLevel(int level) {
    switch (level) {
      case 1:
        return 200;
      case 2:
        return 300;
      case 3:
        return 400;
      case 4:
        return 500;
      default:
        return 400;
    }
  }

  Future<bool> _isMovementDoneToday(DateTime today) async {
    final profileJson = await LocalStorageService.instance.getUserProfile();
    if (profileJson == null) return true;
    final profile = UserProfile.fromJson(profileJson);
    final active = profile.activeGoalForDate(today);

    final activities =
        await LocalStorageService.instance.getActivitiesForDate(today);
    final burned = activities.fold<int>(0, (sum, a) => sum + a.caloriesBurned);
    final targetBurn =
        (active?.targetBurnCalories != null && active!.targetBurnCalories! > 0)
            ? active.targetBurnCalories!
            : _estimateBurnTargetFromActivityLevel(profile.activityLevel);

    final burnPercent =
        targetBurn > 0 ? (burned / targetBurn).clamp(0.0, 1.0) : 0.0;
    return burnPercent >= 0.999;
  }

  // Send activity monitoring notification
  Future<void> sendActivityMonitoringNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'activity_monitoring_channel',
      'Activity Monitoring',
      channelDescription: 'Notifications for activity monitoring',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: data?.toString(),
    );
  }

  Future<void> showActivityNotification(ActivityData activity) async {
    if (kIsWeb) return;

    final String status = activity.isPaused ? ' (Paused)' : '';
    final String title = '${activity.type.displayName} Activity$status';
    final String body =
        'Time: ${activity.formattedDuration} | Distance: ${activity.formattedDistance}';

    final List<AndroidNotificationAction> androidActions = [
      if (activity.isPaused)
        const AndroidNotificationAction(
          'activity_resume',
          'Resume',
          showsUserInterface: true,
        )
      else
        const AndroidNotificationAction(
          'activity_pause',
          'Pause',
          showsUserInterface: true,
        ),
      const AndroidNotificationAction(
        'activity_stop',
        'Stop',
        showsUserInterface: true,
        cancelNotification: true,
      ),
    ];

    final androidDetails = AndroidNotificationDetails(
      _activityChannelId,
      _activityChannelName,
      channelDescription: 'Ongoing activity tracking status',
      importance:
          Importance.low, // Lower importance to avoid sound/pop on every update
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: true,
      onlyAlertOnce: true,
      actions: androidActions,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false, // Don't pop up every time
      presentBadge: true,
      presentSound: false,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      _activityNotificationId,
      title,
      body,
      details,
      payload: 'activity_tracking',
    );
  }

  Future<void> cancelActivityNotification() async {
    await _localNotifications.cancel(_activityNotificationId);
  }

  @override
  Future<void> dispose() async {
    await _messageSubscription?.cancel();
    await _backgroundMessageSubscription?.cancel();
    FriendlyNotificationService.instance.stopFriendlyNotifications();
    super.dispose();
  }

  // Send friendly notification method
  Future<void> sendFriendlyNotification({
    required String title,
    required String body,
    String? type,
  }) async {
    await sendActivityMonitoringNotification(
      title: title,
      body: body,
      data: {'type': 'friendly', 'category': type ?? 'general'},
    );
  }
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId}');
  // Handle background messages here
}
