import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'custom_reminder_service.dart';
import 'tts_service.dart';
import 'web_notification_helper.dart';

/// Web Alarm Service
///
/// Provides alarm functionality for web browsers.
///
/// Limitations on Web:
/// - App must be open for alarm to ring
/// - No full-screen alarm support
/// - Relies on browser notifications (user must grant permission)
/// - Audio plays when alarm time is reached
class WebAlarmService {
  static final WebAlarmService instance = WebAlarmService._internal();
  factory WebAlarmService() => instance;
  WebAlarmService._internal();

  Timer? _checkTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAlarmRinging = false;
  String? _currentAlarmId;
  final ValueNotifier<CustomReminder?> currentAlarm =
      ValueNotifier<CustomReminder?>(null);
  final Set<String> _processedAlarms = {};

  /// Start monitoring for alarms (call this when app opens)
  void startMonitoring() {
    if (!kIsWeb) return;

    // Check frequently enough that the UI does not move a due alarm to
    // "missed" before the web alarm overlay can appear.
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkForUpcomingAlarms();
    });

    Timer(const Duration(seconds: 1), _checkForUpcomingAlarms);

    debugPrint('🌐 Web alarm monitoring started (delayed first check)');
  }

  /// Stop monitoring
  void stopMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
    debugPrint('🌐 Web alarm monitoring stopped');
  }

  /// Check for alarms that should ring now
  Future<void> _checkForUpcomingAlarms() async {
    try {
      final reminders =
          await CustomReminderService.instance.getActiveReminders();
      final now = DateTime.now();

      for (final reminder in reminders) {
        // Skip if not an alarm
        if (reminder.alertType != 'alarm') continue;

        // Skip if already processed recently
        final alarmKey =
            '${reminder.id}_${reminder.scheduledTime.millisecondsSinceEpoch}';
        if (_processedAlarms.contains(alarmKey)) continue;

        // Check if alarm time has arrived
        // For one-time alarms: ring if time has passed (within last 5 minutes to avoid missing)
        // For recurring alarms: will be handled by notification system
        if (reminder.repeat == 'once') {
          final difference = reminder.scheduledTime.difference(now);
          final secondsUntilAlarm = difference.inSeconds;
          // Ring if alarm time has passed (within last 5 minutes)
          final isTime = secondsUntilAlarm <= 0 && secondsUntilAlarm >= -300;

          if (isTime && !_isAlarmRinging) {
            debugPrint('🔔 Web alarm triggered: ${reminder.title}');
            _processedAlarms.add(alarmKey);
            await _triggerAlarm(reminder);

            // Clear processed alarms older than 10 minutes
            _cleanupProcessedAlarms();
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking web alarms: $e');
    }
  }

  /// Trigger an alarm
  Future<void> _triggerAlarm(CustomReminder reminder) async {
    if (_isAlarmRinging) {
      debugPrint('⚠️ Another alarm is already ringing');
      return;
    }

    _isAlarmRinging = true;
    _currentAlarmId = reminder.id;
    currentAlarm.value = reminder;

    try {
      // Get alarm sound mode
      final mode = reminder.metadata['alarm_sound_mode'] as String? ?? 'normal';
      final aiStyle = reminder.metadata['ai_wake_style'] as String? ?? '';

      // Show browser notification
      await _showBrowserNotification(reminder);

      // Play alarm sound
      final playMusic = mode == 'normal' || mode == 'mp3' || mode == 'ai_music';
      final playAI = mode == 'ai' || mode == 'ai_music';

      if (playMusic) {
        await _playAlarmSound(
            mode, reminder.metadata['custom_sound_uri'] as String?);
      }

      if (playAI) {
        await Future.delayed(
            playMusic ? const Duration(milliseconds: 1500) : Duration.zero);
        await _playAIWakeMessage(reminder.title, aiStyle);
      }

      // Auto-stop after 2 minutes if not manually stopped
      Timer(const Duration(minutes: 2), () {
        if (_currentAlarmId == reminder.id) {
          stopAlarm();
        }
      });
    } catch (e) {
      debugPrint('❌ Error triggering web alarm: $e');
      _isAlarmRinging = false;
      _currentAlarmId = null;
      currentAlarm.value = null;
    }
  }

  /// Play alarm sound
  Future<void> _playAlarmSound(String mode, String? customSoundUri) async {
    try {
      if (mode == 'mp3' &&
          customSoundUri != null &&
          customSoundUri.isNotEmpty) {
        // Try to play custom MP3
        try {
          await _audioPlayer.setReleaseMode(ReleaseMode.loop);
          await _audioPlayer.setVolume(1.0);
          await _audioPlayer.play(UrlSource(customSoundUri));
          debugPrint('🔊 Web alarm custom sound playing');
          return;
        } catch (e) {
          debugPrint('⚠️ Custom sound failed, using default: $e');
        }
      }

      // For web, we'll use a simple notification sound
      // The browser will play its default notification sound
      debugPrint('🔊 Web alarm using browser notification sound');
    } catch (e) {
      debugPrint('❌ Error playing alarm sound: $e');
    }
  }

  /// Play AI wake message
  Future<void> _playAIWakeMessage(String title, String style) async {
    try {
      final message = await _buildAIWakeMessage(title, style);
      await TTSService.instance.initialize();
      await TTSService.instance.speak(message);
      debugPrint('🗣️ Web alarm AI message playing');
    } catch (e) {
      debugPrint('❌ Error playing AI wake message: $e');
    }
  }

  /// Build AI wake message
  Future<String> _buildAIWakeMessage(String title, String style) async {
    final hour = DateTime.now().hour;
    final timeWord = hour < 12 ? 'Morning' : (hour < 17 ? 'Hey' : 'Evening');

    if (style.trim().isEmpty) {
      return '$timeWord. Time for $title.';
    }

    return '$timeWord. $title. $style';
  }

  /// Show browser notification
  Future<void> _showBrowserNotification(CustomReminder reminder) async {
    if (!kIsWeb) return;

    try {
      await WebNotificationHelper.showNotification(
        title: '⏰ ${reminder.title}',
        body: reminder.body,
        tag: reminder.id,
        requireInteraction: true,
      );

      debugPrint('🔔 Browser notification shown: ${reminder.title}');
    } catch (e) {
      debugPrint('❌ Error showing browser notification: $e');
    }
  }

  /// Stop alarm
  Future<void> stopAlarm() async {
    try {
      await _audioPlayer.stop();
      await TTSService.instance.stop();

      _isAlarmRinging = false;
      _currentAlarmId = null;
      currentAlarm.value = null;

      debugPrint('🔕 Web alarm stopped');
    } catch (e) {
      debugPrint('❌ Error stopping web alarm: $e');
    }
  }

  /// Snooze alarm
  Future<void> snoozeAlarm(int minutes) async {
    final alarmId = _currentAlarmId;
    if (alarmId == null) return;

    try {
      final reminder =
          await CustomReminderService.instance.getReminderById(alarmId);

      // Stop current alarm
      await stopAlarm();

      // Reschedule for later
      if (reminder != null) {
        final snoozeTime = DateTime.now().add(Duration(minutes: minutes));
        await CustomReminderService.instance.scheduleReminder(
          title: reminder.title,
          body: reminder.body,
          scheduledTime: snoozeTime,
          repeat: 'once',
          createdBy: reminder.createdBy,
          category: reminder.category,
          alertType: 'alarm',
          metadata: {
            ...reminder.metadata,
            'snoozed_from': reminder.id,
            'snooze_minutes': minutes,
          },
        );
        await CustomReminderService.instance.cancelReminder(
          alarmId,
          cancelNotification: true,
        );

        debugPrint('💤 Web alarm snoozed for $minutes minutes');
      }
    } catch (e) {
      debugPrint('❌ Error snoozing web alarm: $e');
    }
  }

  /// Clean up old processed alarms
  void _cleanupProcessedAlarms() {
    if (_processedAlarms.length > 50) {
      final toRemove = _processedAlarms.length - 30;
      _processedAlarms.removeAll(_processedAlarms.take(toRemove));
    }
  }

  /// Check if alarm is currently ringing
  bool get isAlarmRinging => _isAlarmRinging;

  /// Get current alarm ID
  String? get currentAlarmId => _currentAlarmId;

  /// Dispose resources
  void dispose() {
    _checkTimer?.cancel();
    currentAlarm.dispose();
    _audioPlayer.dispose();
  }
}
