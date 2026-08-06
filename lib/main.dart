import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:openfoodfacts/openfoodfacts.dart' as off;

import 'firebase_options.dart';
import 'utils/logger_init.dart';
import 'utils/secure_logger.dart';

import 'core/route_generator.dart';
import 'core/routes.dart';
import 'auth/login_screen.dart';
import 'screens/navigation_container.dart';
import 'controllers/theme_controller.dart';
import 'services/isar_service.dart';
import 'services/local_storage_service.dart';
import 'services/isar_bootstrap.dart';
import 'services/notification_service.dart';
import 'services/activity_tracking_service.dart';
import 'services/user_subscription_service.dart';
import 'services/storage_tracking_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/custom_reminder_service.dart';
import 'services/web_alarm_service.dart';
import 'services/tts_service.dart';
import 'services/ai_floating_assistant_controller.dart';
// import 'services/pwa_service.dart'; // Temporarily commented for Android build
import 'services/currency_service.dart';
import 'services/credits_service.dart';
import 'services/referral_service.dart';
import 'widgets/floating_ai_assistant.dart';
import 'widgets/shake_bug_reporter.dart';
import 'widgets/web_alarm_overlay.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

enum InitializationStage {
  idle,
  critical,
  background,
  ready,
  failed,
}

final ValueNotifier<InitializationStage> _initStage =
    ValueNotifier(InitializationStage.idle);
final ValueNotifier<String> _initStatus = ValueNotifier('Starting...');
bool _isFirebaseInitialized = false;
bool isAdsInitialized = false;

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // ═══════════════════════════════════════════════════════════════════
    // SECURE LOGGING - Initialize FIRST before any other code
    // ═══════════════════════════════════════════════════════════════════
    initializeSecureLogging();
    disableDebugPrintsInRelease();

    logger.i('App starting');

    // Firebase must be initialized before any widget/service touches Auth/Firestore/Functions.
    try {
      logger.i('Initializing Firebase');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 8));
      _isFirebaseInitialized = true;
      logger.i('Firebase initialized');
    } catch (e) {
      logger.e('Firebase initialization failed', e);
      _isFirebaseInitialized = false;
    }

    // ═══════════════════════════════════════════════════════════════════
    // APP CHECK - PRODUCTION READY
    // Secures Firebase AI, Firestore, and Functions access
    // ═══════════════════════════════════════════════════════════════════

    // Activate App Check — secures Firebase AI and Firestore access
    if (_isFirebaseInitialized) {
      try {
        logger.i('Activating App Check');

        // TEMPORARILY DISABLED - App Check throttled
        // TODO: Fix App Check configuration before re-enabling
        /*
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaV3Provider('6LdSKs8sAAAAAGdfilDGFnIQhRYkKOr3_4aI1jui'),
          androidProvider: kReleaseMode
              ? AndroidProvider.playIntegrity
              : AndroidProvider.debug,
          appleProvider:
              kReleaseMode ? AppleProvider.deviceCheck : AppleProvider.debug,
        );
        */
        logger.i('App Check temporarily disabled');
      } catch (e) {
        logger.w('App Check activation failed', e);
      }
    }

    logger.i('Setting up error handlers');
    FlutterError.onError = (details) {
      logger.e('Flutter error', details.exception, details.stack);
      if (_isFirebaseInitialized && !kIsWeb) {
        try {
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        } catch (e) {
          logger.e('Failed to record to Crashlytics', e);
        }
      } else if (kIsWeb) {
        // On web, just present the error
        FlutterError.presentError(details);
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      logger.e('Platform error', error, stack);
      if (_isFirebaseInitialized && !kIsWeb) {
        try {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        } catch (e) {
          logger.e('Failed to record to Crashlytics', e);
        }
      }
      return true;
    };
    logger.i('Error handlers configured');

    off.OpenFoodAPIConfiguration.userAgent = off.UserAgent(
      name: 'VerveStride',
      version: '1.0.0',
    );
    off.OpenFoodAPIConfiguration.globalLanguages = [
      off.OpenFoodFactsLanguage.ENGLISH
    ];
    logger.i('OpenFoodFacts configured');

    logger.i('Starting app UI');
    runApp(const MyApp());

    // Run initializations AFTER app starts to avoid blocking UI
    // Use scheduleMicrotask instead of Future.microtask for better web compatibility
    scheduleMicrotask(() async {
      try {
        logger.i('Starting background initialization');
        // PRE-INIT ISAR HERE
        await preInitIsar();
        logger.i('Isar pre-initialized');
        await _startAllInitializations();
        logger.i('All initializations complete');
      } catch (e, st) {
        logger.e('Initialization failed', e, st);
        if (_isFirebaseInitialized && !kIsWeb) {
          try {
            FirebaseCrashlytics.instance.recordError(e, st, fatal: true);
          } catch (crashError) {
            logger.e('Failed to record crash', crashError);
          }
        }
        // Set init stage to failed so UI can show error
        _initStage.value = InitializationStage.failed;
        _initStatus.value =
            'Initialization failed: ${e.toString().substring(0, min(50, e.toString().length))}';
      }
    });
  }, (error, stack) {
    logger.f('Uncaught zone error', error, stack);
    if (_isFirebaseInitialized && !kIsWeb) {
      try {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } catch (e) {
        logger.e('Failed to record to Crashlytics', e);
      }
    }
  });
}

