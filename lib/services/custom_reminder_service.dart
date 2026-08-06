import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'local_storage_service.dart';
import 'tts_service.dart';
import 'firebase_ai_service.dart';

/// Custom Reminder Service
///
/// Allows both AI and users to schedule custom notifications/reminders
/// with specific times, like alarms or scheduled notifications.
///
/// Features:
/// - Schedule one-time or recurring reminders
/// - AI can suggest and schedule reminders
/// - User can manually create reminders
/// - Supports daily, weekly, or custom schedules
class CustomReminderService {
  static final CustomReminderService instance =
      CustomReminderService._internal();
  factory CustomReminderService() => instance;
  CustomReminderService._internal();

  GlobalKey<NavigatorState>? navigatorKey;

  final LocalStorageService _storage = LocalStorageService.instance;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static const MethodChannel _platform = MethodChannel('com.vervestride/alarm');

  bool _initialized = false;
  bool _tzInitialized = false;

  static const String _kPayloadPrefix = 'custom_reminder:';
  static const String _kActionStop = 'alarm_stop';
  static const String _kActionSnooze = 'alarm_snooze';

  /// Check if battery optimization is ignored, and request exemption if not.
  /// Critical for MIUI/Xiaomi devices where alarms get killed.
  Future<void> ensureBatteryOptimizationExempt() async {
    if (kIsWeb) return;
    try {
      final isIgnoring = await _platform
              .invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          false;
      if (!isIgnoring) {
        await _platform.invokeMethod('requestIgnoreBatteryOptimizations');
      }
    } catch (e) {
      debugPrint('⚠️ Battery optimization check failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UNIVERSAL PERMISSION METHODS (Works on ALL Android versions)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Check if exact alarm permission is granted (Android 12+)
  /// Always returns true on Android 11 and below
  Future<bool> checkAlarmPermission() async {
    if (kIsWeb) return true;
    try {
      final hasPermission =
          await _platform.invokeMethod<bool>('checkAlarmPermission');
      return hasPermission ?? false;
    } catch (e) {
      debugPrint('⚠️ checkAlarmPermission failed: $e');
      return false;
    }
  }

  /// Request exact alarm permission (Android 12+)
  /// Opens app settings on older Android versions
  Future<void> requestAlarmPermission() async {
    if (kIsWeb) return;
    try {
      await _platform.invokeMethod('requestAlarmPermission');
    } catch (e) {
      debugPrint('⚠️ requestAlarmPermission failed: $e');
    }
  }

  /// Check if notification permission is granted (Android 13+)
  /// Always returns true on Android 12 and below
  Future<bool> checkNotificationPermission() async {
    if (kIsWeb) return true;
    try {
      final hasPermission =
          await _platform.invokeMethod<bool>('checkNotificationPermission');
      return hasPermission ?? true;
    } catch (e) {
      debugPrint('⚠️ checkNotificationPermission failed: $e');
      return true;
    }
  }

  /// Request notification permission (Android 13+)
  Future<void> requestNotificationPermission() async {
    if (kIsWeb) return;
    try {
      await _platform.invokeMethod('requestNotificationPermission');
    } catch (e) {
      debugPrint('⚠️ requestNotificationPermission failed: $e');
    }
  }

  /// Check if battery optimization is disabled
  Future<bool> checkBatteryOptimization() async {
    if (kIsWeb) return true;
    try {
      final isIgnoring =
          await _platform.invokeMethod<bool>('checkBatteryOptimization');
      return isIgnoring ?? false;
    } catch (e) {
      debugPrint('⚠️ checkBatteryOptimization failed: $e');
      return false;
    }
  }

  /// Request battery optimization exemption
  /// CRITICAL for alarms on Xiaomi/MIUI, Huawei/EMUI, Oppo/ColorOS
  Future<void> requestBatteryOptimizationExemption() async {
    if (kIsWeb) return;
    try {
      await _platform.invokeMethod('requestBatteryOptimizationExemption');
    } catch (e) {
      debugPrint('⚠️ requestBatteryOptimizationExemption failed: $e');
    }
  }

  /// Get device information for debugging
  /// Helps identify manufacturer-specific issues
  Future<Map<String, dynamic>> getDeviceInfo() async {
    if (kIsWeb) return {'platform': 'web'};
    try {
      final info = await _platform.invokeMethod<Map>('getDeviceInfo');
      return Map<String, dynamic>.from(info ?? {});
    } catch (e) {
      debugPrint('⚠️ getDeviceInfo failed: $e');
      return {};
    }
  }

  /// Open app settings (works on all Android versions)
  Future<void> openAppSettings() async {
    if (kIsWeb) return;
    try {
      await _platform.invokeMethod('openAppSettings');
    } catch (e) {
      debugPrint('⚠️ openAppSettings failed: $e');
    }
  }

  /// Comprehensive permission check for alarms
  /// Returns true if ALL permissions are granted
  Future<bool> hasAllAlarmPermissions() async {
    if (kIsWeb) return true;

    final alarmPerm = await checkAlarmPermission();
    final notifPerm = await checkNotificationPermission();
    final batteryOpt = await checkBatteryOptimization();

    return alarmPerm && notifPerm && batteryOpt;
  }

  /// Request all necessary permissions for alarms
  /// Shows dialogs explaining each permission
  Future<bool> requestAllAlarmPermissions(BuildContext context) async {
    if (kIsWeb) return true;

    try {
      // Check current status
      final deviceInfo = await getDeviceInfo();
      final manufacturer =
          (deviceInfo['manufacturer'] as String?)?.toLowerCase() ?? '';

      debugPrint('🔍 Device: $manufacturer ${deviceInfo['model']}');
      debugPrint(
          '🔍 Android: ${deviceInfo['androidVersion']} (SDK ${deviceInfo['sdkInt']})');

      // 1. Notification Permission (Android 13+)
      if (!await checkNotificationPermission()) {
        final shouldRequest = await _showPermissionDialog(
          context,
          'Notification Permission',
          'VerveStride needs notification permission to show alarm reminders.',
          '🔔',
        );
        if (shouldRequest) {
          await requestNotificationPermission();
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      // 2. Exact Alarm Permission (Android 12+)
      if (!await checkAlarmPermission()) {
        final shouldRequest = await _showPermissionDialog(
          context,
          'Exact Alarm Permission',
          'VerveStride needs permission to schedule exact alarms. '
              'This ensures your workout reminders ring at the precise time you set.',
          '⏰',
        );
        if (shouldRequest) {
          await requestAlarmPermission();
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      // 3. Battery Optimization (Critical for Chinese manufacturers)
      if (!await checkBatteryOptimization()) {
        final isChinese = manufacturer.contains('xiaomi') ||
            manufacturer.contains('huawei') ||
            manufacturer.contains('oppo') ||
            manufacturer.contains('vivo') ||
            manufacturer.contains('realme') ||
            manufacturer.contains('oneplus');

        final message = isChinese
            ? 'Your device ($manufacturer) has aggressive battery management that can prevent alarms from ringing.\n\n'
                'Please disable battery optimization for VerveStride to ensure alarms work reliably.'
            : 'Please disable battery optimization for VerveStride to ensure alarms work reliably, '
                'especially when the screen is off.';

        final shouldRequest = await _showPermissionDialog(
          context,
          'Battery Optimization',
          message,
          '🔋',
        );
        if (shouldRequest) {
          await requestBatteryOptimizationExemption();
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      // Recheck all permissions
      return await hasAllAlarmPermissions();
    } catch (e) {
      debugPrint('❌ requestAllAlarmPermissions failed: $e');
      return false;
    }
  }

  /// Show permission explanation dialog
  Future<bool> _showPermissionDialog(
    BuildContext context,
    String title,
    String message,
    String emoji,
  ) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(child: Text(title)),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Skip'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Grant Permission'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Start continuous alarm ringing via Android foreground service
  Future<void> startAlarmService({
    required String alarmId,
    required String title,
    required String body,
    String? customSoundUri,
  }) async {
    if (kIsWeb) return;
    try {
      await _platform.invokeMethod('startAlarmService', {
        'alarmId': alarmId,
        'title': title,
        'body': body,
        'useDefaultSound': customSoundUri == null,
        'customSoundUri': customSoundUri,
      });
      debugPrint('✅ Alarm foreground service started');
    } catch (e) {
      debugPrint('❌ Failed to start alarm service: $e');
    }
  }

  /// Stop continuous alarm ringing
  Future<void> stopAlarmService() async {
    if (kIsWeb) return;
    try {
      await _platform.invokeMethod('stopAlarmService');
      debugPrint('✅ Alarm foreground service stopped');
    } catch (e) {
      debugPrint('❌ Failed to stop alarm service: $e');
    }
  }

  Future<void> _ensureTzInitialized() async {
    if (_tzInitialized) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // no-op
    }
    _tzInitialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    // Re-initialize with our callback so alarm tap/action responses are routed here.
    // flutter_local_notifications uses a single plugin instance; re-initializing
    // only updates the callback — it does NOT create duplicate channels or schedules.
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    if (!kIsWeb) {
      try {
        final android = _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

        // Delete old channel first — Android caches sound=false permanently
        // until the channel is deleted and recreated
        await android?.deleteNotificationChannel('reminders_alarm');

        await android?.createNotificationChannel(
          const AndroidNotificationChannel(
            'reminders_alarm',
            'Alarms',
            description: 'Full-screen alarms that ring even on silent mode',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );

        await android?.createNotificationChannel(
          const AndroidNotificationChannel(
            'reminders_notification',
            'Reminders',
            description: 'Reminder notifications',
            importance: Importance.high,
          ),
        );
      } catch (_) {
        // no-op
      }
    }

    await _ensureTzInitialized();
    _initialized = true;
  }

  void _onNotificationResponse(NotificationResponse response) {
    final actionId = response.actionId;
    final payload = response.payload ?? '';
    if (!payload.startsWith(_kPayloadPrefix)) return;
    final reminderId = payload.substring(_kPayloadPrefix.length);
    if (reminderId.isEmpty) return;

    debugPrint(
        '🔔 [Notification Response] Action: $actionId, Reminder: $reminderId');

    if (actionId == _kActionStop) {
      debugPrint('🛑 [Notification Response] User clicked Stop');
      stopAlarmService();
      cancelReminder(reminderId, cancelNotification: true);
      return;
    }

    if (actionId == _kActionSnooze) {
      debugPrint('💤 [Notification Response] User clicked Snooze');
      stopAlarmService();
      _promptAndSnooze(reminderId);
      return;
    }

    // Default tap on alarm notification - start foreground service for continuous ringing
    debugPrint('👆 [Notification Response] User tapped notification (default)');
    _startAlarmRinging(reminderId);
  }

  /// Start continuous alarm ringing for a reminder
  Future<void> _startAlarmRinging(String reminderId) async {
    final reminder = await getReminderById(reminderId);
    if (reminder == null) return;

    if (reminder.alertType != 'alarm') return;

    // alarm_sound_mode: 'normal' | 'mp3' | 'ai' | 'ai_music'
    final mode = reminder.metadata['alarm_sound_mode'] as String? ?? 'normal';
    final aiStyle = reminder.metadata['ai_wake_style'] as String? ?? '';
    final customSoundUri = reminder.metadata['custom_sound_uri'] as String?;

    final playMusic = mode == 'normal' || mode == 'mp3' || mode == 'ai_music';
    final playAI = mode == 'ai' || mode == 'ai_music';

    if (playMusic) {
      await startAlarmService(
        alarmId: reminderId,
        title: reminder.title,
        body: reminder.body,
        customSoundUri: (mode == 'mp3') ? customSoundUri : null,
      );
    }

    if (playAI) {
      final delay =
          playMusic ? const Duration(milliseconds: 1500) : Duration.zero;
      Future.delayed(delay, () async {
        try {
          final todayAlarms = await _countTodayAlarms();
          final message = await _buildAIWakeMessage(
            reminder.title,
            todayAlarms,
            aiStyle,
          );
          await TTSService.instance.initialize();
          await TTSService.instance.speak(message);
        } catch (e) {
          debugPrint('⚠️ TTS wake message failed: $e');
        }
      });
    }
  }

  /// Count how many alarms are set for today
  Future<int> _countTodayAlarms() async {
    final all = await getAllReminders();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    return all.where((r) {
      if (!r.isActive || r.alertType != 'alarm') return false;
      if (r.repeat == 'daily' || r.repeat == 'weekly') return true;
      return r.scheduledTime.isAfter(todayStart) &&
          r.scheduledTime.isBefore(todayEnd);
    }).length;
  }

  /// Build wake-up message — uses AI style if provided, else a sharp default
  Future<String> _buildAIWakeMessage(
    String title,
    int totalToday,
    String style,
  ) async {
    final hour = DateTime.now().hour;
    final timeWord = hour < 12 ? 'Morning' : (hour < 17 ? 'Hey' : 'Evening');
    final countPart =
        totalToday > 1 ? '$totalToday alarms today.' : 'One alarm today.';

    if (style.trim().isEmpty) {
      // Default: short and direct
      return '$timeWord. $title. $countPart';
    }

    // User described a style — generate via AI
    try {
      final prompt =
          'You are an alarm voice assistant. Generate a short wake-up message '
          '(max 2 sentences) for an alarm called "$title". '
          'There are $totalToday alarms set today. '
          'Style instruction from user: "$style". '
          'Be direct. No emojis. No hashtags.';
      final response = await _firebaseAI(prompt);
      return response.isNotEmpty ? response : '$timeWord. $title. $countPart';
    } catch (_) {
      return '$timeWord. $title. $countPart';
    }
  }

  Future<String> _firebaseAI(String prompt) async {
    try {
      return await FirebaseAIService.instance.chatWithAI(prompt);
    } catch (_) {
      return '';
    }
  }

  Future<void> _promptAndSnooze(String reminderId) async {
    debugPrint('💤 [Snooze] Starting snooze flow for reminder: $reminderId');

    final reminder = await getReminderById(reminderId);
    if (reminder == null) {
      debugPrint('❌ [Snooze] Reminder not found: $reminderId');
      return;
    }

    debugPrint('💤 [Snooze] Found reminder: ${reminder.title}');

    // Try multiple times to get context
    BuildContext? dialogContext;
    for (int i = 0; i < 3; i++) {
      dialogContext = navigatorKey?.currentContext;
      if (dialogContext != null) break;
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (dialogContext == null) {
      debugPrint('❌ [Snooze] No context available after retries');
      return;
    }

    debugPrint('💤 [Snooze] Got context, showing dialog...');

    final controller = TextEditingController(text: '10');
    final minutes = await showDialog<int>(
      context: dialogContext,
      barrierDismissible: false, // Prevent accidental dismissal
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Snooze Alarm'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Snooze "${reminder.title}" for how many minutes?'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Minutes',
                  hintText: 'e.g., 10',
                  suffixText: 'min',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                debugPrint('💤 [Snooze] User cancelled snooze');
                Navigator.pop(ctx);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text.trim());
                if (parsed == null || parsed <= 0) {
                  debugPrint('❌ [Snooze] Invalid minutes: ${controller.text}');
                  Navigator.pop(ctx);
                } else {
                  debugPrint('💤 [Snooze] User selected $parsed minutes');
                  Navigator.pop(ctx, parsed);
                }
              },
              child: const Text('Snooze'),
            ),
          ],
        );
      },
    );

    if (minutes == null) {
      debugPrint('💤 [Snooze] No minutes selected, snooze cancelled');
      return;
    }

    try {
      debugPrint('💤 [Snooze] Cancelling original reminder: $reminderId');
      // Cancel current firing notification.
      await cancelReminder(reminderId, cancelNotification: true);
    } catch (e) {
      debugPrint('⚠️ [Snooze] Error cancelling reminder: $e');
    }

    final snoozedAt = DateTime.now().add(Duration(minutes: minutes));
    debugPrint(
        '💤 [Snooze] Creating new reminder for: ${snoozedAt.toIso8601String()}');

    final newReminderId = await scheduleReminder(
      title: reminder.title,
      body: reminder.body,
      scheduledTime: snoozedAt,
      repeat: 'once',
      createdBy: reminder.createdBy,
      category: reminder.category,
      alertType: reminder.alertType,
      metadata: {
        ...reminder.metadata,
        'snoozed_from': reminder.id,
        'snooze_minutes': minutes,
      },
    );

    debugPrint('✅ [Snooze] Alarm snoozed! New reminder ID: $newReminderId');
    debugPrint('   Will ring at: ${snoozedAt.toString()}');
    debugPrint('   Alert type: ${reminder.alertType}');
    debugPrint('   Category: ${reminder.category}');

    // Verify the new reminder was actually saved
    final saved = await getReminderById(newReminderId);
    if (saved != null) {
      debugPrint('✅ [Snooze] Verified: New reminder exists in storage');
      debugPrint('   Scheduled time: ${saved.scheduledTime}');
      debugPrint('   Is active: ${saved.isActive}');
    } else {
      debugPrint('❌ [Snooze] ERROR: New reminder NOT found in storage!');
    }

    // Show confirmation to user
    if (navigatorKey?.currentContext != null) {
      try {
        ScaffoldMessenger.of(navigatorKey!.currentContext!).showSnackBar(
          SnackBar(
            content: Text('⏰ Alarm snoozed for $minutes minutes'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        debugPrint('⚠️ [Snooze] Could not show confirmation snackbar: $e');
      }
    }
  }

  /// Get reminder by ID
  Future<CustomReminder?> getReminderById(String id) async {
    final reminders = await getAllReminders();
    try {
      return reminders.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Schedule a custom reminder
  ///
  /// [title] - Notification title
  /// [body] - Notification message
  /// [scheduledTime] - When to show the notification
  /// [repeat] - Repeat type: 'once', 'daily', 'weekly', 'monthly'
  /// [createdBy] - 'user' or 'ai'
  /// [category] - 'workout', 'meal', 'water', 'medication', 'custom'
  /// [alertType] - 'alarm' (full-screen, rings on silent) or 'notification' (notification bar)
  Future<String> scheduleReminder({
    required String title,
    required String body,
    required DateTime scheduledTime,
    String repeat = 'once',
    String createdBy = 'user',
    String category = 'custom',
    String alertType = 'notification',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _ensureInitialized();

      // NEW: Check permissions before scheduling (especially for alarms)
      if (!kIsWeb && alertType == 'alarm') {
        // Check exact alarm permission (Android 12+)
        final hasAlarmPerm = await checkAlarmPermission();
        if (!hasAlarmPerm) {
          throw Exception('Exact alarm permission not granted. '
              'Please enable "Alarms & reminders" permission in Settings.');
        }

        // Check notification permission (Android 13+)
        final hasNotifPerm = await checkNotificationPermission();
        if (!hasNotifPerm) {
          throw Exception('Notification permission not granted. '
              'Please enable notifications in Settings.');
        }

        // Warn about battery optimization (critical for reliability)
        final hasBatteryExempt = await checkBatteryOptimization();
        if (!hasBatteryExempt) {
          debugPrint(
              '⚠️ Battery optimization not disabled - alarm may not ring reliably');
          // Don't throw - just warn, as some users may prefer battery life
        }
      }

      // Generate unique ID
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      // Create reminder object
      final reminder = CustomReminder(
        id: id,
        title: title,
        body: body,
        scheduledTime: scheduledTime,
        repeat: repeat,
        createdBy: createdBy,
        category: category,
        alertType: alertType,
        isActive: true,
        createdAt: DateTime.now(),
        metadata: metadata ?? {},
      );

      // Save to storage
      await _saveReminder(reminder);

      // Schedule notification
      await _scheduleNotification(reminder);

      debugPrint('✅ Reminder scheduled: $title at ${scheduledTime.toString()}');
      return id;
    } catch (e) {
      debugPrint('❌ Failed to schedule reminder: $e');
      rethrow;
    }
  }

  /// Schedule notification based on reminder settings
  Future<void> _scheduleNotification(CustomReminder reminder) async {
    await _ensureInitialized();
    final notificationId = _notificationIdFor(reminder.id);
    final now = tz.TZDateTime.now(tz.local);

    if (reminder.repeat == 'weekly') {
      final weekdays = _selectedWeekdaysFor(reminder);
      if (weekdays.isNotEmpty) {
        var scheduledAny = false;
        for (final weekday in weekdays) {
          final scheduledDate = _nextWeeklyDate(reminder, weekday, now);
          if (scheduledDate == null) continue;
          await _scheduleNotificationAt(
            reminder,
            scheduledDate,
            _notificationIdFor(reminder.id, weekday),
          );
          scheduledAny = true;
        }
        if (!scheduledAny) {
          debugPrint('Weekly reminder has no upcoming dates in range');
        }
        return;
      }
    }

    // Convert to timezone-aware datetime
    final scheduledDate = tz.TZDateTime.from(reminder.scheduledTime, tz.local);

    // Check if time is in the past (with 5 second grace period for processing delays)
    final gracePeriod = now.subtract(const Duration(seconds: 5));
    if (scheduledDate.isBefore(gracePeriod)) {
      debugPrint(
          '⚠️ Scheduled time is in the past: $scheduledDate vs now: $now');

      // If daily repeat, schedule for tomorrow
      if (reminder.repeat == 'daily') {
        final tomorrow = scheduledDate.add(const Duration(days: 1));
        await _scheduleNotificationAt(reminder, tomorrow, notificationId);
        return;
      }

      // For one-time alarms, mark as inactive so they don't show in UI
      if (reminder.repeat == 'once') {
        reminder.isActive = false;
        await _saveReminder(reminder);
        debugPrint('⚠️ Past one-time alarm marked inactive: ${reminder.title}');
        return;
      }

      // Otherwise skip
      debugPrint('⚠️ Skipping past notification');
      return;
    }

    debugPrint('✅ Scheduling notification at: $scheduledDate (now: $now)');
    await _scheduleNotificationAt(reminder, scheduledDate, notificationId);

    // For alarm-type reminders, ALSO schedule via Android AlarmManager so the
    // foreground service starts even when the app is completely killed.
    if (!kIsWeb && reminder.alertType == 'alarm' && reminder.repeat == 'once') {
      try {
        await _platform.invokeMethod('scheduleAlarm', {
          'alarmId': reminder.id,
          'title': reminder.title,
          'body': reminder.body,
          'triggerAtMillis': reminder.scheduledTime.millisecondsSinceEpoch,
        });
        debugPrint(
            '✅ AlarmManager alarm scheduled for ${reminder.scheduledTime}');
      } catch (e) {
        debugPrint(
            '⚠️ AlarmManager schedule failed (will rely on notification tap): $e');
      }
    }
  }

  int _notificationIdFor(String reminderId, [int? suffix]) {
    final base = reminderId.hashCode;
    if (suffix == null) return base;
    return Object.hash(reminderId, suffix);
  }

  List<int> _selectedWeekdaysFor(CustomReminder reminder) {
    final raw = reminder.metadata['weekdays'];
    if (raw is! List) return const [];
    final weekdays = raw
        .whereType<num>()
        .map((value) => value.toInt())
        .where((value) => value >= DateTime.monday && value <= DateTime.sunday)
        .toSet()
        .toList()
      ..sort();
    return weekdays;
  }

  tz.TZDateTime? _nextWeeklyDate(
    CustomReminder reminder,
    int weekday,
    tz.TZDateTime now,
  ) {
    final fromDate = _metadataDate(reminder.metadata['from_date']);
    final toDate = _metadataDate(reminder.metadata['to_date']);
    final start = fromDate ?? reminder.scheduledTime;
    final startAtTime = DateTime(
      start.year,
      start.month,
      start.day,
      reminder.scheduledTime.hour,
      reminder.scheduledTime.minute,
    );
    var candidate = tz.TZDateTime.from(startAtTime, tz.local);

    final daysUntilWeekday = (weekday - candidate.weekday) % 7;
    candidate = candidate.add(Duration(days: daysUntilWeekday));

    while (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 7));
    }

    if (toDate != null) {
      final endOfToDate = tz.TZDateTime(
        tz.local,
        toDate.year,
        toDate.month,
        toDate.day,
        23,
        59,
        59,
      );
      if (candidate.isAfter(endOfToDate)) return null;
    }

    return candidate;
  }

  DateTime? _metadataDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  Future<void> _scheduleNotificationAt(
    CustomReminder reminder,
    tz.TZDateTime scheduledDate,
    int notificationId,
  ) async {
    // Local notifications are not supported the same way on web — data is still saved.
    if (kIsWeb) {
      debugPrint(
        'Custom reminders: stored in app settings (no OS alarm on web).',
      );
      return;
    }

    // Use different settings for alarm vs notification
    final isAlarm = reminder.alertType == 'alarm';

    // Do not reference res/raw/*.mp3 — missing files caused schedule failures on Android.
    final androidDetails = AndroidNotificationDetails(
      isAlarm ? 'reminders_alarm' : 'reminders_notification',
      isAlarm ? 'Alarms' : 'Reminders',
      channelDescription: isAlarm
          ? 'Full-screen alarms that ring even on silent mode'
          : 'Reminder notifications',
      importance: isAlarm ? Importance.max : Importance.high,
      priority: isAlarm ? Priority.max : Priority.high,
      icon: 'app_icon',
      enableVibration: isAlarm,
      playSound: isAlarm, // let the channel play sound so alarm fires audibly
      fullScreenIntent: isAlarm,
      category: isAlarm
          ? AndroidNotificationCategory.alarm
          : AndroidNotificationCategory.reminder,
      actions: isAlarm
          ? const [
              AndroidNotificationAction(
                _kActionStop,
                'Stop',
                showsUserInterface: true,
                cancelNotification: true,
              ),
              AndroidNotificationAction(
                _kActionSnooze,
                'Snooze',
                showsUserInterface: true,
                cancelNotification: true,
              ),
            ]
          : null,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    final payload = '$_kPayloadPrefix${reminder.id}';

    // Schedule based on repeat type
    // IMPORTANT: Alarms need exact scheduling to ring on time
    switch (reminder.repeat) {
      case 'daily':
        await _zonedScheduleWithFallback(
          notificationId: notificationId,
          title: reminder.title,
          body: reminder.body,
          scheduledDate: scheduledDate,
          details: details,
          payload: payload,
          matchDateTimeComponents: DateTimeComponents.time,
          allowExact: true, // Always try exact for reliability
        );
        break;

      case 'weekly':
        await _zonedScheduleWithFallback(
          notificationId: notificationId,
          title: reminder.title,
          body: reminder.body,
          scheduledDate: scheduledDate,
          details: details,
          payload: payload,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          allowExact: true, // Always try exact for reliability
        );
        break;

      case 'once':
      default:
        await _zonedScheduleWithFallback(
          notificationId: notificationId,
          title: reminder.title,
          body: reminder.body,
          scheduledDate: scheduledDate,
          details: details,
          payload: payload,
          matchDateTimeComponents: null,
          allowExact: true, // Always try exact for reliability
        );
        break;
    }
  }

  /// Schedules a notification exactly once, falling back to inexact if exact is blocked.
  Future<void> _zonedScheduleWithFallback({
    required int notificationId,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails details,
    required String payload,
    DateTimeComponents? matchDateTimeComponents,
    required bool allowExact,
  }) async {
    Future<void> doSchedule(AndroidScheduleMode androidMode) async {
      await _notifications.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledDate,
        details,
        payload: payload,
        androidScheduleMode: androidMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    }

    // Try exact first if allowed, then fall back to inexact — never schedule both.
    if (allowExact) {
      try {
        await doSchedule(AndroidScheduleMode.exactAllowWhileIdle);
        return; // scheduled successfully, stop here
      } catch (e) {
        debugPrint(
            '⚠️ zonedSchedule exact failed ($e), falling back to inexact');
      }
    }

    try {
      await doSchedule(AndroidScheduleMode.inexactAllowWhileIdle);
    } catch (e2) {
      debugPrint(
          '⚠️ zonedSchedule inexactAllowWhileIdle failed ($e2), retrying inexact');
      await doSchedule(AndroidScheduleMode.inexact);
    }
  }

  /// Get all reminders
  Future<List<CustomReminder>> getAllReminders() async {
    try {
      final settings = await _storage.getAppSettings() ?? {};
      final remindersJson = settings['custom_reminders'] as List<dynamic>?;

      if (remindersJson == null) return [];

      return remindersJson
          .map((json) => CustomReminder.fromJson(json as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    } catch (e) {
      debugPrint('❌ Failed to load reminders: $e');
      return [];
    }
  }

  /// Get active reminders only (excludes past one-time reminders)
  Future<List<CustomReminder>> getActiveReminders() async {
    final all = await getAllReminders();
    final now = DateTime.now();
    return all.where((r) {
      if (!r.isActive) return false;
      // Hide past one-time reminders
      if (r.repeat == 'once' && r.scheduledTime.isBefore(now)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Get reminders by category
  Future<List<CustomReminder>> getRemindersByCategory(String category) async {
    final all = await getAllReminders();
    return all.where((r) => r.category == category && r.isActive).toList();
  }

  /// Get reminders created by AI
  Future<List<CustomReminder>> getAIReminders() async {
    final all = await getAllReminders();
    return all.where((r) => r.createdBy == 'ai' && r.isActive).toList();
  }

  /// Update a reminder
  Future<void> updateReminder(CustomReminder reminder) async {
    try {
      // Cancel old notification
      await cancelReminder(reminder.id, cancelNotification: true);

      // Save updated reminder
      await _saveReminder(reminder);

      // Reschedule if active
      if (reminder.isActive) {
        await _scheduleNotification(reminder);
      }

      debugPrint('✅ Reminder updated: ${reminder.title}');
    } catch (e) {
      debugPrint('❌ Failed to update reminder: $e');
      rethrow;
    }
  }

  /// Cancel a reminder
  Future<void> cancelReminder(String id,
      {bool cancelNotification = true}) async {
    try {
      final reminders = await getAllReminders();
      final index = reminders.indexWhere((r) => r.id == id);

      if (index == -1) return;

      // Cancel flutter_local_notifications scheduled notification
      if (cancelNotification) {
        await _notifications.cancel(_notificationIdFor(id));
        for (var weekday = DateTime.monday;
            weekday <= DateTime.sunday;
            weekday++) {
          await _notifications.cancel(_notificationIdFor(id, weekday));
        }
      }

      // Also cancel the AlarmManager alarm (for alarm-type reminders)
      if (!kIsWeb) {
        try {
          await _platform.invokeMethod('cancelAlarm', {'alarmId': id});
        } catch (_) {}
      }

      // Remove from storage
      reminders.removeAt(index);
      await _saveAllReminders(reminders);

      debugPrint('✅ Reminder cancelled: $id');
    } catch (e) {
      debugPrint('❌ Failed to cancel reminder: $e');
      rethrow;
    }
  }

  /// Toggle reminder active state
  Future<void> toggleReminder(String id) async {
    try {
      final reminders = await getAllReminders();
      final index = reminders.indexWhere((r) => r.id == id);

      if (index == -1) return;

      final reminder = reminders[index];
      reminder.isActive = !reminder.isActive;

      await updateReminder(reminder);

      debugPrint(
          '✅ Reminder toggled: ${reminder.title} -> ${reminder.isActive}');
    } catch (e) {
      debugPrint('❌ Failed to toggle reminder: $e');
      rethrow;
    }
  }

  /// Delete a reminder permanently
  Future<void> deleteReminder(String id) async {
    await cancelReminder(id, cancelNotification: true);
  }

  /// Clear all reminders
  Future<void> clearAllReminders() async {
    try {
      final reminders = await getAllReminders();

      // Cancel all notifications
      for (final reminder in reminders) {
        await _notifications.cancel(_notificationIdFor(reminder.id));
        for (var weekday = DateTime.monday;
            weekday <= DateTime.sunday;
            weekday++) {
          await _notifications.cancel(_notificationIdFor(reminder.id, weekday));
        }
      }

      // Clear storage
      await _saveAllReminders([]);

      debugPrint('✅ All reminders cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear reminders: $e');
      rethrow;
    }
  }

  /// Save a single reminder
  Future<void> _saveReminder(CustomReminder reminder) async {
    final reminders = await getAllReminders();
    final index = reminders.indexWhere((r) => r.id == reminder.id);

    if (index != -1) {
      reminders[index] = reminder;
    } else {
      reminders.add(reminder);
    }

    await _saveAllReminders(reminders);
  }

  /// Save all reminders to storage
  Future<void> _saveAllReminders(List<CustomReminder> reminders) async {
    final settings = await _storage.getAppSettings() ?? {};
    settings['custom_reminders'] = reminders.map((r) => r.toJson()).toList();
    await _storage.saveAppSettings(settings);
  }

  /// AI suggests a reminder based on user context
  Future<String?> aiSuggestReminder({
    required String context,
    required String userGoal,
  }) async {
    // This would integrate with Firebase AI to suggest smart reminders
    // For now, return a template

    // Example: If user wants to drink more water, suggest water reminders
    if (context.toLowerCase().contains('water') ||
        context.toLowerCase().contains('hydration')) {
      final now = DateTime.now();
      final reminderTime = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour + 2, // 2 hours from now
      );

      return await scheduleReminder(
        title: '💧 Hydration Reminder',
        body: 'Time to drink water! Stay hydrated for better performance.',
        scheduledTime: reminderTime,
        repeat: 'daily',
        createdBy: 'ai',
        category: 'water',
        metadata: {
          'ai_suggested': true,
          'context': context,
          'goal': userGoal,
        },
      );
    }

    return null;
  }
}

/// Custom Reminder Model
class CustomReminder {
  final String id;
  String title;
  String body;
  DateTime scheduledTime;
  String repeat; // 'once', 'daily', 'weekly', 'monthly'
  String createdBy; // 'user' or 'ai'
  String category; // 'workout', 'meal', 'water', 'medication', 'custom'
  String
      alertType; // 'alarm' (full-screen) or 'notification' (notification bar)
  bool isActive;
  final DateTime createdAt;
  Map<String, dynamic> metadata;

  CustomReminder({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledTime,
    required this.repeat,
    required this.createdBy,
    required this.category,
    this.alertType = 'notification',
    required this.isActive,
    required this.createdAt,
    required this.metadata,
  });

  factory CustomReminder.fromJson(Map<String, dynamic> json) {
    return CustomReminder(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      scheduledTime: DateTime.parse(json['scheduled_time'] as String),
      repeat: json['repeat'] as String? ?? 'once',
      createdBy: json['created_by'] as String? ?? 'user',
      category: json['category'] as String? ?? 'custom',
      alertType: json['alert_type'] as String? ?? 'notification',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'scheduled_time': scheduledTime.toIso8601String(),
      'repeat': repeat,
      'created_by': createdBy,
      'category': category,
      'alert_type': alertType,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  String get repeatLabel {
    switch (repeat) {
      case 'daily':
        return 'Every day';
      case 'weekly':
        return 'Every week';
      case 'monthly':
        return 'Every month';
      case 'once':
      default:
        return 'One time';
    }
  }

  String get categoryIcon {
    switch (category) {
      case 'workout':
        return '💪';
      case 'meal':
        return '🍽️';
      case 'water':
        return '💧';
      case 'medication':
        return '💊';
      case 'custom':
      default:
        return '⏰';
    }
  }

  bool get isPast {
    if (repeat != 'once') return false;
    // Give 5-minute grace period before marking as "missed"
    // This allows web alarms time to ring
    final gracePeriod = DateTime.now().subtract(const Duration(minutes: 5));
    return scheduledTime.isBefore(gracePeriod);
  }

  String get alertTypeLabel {
    return alertType == 'alarm' ? '🔔 Alarm' : '📱 Notification';
  }

  /// Get smart default alert type based on category
  static String getDefaultAlertType(String category) {
    switch (category) {
      case 'medication':
      case 'appointment':
        return 'alarm'; // Critical reminders
      case 'water':
      case 'workout':
      case 'meal':
      default:
        return 'notification'; // Regular reminders
    }
  }
}
