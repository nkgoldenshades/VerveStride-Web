import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:vervestride/services/local_storage_service.dart';
import 'package:vervestride/services/notification_service.dart';

class FriendlyNotificationService {
  static final FriendlyNotificationService instance =
      FriendlyNotificationService._internal();
  factory FriendlyNotificationService() => instance;
  FriendlyNotificationService._internal();

  final List<String> _morningGreetings = [
    "Morning sunshine! ☀️ Ready to crush today's goals?",
    "Good morning! 🌅 Let's make today amazing together!",
    "Rise and shine! 💪 Your workout buddy is here!",
    "Hey early bird! 🐦 Time to start our day with energy!",
    "Morning champion! 🏆 Let's get moving!",
  ];

  final List<String> _mealReminders = [
    "Hey! 👋 Are you leaving me? Time for a healthy snack!",
    "Fuel time! 🥗 Your body needs some love",
    "Lunch break! 🍱 Don't forget to eat well",
    "Snack attack! 🍎 Healthy choices, happy you!",
    "Dinner time! 🍽️ Let's refuel for tomorrow",
  ];

  final List<String> _motivationalMessages = [
    "You've been quiet... missing our workout sessions! 💪",
    "Your muscles miss you! 🏋️‍♂️ Time for a quick workout?",
    "Let's get that heart pumping! ❤️‍🔥 I'm here for you!",
    "Remember our goals? 🎯 Let's take one small step!",
    "Your wellness journey calls! 📱 Are you ready to answer?",
  ];

  final List<String> _eveningCheckIns = [
    "Great day today! 🌟 Ready to plan tomorrow's adventure?",
    "Time to rest! 🌙 You earned it, champion!",
    "Before you sleep... 📝 Let's celebrate today's wins!",
    "Night night! 💤 Sweet dreams of tomorrow's goals!",
    "Day complete! 🎉 Proud of you for showing up!",
  ];

  Timer? _friendlyTimer;

  void startFriendlyNotifications() async {
    // Disabled: interval-based timers are not reliable for timely delivery in background
    // and do not respect the app's reminder scheduling window.
    // Friendly reminders are scheduled via NotificationService using the user's
    // reminder settings (active hours + enabled toggles).
    stopFriendlyNotifications();
    debugPrint(
      '🤖 FriendlyNotificationService.startFriendlyNotifications disabled (using scheduled reminders).',
    );
  }

  void stopFriendlyNotifications() {
    _friendlyTimer?.cancel();
    _friendlyTimer = null;
    debugPrint('🤖 Friendly notifications stopped');
  }

  String _getRandomMessage(List<String> messages) {
    final random = Random();
    return messages[random.nextInt(messages.length)];
  }

  Future<void> sendImmediateFriendlyMessage({String? type}) async {
    String message;
    String messageType;

    switch (type?.toLowerCase()) {
      case 'morning':
        message = _getRandomMessage(_morningGreetings);
        messageType = 'morning';
        break;
      case 'meal':
        message = _getRandomMessage(_mealReminders);
        messageType = 'meal';
        break;
      case 'motivation':
        message = _getRandomMessage(_motivationalMessages);
        messageType = 'motivation';
        break;
      case 'evening':
        message = _getRandomMessage(_eveningCheckIns);
        messageType = 'evening';
        break;
      default:
        // Send based on current time
        final hour = DateTime.now().hour;
        if (hour >= 6 && hour < 10) {
          message = _getRandomMessage(_morningGreetings);
          messageType = 'morning';
        } else if (hour >= 11 && hour < 14) {
          message = _getRandomMessage(_mealReminders);
          messageType = 'meal';
        } else if (hour >= 14 && hour < 17) {
          message = _getRandomMessage(_motivationalMessages);
          messageType = 'motivation';
        } else if (hour >= 18 && hour < 22) {
          message = _getRandomMessage(_eveningCheckIns);
          messageType = 'evening';
        } else {
          message = _getRandomMessage(_motivationalMessages);
          messageType = 'motivation';
        }
    }

    debugPrint('🤖 Immediate friendly message: $message');

    try {
      await NotificationService.instance.sendFriendlyNotification(
        title: 'Your Personal Assistant 💪',
        body: message,
        type: messageType,
      );
    } catch (e) {
      debugPrint('❌ Failed to send immediate friendly notification: $e');
    }

    // Save to local storage for tracking
    final settings = await LocalStorageService.instance.getAppSettings() ?? {};
    final sentMessages =
        (settings['friendly_messages_sent'] as List<dynamic>?) ?? [];
    sentMessages.add({
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
      'type': messageType,
    });
    settings['friendly_messages_sent'] = sentMessages;
    await LocalStorageService.instance.saveAppSettings(settings);
  }
}