Future<void> _startAllInitializations() async {
  debugPrint(
      '📍 _startAllInitializations called, current stage: ${_initStage.value}');

  if (_initStage.value != InitializationStage.idle &&
      _initStage.value != InitializationStage.failed) {
    debugPrint('⚠️ Already initializing or initialized, skipping');
    return;
  }

  _initStage.value = InitializationStage.critical;
  _initStatus.value = 'Loading database...';
  debugPrint('📍 Set stage to critical');

  // 1. Critical initializations
  try {
    // On web, preInitIsar is a no-op, so we need to initialize LocalStorageService here
    // On native, preInitIsar already initialized it, so this will be idempotent
    debugPrint('🔄 Step 1: Initializing LocalStorageService...');
    try {
      await LocalStorageService.instance.init().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('⏱️ LocalStorageService initialization timed out');
          throw TimeoutException(
              'LocalStorageService initialization timed out');
        },
      );
      debugPrint('✅ LocalStorageService initialized');
    } catch (e) {
      debugPrint('❌ LocalStorageService failed: $e');
      // Continue anyway, it might work later
    }

    debugPrint('🔄 Step 2: Initializing IsarService...');
    try {
      await IsarService.initialize().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('⏱️ IsarService initialization timed out');
          throw TimeoutException('IsarService initialization timed out');
        },
      );
      debugPrint('✅ IsarService initialized');
    } catch (e) {
      debugPrint('❌ IsarService failed: $e');
      // Continue anyway
    }

    debugPrint('🔄 Step 3: Loading theme...');
    try {
      await ThemeController.instance.load().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          debugPrint('⏱️ Theme loading timed out, using defaults');
          // Theme can use defaults, don't throw
        },
      );
      debugPrint('✅ Theme loaded');
    } catch (e) {
      debugPrint('⚠️ Theme load failed (using defaults): $e');
    }

    // Wait for Firebase Auth to be ready before loading user data
    debugPrint('🔄 Waiting for Firebase Auth...');
    try {
      await FirebaseAuth.instance.authStateChanges().first.timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          );
      debugPrint(
          '✅ Auth ready: ${FirebaseAuth.instance.currentUser?.uid ?? 'not signed in'}');
    } catch (e) {
      debugPrint('⚠️ Auth wait failed: $e');
    }

    // Load subscription state after local storage is ready
    debugPrint('🔄 Loading subscription state...');
    try {
      await UserSubscriptionService.instance.load().timeout(
            const Duration(seconds: 3),
          );
      debugPrint('✅ Subscription state loaded');
    } catch (e) {
      debugPrint('⚠️ Subscription load failed (non-critical): $e');
    }

    // Load storage tracking (after subscription so limits are correct)
    debugPrint('🔄 Loading storage tracking...');
    try {
      await StorageTrackingService.instance.load().timeout(
            const Duration(seconds: 3),
          );
      debugPrint('✅ Storage tracking loaded');
    } catch (e) {
      debugPrint('⚠️ Storage tracking load failed (non-critical): $e');
    }

    // Load cloud sync settings
    debugPrint('🔄 Loading cloud sync settings...');
    try {
      await CloudSyncService.instance.load();
      debugPrint('✅ Cloud sync settings loaded');
    } catch (e) {
      debugPrint('⚠️ Cloud sync load failed (non-critical): $e');
    }

    // Load credits service
    debugPrint('🔄 Loading credits service...');
    try {
      await CreditsService.instance.load();
      // Claim daily bonus silently on every app open
      CreditsService.instance.claimDailyBonus();
      // Ensure user has a referral code generated
      ReferralService.instance.loadReferralCode();
      debugPrint('✅ Credits service loaded');
    } catch (e) {
      debugPrint('⚠️ Credits load failed (non-critical): $e');
    }

    // Load floating AI enabled state
    debugPrint('🔄 Loading AI settings...');
    try {
      final aiSettings = await LocalStorageService.instance.getAISettings();

      // ── Model ID migration ──────────────────────────────────────────────
      // Clear any stale/deprecated Google model IDs from storage.
      // Valid internal IDs start with 'vs_'. Anything else gets wiped.
      bool needsSave = false;
      for (final key in [
        'selected_general_model',
        'selected_vision_model',
        'selected_live_model'
      ]) {
        final saved = aiSettings[key] as String?;
        if (saved != null && !saved.startsWith('vs_')) {
          debugPrint('🔄 Clearing stale model ID: $saved');
          aiSettings.remove(key);
          needsSave = true;
        }
      }
      if (needsSave) {
        await LocalStorageService.instance.saveAISettings(aiSettings);
        debugPrint('✅ Stale model IDs cleared');
      }
      // ───────────────────────────────────────────────────────────────────

      final floatingEnabled =
          (aiSettings['floating_ai_enabled'] as bool?) ?? true;
      AIFloatingAssistantController.enabled.value = floatingEnabled;
      debugPrint('🤖 Floating AI enabled: $floatingEnabled');

      // Also load hidden state - default to FALSE (visible)
      final floatingHidden =
          await LocalStorageService.instance.getAIFloatingAssistantHidden();
      AIFloatingAssistantController.hidden.value = floatingHidden;
      debugPrint('🤖 Floating AI hidden: $floatingHidden');
    } catch (e) {
      debugPrint('⚠️ AI settings load failed (using defaults): $e');
      AIFloatingAssistantController.enabled.value = true;
      AIFloatingAssistantController.hidden.value = false;
    }
  } catch (e, st) {
    debugPrint('❌ CRITICAL initialization failure: $e');
    debugPrint('Stack trace: $st');
    // Set failed state and rethrow to stop initialization
    _initStage.value = InitializationStage.failed;
    _initStatus.value = 'Failed: ${e.toString().substring(0, 50)}...';
    rethrow;
  }

  _initStage.value = InitializationStage.background;
  _initStatus.value = 'Connecting services...';

  // 2. Non-critical background initializations
  await _initializeBackgroundServices();

  _initStage.value = InitializationStage.ready;
  _initStatus.value = 'Ready';
}

