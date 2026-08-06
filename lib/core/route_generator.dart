import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'routes.dart';

import '../auth/login_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/fitness/profile_screen.dart';
import '../screens/main/calendar_screen.dart';
import '../screens/main/meals_screen.dart';
import '../screens/main/activity_screen.dart';
import '../screens/navigation_container.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/cloud_sync_screen.dart';
import '../screens/settings/downloads_screen.dart';
import '../screens/workout/workout_pip_screen.dart';
import '../screens/premium/premium_screen.dart';
import '../screens/reminders/reminders_main_screen.dart';
import '../screens/credits/credits_store_screen.dart';
import '../screens/ai/live_video_session_screen.dart';
import '../screens/ai/image_generator_screen.dart';
import '../screens/ai/video_generator_screen.dart';
import '../screens/ai_chat/ai_chat_screen.dart';
import '../screens/test/web_alarm_test_screen.dart';
import '../services/unified_ai_chat_service.dart';

Route<dynamic> generateRoute(RouteSettings settings) {
  bool isSignedIn;
  try {
    isSignedIn = FirebaseAuth.instance.currentUser != null;
  } catch (_) {
    isSignedIn = false;
  }

  final routeName = settings.name;
  final isPublicRoute = routeName == Routes.login;

  if (!isSignedIn && !isPublicRoute) {
    return _page(const LoginScreen());
  }

  if (isSignedIn && routeName == Routes.login) {
    return _page(const NavigationContainer());
  }

  switch (settings.name) {
    case Routes.login:
      return _page(const LoginScreen());
    case Routes.onboarding:
      return _page(const OnboardingScreen());
    case Routes.home:
      return _page(const NavigationContainer());
    case Routes.calendar:
      return _page(const CalendarScreen());
    case Routes.meals:
      return _page(const MealsScreen());
    case Routes.activity:
      return _page(const ActivityScreen());
    case Routes.profile:
      return _page(const ProfileScreen());
    case Routes.settings:
      return _page(const SettingsScreen());
    case Routes.workoutPiP:
      return _page(const WorkoutPiPScreen());
    case Routes.navigation:
      return _page(const NavigationContainer());
    case Routes.premium:
      return _page(const PremiumScreen());
    case Routes.customReminders:
      return _page(const RemindersMainScreen());
    case Routes.cloudSync:
      return _page(const CloudSyncScreen());
    case Routes.aiThreads:
      // Redirect to chat screen with auto-loaded thread
      return _page(const _AIChatScreenWrapper());
    case Routes.aiChat:
      final threadId = settings.arguments as String?;
      if (threadId != null) return _page(AIChatScreen(threadId: threadId));
      // If no threadId provided, use wrapper to auto-load
      return _page(const _AIChatScreenWrapper());
    case Routes.creditsStore:
      return _page(const CreditsStoreScreen());
    case Routes.liveVideoSession:
      return _page(const LiveVideoSessionScreen());
    case Routes.imageGenerator:
      return _page(const ImageGeneratorScreen());
    case Routes.videoGenerator:
      return _page(const VideoGeneratorScreen());
    case Routes.downloads:
      return _page(const DownloadsScreen());
    case Routes.webAlarmTest:
      return _page(const WebAlarmTestScreen());
    default:
      return _page(const NavigationContainer());
  }
}

PageRouteBuilder _page(Widget page) {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

/// Wrapper that automatically loads or creates a thread before showing chat screen
class _AIChatScreenWrapper extends StatefulWidget {
  const _AIChatScreenWrapper();

  @override
  State<_AIChatScreenWrapper> createState() => _AIChatScreenWrapperState();
}

class _AIChatScreenWrapperState extends State<_AIChatScreenWrapper> {
  String? _threadId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrCreateThread();
  }

  Future<void> _loadOrCreateThread() async {
    try {
      final chatService = UnifiedAIChatService.instance;

      await chatService.initialize();
      final thread = await chatService.getActiveThread();

      if (mounted) {
        setState(() {
          _threadId = thread.id;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading thread: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_threadId == null) {
      return const Scaffold(
        body: Center(child: Text('Error loading chat')),
      );
    }

    return AIChatScreen(threadId: _threadId!);
  }
}