/// Initializes services that don't need to block the initial UI render.
Future<void> _initializeBackgroundServices() async {
  // Firebase (already initialized in main; keep this idempotent).
  if (!_isFirebaseInitialized) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 8));
      _isFirebaseInitialized = true;
    } catch (e) {
      debugPrint('Error initializing Firebase: $e');
      _isFirebaseInitialized = false;
    }
  }

  // Notifications
  if (_isFirebaseInitialized) {
    try {
      debugPrint('🚀 Initializing NotificationService...');
      await NotificationService.instance.initialize();
      NotificationService.instance.navigatorKey = appNavigatorKey;
      CustomReminderService.instance.navigatorKey = appNavigatorKey;
      // Disable auto-rescheduling on startup to prevent notification sounds
      // await NotificationService.instance.rescheduleHumaneReminders();
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  } else {
    debugPrint(
        '⚠️ Skipping NotificationService because Firebase is not initialized.');
  }

  // Activity Tracking Service
  try {
    debugPrint('🚀 Initializing ActivityTrackingService...');
    await ActivityTrackingService.instance.initialize();
  } catch (e) {
    debugPrint('Error initializing ActivityTrackingService: $e');
  }

  // TTS Service — initialize early so first AI response speaks without delay
  if (!kIsWeb) {
    try {
      await TTSService.instance.initialize();
      debugPrint('✅ TTS Service initialized');
    } catch (e) {
      debugPrint('⚠️ TTS init failed: $e');
    }
  }

  // PWA Service — initialize for web app installation
  if (kIsWeb) {
    try {
      // PWAService.instance.initialize(); // Temporarily commented for Android build
      debugPrint('✅ PWA Service skipped (not needed for Android)');
    } catch (e) {
      debugPrint('⚠️ PWA init failed: $e');
    }
  }

  // Currency Service — initialize for localized pricing
  try {
    debugPrint('🚀 Initializing CurrencyService...');
    await CurrencyService.instance.initialize();
    debugPrint('✅ Currency Service initialized');
  } catch (e) {
    debugPrint('⚠️ Currency init failed: $e');
  }

  // AdMob
  if (!kIsWeb) {
    try {
      debugPrint('🚀 Initializing MobileAds...');
      await MobileAds.instance.initialize().timeout(const Duration(seconds: 5));
      isAdsInitialized = true;
    } catch (e) {
      debugPrint('AdMob initialization failed: $e');
      isAdsInitialized = false;
    }
  }

  debugPrint('✅ Background services initialization complete.');

  // Start web alarm monitoring (web only)
  if (kIsWeb) {
    try {
      WebAlarmService.instance.startMonitoring();
      debugPrint('🌐 Web alarm service started');
    } catch (e) {
      debugPrint('❌ Web alarm service failed: $e');
    }
  }

  // Debug notifications disabled - uncomment for testing
  // if (kIsWeb && kDebugMode) {
  //   Future.delayed(const Duration(seconds: 2), () async {
  //     try {
  //       await NotificationService.instance.rescheduleHumaneReminders();
  //       await NotificationService.instance.rescheduleFriendlyReminders();
  //       debugPrint('🔔 Web test notification triggered');
  //     } catch (e) {
  //       debugPrint('❌ Web notification test failed: $e');
  //     }
  //   });
  //
  //   // Test platform notifications after 5 seconds (debug only)
  //   Future.delayed(const Duration(seconds: 5), () async {
  //     try {
  //       await PlatformNotificationService.instance.initialize();
  //       await PlatformNotificationService.instance.showFriendlyNotification(
  //         title: 'Platform Test 💪',
  //         body: 'This notification works on all platforms! 🎉',
  //         payload: 'platform_test',
  //       );
  //       debugPrint('🔔 Platform notification test triggered');
  //     } catch (e) {
  //       debugPrint('❌ Platform notification test failed: $e');
  //     }
  //   });
  // }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'VerveStride',
          debugShowCheckedModeBanner: false,
          theme: ThemeController.instance.theme,
          navigatorKey: appNavigatorKey,
          builder: (context, child) {
            final content = child ?? const SizedBox.shrink();
            return ShakeBugReporter(
              navigatorKey: appNavigatorKey,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  content,
                  // FloatingAIAssistant uses appNavigatorKey overlay context
                  // to ensure TextField has a valid Overlay ancestor
                  StreamBuilder<User?>(
                    stream: FirebaseAuth.instance.authStateChanges(),
                    builder: (context, snapshot) {
                      if (snapshot.data == null) return const SizedBox.shrink();
                      return ValueListenableBuilder<bool>(
                        valueListenable: AIFloatingAssistantController.enabled,
                        builder: (context, floatingEnabled, _) {
                          if (!floatingEnabled) return const SizedBox.shrink();
                          // Overlay widget provides the ancestor TextField needs
                          return Overlay(
                            initialEntries: [
                              OverlayEntry(
                                builder: (_) => const FloatingAIAssistant(),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  if (kIsWeb)
                    ValueListenableBuilder<CustomReminder?>(
                      valueListenable: WebAlarmService.instance.currentAlarm,
                      builder: (context, reminder, _) {
                        if (reminder == null) return const SizedBox.shrink();
                        return WebAlarmOverlay(
                          reminder: reminder,
                          onDismiss: () {},
                        );
                      },
                    ),
                ],
              ),
            );
          },
          home: const SplashScreen(),
          onGenerateRoute: generateRoute,
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Premium easeOutCubic curve
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    // Glow pulse animation only - breathing effect
    _glow = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();

    _initStage.addListener(_onInitStateChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // If init completed before the listener was attached, we won't receive
      // a ValueNotifier change event. Handle that case here.
      if (_initStage.value == InitializationStage.ready) {
        _navigateToNext();
      }
    });
  }

  void _onInitStateChanged() {
    if (_initStage.value == InitializationStage.ready) {
      _navigateToNext();
    }
  }

  void _navigateToNext() {
    if (!mounted) return;

    // Ensure splash is visible for at least 1.8s for branding
    final elapsed = _controller.lastElapsedDuration?.inMilliseconds ?? 0;
    final remaining = max(0, 1800 - elapsed);

    Future.delayed(Duration(milliseconds: remaining), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
      );
    });
  }

  @override
  void dispose() {
    _initStage.removeListener(_onInitStateChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F0F1A),
              Color(0xFF1A0F2A),
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon with glow pulse effect
                  ScaleTransition(
                    scale: _glow,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [
                            Color(0xFF6B46C1),
                            Color(0xFF12D6B5),
                          ],
                          center: Alignment(0.2, -0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6B46C1)
                                .withOpacity(_glow.value * 0.3),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.directions_run,
                          color: Colors.white,
                          size: 76,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ShaderMask(
                    shaderCallback: (bounds) {
                      return const LinearGradient(
                        colors: [
                          Color(0xFF9F7AEA),
                          Color(0xFF12D6B5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds);
                    },
                    child: const Text(
                      'VerveStride',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ValueListenableBuilder<String>(
                    valueListenable: _initStatus,
                    builder: (context, status, _) {
                      return Text(
                        status,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  static bool get _useAuthStreams {
    if (kIsWeb) return true;
    return defaultTargetPlatform != TargetPlatform.windows;
  }

  User? _user;
  bool _isReady = false;
  Timer? _pollTimer;

  bool? _hasSeenOnboarding;

  @override
  void initState() {
    super.initState();
    _loadOnboardingFlag();
    if (_useAuthStreams) {
      _isReady = true;
      return;
    }
    _bootstrapWindowsAuth();
  }

  Future<void> _loadOnboardingFlag() async {
    try {
      final seen = await LocalStorageService.instance.getHasSeenOnboarding();
      if (!mounted) return;
      setState(() {
        _hasSeenOnboarding = seen;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasSeenOnboarding = false;
      });
    }
  }

  Future<void> _bootstrapWindowsAuth() async {
    try {
      // Wait for Firebase to be initialized - non-blocking
      await Future.delayed(const Duration(milliseconds: 300));

      // Try up to 10 times with 200ms delays (2 seconds total max)
      for (int i = 0; i < 10; i++) {
        try {
          final current = FirebaseAuth.instance.currentUser;
          if (current != null) {
            _user = current;
            break;
          }
        } catch (e) {
          // Firebase not ready yet, continue waiting
        }
        await Future.delayed(const Duration(milliseconds: 200));
      }

      try {
        _user = FirebaseAuth.instance.currentUser;
      } catch (e) {
        _user = null;
      }
    } catch (e) {
      _user = null;
    } finally {
      if (mounted) {
        setState(() {
          _isReady = true;
        });

        _pollTimer?.cancel();
        _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          try {
            final current = FirebaseAuth.instance.currentUser;
            if (current?.uid != _user?.uid) {
              if (!mounted) return;
              setState(() {
                _user = current;
              });
            }
          } catch (e) {
            // Firebase not available, keep current user state
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isFirebaseInitialized) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Service Connection Issue',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 8),
                child: Text(
                  'We couldn\'t connect to VerveStride services. Check your internet or try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  _startAllInitializations();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const SplashScreen()),
                  );
                },
                child: const Text('RETRY CONNECTION'),
              ),
              TextButton(
                onPressed: () {
                  // Fallback for debugging if possible
                  setState(() {
                    _isReady = true;
                    _user = null;
                  });
                },
                child: const Text('CONTINUE OFFLINE'),
              ),
            ],
          ),
        ),
      );
    }

    final seen = _hasSeenOnboarding;
    if (seen == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Skip onboarding before login - show it after sign-in instead
    // This way: Splash → Login → Home → Onboarding (optional)

    if (_useAuthStreams) {
      return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Column(
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pushReplacementNamed(
                        context,
                        Routes.login,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Handle Firebase not initialized case
          if (snapshot.error is FirebaseException &&
              snapshot.error.toString().contains('No Firebase App')) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning, size: 64, color: Colors.orange),
                    const SizedBox(height: 16),
                    const Text('Firebase not initialized'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pushReplacementNamed(
                        context,
                        Routes.login,
                      ),
                      child: const Text('Continue to Login'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasData) {
            return const NavigationContainer();
          }

          return const LoginScreen();
        },
      );
    }

    if (!_isReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_user != null) {
      return const NavigationContainer();
    }

    return const LoginScreen();
  }
}
