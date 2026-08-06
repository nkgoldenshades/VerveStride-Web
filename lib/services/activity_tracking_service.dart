import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:vervestride/models/activity_data.dart';
import 'package:vervestride/models/user_profile.dart';
import 'package:vervestride/utils/polyline_codec.dart';
import 'local_storage_service.dart';
import 'notification_service.dart';
import 'streak_service.dart';

class ActivityTrackingService extends ChangeNotifier {
  static final ActivityTrackingService instance =
      ActivityTrackingService._internal();
  ActivityTrackingService._internal();

  final LocalStorageService _storage = LocalStorageService.instance;

  double _userWeightKg = 70.0;

  ActivityData? _currentActivity;
  ActivityData? get currentActivity => _currentActivity;

  Map<String, double>? _currentPosition;
  Map<String, double>? get currentPosition => _currentPosition;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _notificationTimer;
  Timer? _tickerTimer;
  int _notificationCount = 0;
  DateTime? _lastRoutePointAt;
  DateTime? _routeWarmupUntil;

  // Small-distance accumulation to handle <5m movements without noise
  double _pendingDistanceMeters = 0.0;
  static const double _commitThresholdMeters = 5.0;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    // Register notification callbacks
    NotificationService.instance.onActivityPause = pauseActivity;
    NotificationService.instance.onActivityResume = resumeActivity;
    NotificationService.instance.onActivityStop = stopActivity;

    // Check permissions and get initial position
    await _updateCurrentPosition();
    await _refreshUserWeightKg();
    _initialized = true;
    notifyListeners();
  }

  Future<void> _refreshUserWeightKg() async {
    try {
      final profileJson = await _storage.getUserProfile();
      final profile =
          profileJson != null ? UserProfile.fromJson(profileJson) : null;
      final w = profile?.weightKg;
      if (w != null && w > 0) {
        _userWeightKg = w;
      }
    } catch (_) {
      // ignore
    }
  }

  double _estimateCalories(
    ActivityType type,
    int durationMinutes,
    double distanceKm,
  ) {
    final weightScale = _userWeightKg / 70.0;
    switch (type) {
      case ActivityType.running:
        return distanceKm * 70 * weightScale;
      case ActivityType.walking:
        return distanceKm * 45 * weightScale;
      case ActivityType.cycling:
        return distanceKm * 32 * weightScale;
      case ActivityType.swimming:
        return distanceKm * 58 * weightScale;
      case ActivityType.driving:
        return distanceKm * 8 * weightScale;
      case ActivityType.motorcycle:
        return distanceKm * 12 * weightScale;
      case ActivityType.publicTransport:
        return distanceKm * 4 * weightScale;
      case ActivityType.truck:
        return distanceKm * 10 * weightScale;
      case ActivityType.horseRide:
        return distanceKm * 38 * weightScale;
      case ActivityType.workout:
        return durationMinutes * 6.0 * weightScale;
    }
  }

  Future<void> _updateCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⚠️ Location request timed out');
          throw TimeoutException('Location request timed out');
        },
      );
      _currentPosition = {
        'lat': position.latitude,
        'lng': position.longitude,
      };
      notifyListeners();
    } catch (e) {
      debugPrint('Error getting initial position: $e');
    }
  }

  void startActivity(ActivityType type) {
    if (_currentPosition == null) return;

    _refreshUserWeightKg();

    _currentActivity = ActivityData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      startTime: DateTime.now(),
      route: [_currentPosition!],
    );

    final now = DateTime.now();
    _lastRoutePointAt = now;

    // GPS can be very noisy for the first few seconds after starting an activity.
    // During warm-up we still update the live marker, but we avoid recording a burst
    // of jittery points into the saved route.
    final isFoot = type == ActivityType.walking || type == ActivityType.running;
    final isCycle = type == ActivityType.cycling;
    final isMotorized = type == ActivityType.driving ||
        type == ActivityType.motorcycle ||
        type == ActivityType.truck ||
        type == ActivityType.publicTransport;
    _routeWarmupUntil = (isMotorized || isCycle)
        ? now.add(const Duration(seconds: 15))
        : isFoot
            ? now.add(const Duration(seconds: 10))
            : now.add(const Duration(seconds: 12));

    _pendingDistanceMeters = 0.0; // Reset small-distance buffer
    _startLocationTracking();
    _startNotificationTimer();
    _startTicker();

    // Immediate notification
    NotificationService.instance.showActivityNotification(_currentActivity!);

    notifyListeners();
  }

  void pauseActivity() {
    if (_currentActivity == null || _currentActivity!.isPaused) return;
    _currentActivity = _currentActivity!.copyWith(isPaused: true);

    // Pause the notification timer to avoid misleading "active for X minutes" messages
    _notificationTimer?.cancel();

    NotificationService.instance.showActivityNotification(_currentActivity!);
    notifyListeners();
  }

  void resumeActivity() {
    if (_currentActivity == null || !_currentActivity!.isPaused) return;
    _currentActivity = _currentActivity!.copyWith(isPaused: false);

    // Resume the notification timer
    _startNotificationTimer();

    NotificationService.instance.showActivityNotification(_currentActivity!);
    notifyListeners();
  }

  void _startTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentActivity == null) {
        timer.cancel();
        return;
      }

      if (_currentActivity!.isPaused) {
        _currentActivity = _currentActivity!.copyWith(
          pausedSeconds: _currentActivity!.pausedSeconds + 1,
        );
      }

      if (_currentActivity != null &&
          _currentActivity!.isActive &&
          !_currentActivity!.isPaused &&
          DateTime.now().second % 10 == 0) {
        final a = _currentActivity!;
        final durationMinutes =
            a.durationSeconds == 0 ? 0 : ((a.durationSeconds + 59) ~/ 60);
        final est = _estimateCalories(a.type, durationMinutes, a.distance);
        _currentActivity = a.copyWith(calories: est);
      }

      // Update notification every 10 seconds to keep stats fresh
      if (DateTime.now().second % 10 == 0) {
        NotificationService.instance
            .showActivityNotification(_currentActivity!);
      }

      notifyListeners();
    });
  }

  void _startLocationTracking() {
    _positionSubscription?.cancel();

    final type = _currentActivity?.type;
    final isFoot = type == ActivityType.walking || type == ActivityType.running;
    final isCycle = type == ActivityType.cycling;
    final isMotorized = type == ActivityType.driving ||
        type == ActivityType.motorcycle ||
        type == ActivityType.truck ||
        type == ActivityType.publicTransport;

    // A zero distanceFilter can generate a burst of jittery points (especially right after start).
    // Use a modest filter for cycling/motorized to stabilize tracking.
    final distanceFilterMeters = isMotorized
        ? 10
        : isCycle
            ? 5
            : isFoot
                ? 3
                : 6;

    late LocationSettings settings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText:
              "VerveStride is tracking your activity in the background",
          notificationTitle: "Activity Tracking Active",
          enableWakeLock: true,
        ),
      );
    } else {
      settings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (position) {
        final nextPoint = <String, double>{
          'lat': position.latitude,
          'lng': position.longitude,
        };

        _currentPosition = nextPoint;
        notifyListeners();

        if (_currentActivity != null &&
            _currentActivity!.isActive &&
            !_currentActivity!.isPaused) {
          final warmupUntil = _routeWarmupUntil;
          final now = DateTime.now();

          // During warm-up we intentionally do not record route points/distance,
          // except for occasional anchors to avoid the route looking stuck.
          if (warmupUntil != null && now.isBefore(warmupUntil)) {
            final prevRoute = _currentActivity!.route;
            final lastAt = _lastRoutePointAt;
            final shouldAnchor = lastAt == null || now.difference(lastAt).inSeconds >= 10;
            if (shouldAnchor) {
              _currentActivity = _currentActivity!.copyWith(
                route: [...prevRoute, nextPoint],
              );
              _lastRoutePointAt = now;
            }
            notifyListeners();
            return;
          }

          final prevRoute = _currentActivity!.route;
          if (prevRoute.isEmpty) {
            _currentActivity = _currentActivity!.copyWith(route: [nextPoint]);
            _lastRoutePointAt = now;
          } else {
            final last = prevRoute.last;
            final meters = Geolocator.distanceBetween(
              last['lat']!,
              last['lng']!,
              nextPoint['lat']!,
              nextPoint['lng']!,
            );
            final lastAt = _lastRoutePointAt;

            final type = _currentActivity!.type;

            final isFoot =
                type == ActivityType.walking || type == ActivityType.running;
            final isCycle = type == ActivityType.cycling;
            final isMotorized = type == ActivityType.driving ||
                type == ActivityType.motorcycle ||
                type == ActivityType.truck ||
                type == ActivityType.publicTransport;

            // Accuracy thresholds:
            // - Foot activities can tolerate slightly worse accuracy because movement is slow.
            // - Motorized activities often report worse accuracy at speed, so allow a higher threshold
            //   to avoid dropping all points.
            final maxAllowedAccuracy = isFoot
                ? 50.0
                : isMotorized
                    ? 120.0
                    : isCycle
                        ? 60.0
                        : 35.0;

            // If accuracy is poor, walking/running tends to create very noisy routes, so we drop it.
            // For cycling/motorized activities, dropping every point can make the route look stuck.
            // In that case, we still record an "anchor" point occasionally, but we won't add distance.
            if (position.accuracy > maxAllowedAccuracy) {
              if (isFoot) return;

              final now = DateTime.now();
              final lastAt = _lastRoutePointAt;
              final shouldAnchor =
                  lastAt == null || now.difference(lastAt).inSeconds >= 10;
              if (!shouldAnchor) return;

              _currentActivity = _currentActivity!.copyWith(
                route: [...prevRoute, nextPoint],
              );
              _lastRoutePointAt = now;
              return;
            }

            // Guard against occasional huge GPS jumps.
            // If we skip points due to accuracy, the next accepted point can be far away (especially
            // for driving). Use a higher jump threshold for motorized activities.
            final maxJumpMeters = isMotorized
                ? 3000.0
                : isCycle
                    ? 600.0
                    : 200.0;

            // If GPS skips a bunch of points (common while driving/cycling), the next valid point can be
            // far away. If we keep returning here, the route can look "stuck" forever.
            // So: on a large jump, accept the point as a new anchor but don't add the jump distance.
            if (meters > maxJumpMeters) {
              _currentActivity = _currentActivity!.copyWith(
                route: [...prevRoute, nextPoint],
              );
              _lastRoutePointAt = now;
              return;
            }

            // Add points cadence:
            // - Foot: smooth path
            // - Cycle: moderate
            // - Motorized: fewer points but don't miss the route entirely
            final minDistanceMeters = isMotorized
                ? 10.0
                : isCycle
                    ? 6.0
                    : 3.0;
            final minTimeSeconds = isMotorized
                ? 5
                : isCycle
                    ? 8
                    : 10;

            final shouldAddByDistance = meters >= minDistanceMeters;
            final shouldAddByTime = lastAt == null
                ? true
                : now.difference(lastAt).inSeconds >= minTimeSeconds;
            final shouldAdd = isMotorized || isCycle
                ? (shouldAddByDistance || shouldAddByTime)
                : (shouldAddByDistance || (shouldAddByTime && meters >= 1));

            if (shouldAdd) {
              final updatedRoute = [...prevRoute, nextPoint];
              // Accumulate small movements; commit only when threshold is reached
              _pendingDistanceMeters += meters;
              double distanceToAdd = 0.0;
              if (_pendingDistanceMeters >= _commitThresholdMeters) {
                distanceToAdd = _pendingDistanceMeters;
                _pendingDistanceMeters = 0.0;
              }
              final updatedDistanceKm = _currentActivity!.distance + (distanceToAdd / 1000.0);
              _currentActivity = _currentActivity!.copyWith(
                route: updatedRoute,
                distance: updatedDistanceKm,
              );
              _lastRoutePointAt = now;
            }
          }
        }
        notifyListeners();
      },
      onError: (e) {
        debugPrint('Location stream error: $e');
      },
    );
  }

  void _startNotificationTimer() {
    _notificationTimer?.cancel();
    _notificationCount = 0;
    _notificationTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_currentActivity != null && _currentActivity!.isActive) {
        _notificationCount++;
        NotificationService.instance.sendActivityMonitoringNotification(
          title: 'Activity Reminder',
          body: 'You have been active for ${_notificationCount * 5} minutes!',
        );
      }
    });
  }

  Future<void> stopActivity({String? notes}) async {
    if (_currentActivity == null) return;

    // Guard against duplicate stops
    final activityToStop = _currentActivity!;
    _currentActivity = null;

    final finalActivityBeforeCal = activityToStop.copyWith(
      endTime: DateTime.now(),
      notes: notes ?? activityToStop.notes,
      distance: activityToStop.distance + (_pendingDistanceMeters / 1000.0),
    );

    _positionSubscription?.cancel();
    _notificationTimer?.cancel();
    _tickerTimer?.cancel();

    NotificationService.instance.cancelActivityNotification();

    notifyListeners();

    final durationMinutes = finalActivityBeforeCal.durationSeconds == 0
        ? 0
        : ((finalActivityBeforeCal.durationSeconds + 59) ~/ 60);

    final calories = await _calculateCalories(
      finalActivityBeforeCal.type,
      durationMinutes,
      finalActivityBeforeCal.distance,
    );

    final finalActivity = finalActivityBeforeCal.copyWith(calories: calories);
    await _saveActivity(finalActivity);
  }

  Future<double> _calculateCalories(
    ActivityType type,
    int durationMinutes,
    double distance,
  ) async {
    final profileJson = await _storage.getUserProfile();
    final profile =
        profileJson != null ? UserProfile.fromJson(profileJson) : null;
    final userWeightKg = profile?.weightKg ?? 70.0;

    if (profile == null || profile.weightKg == 0) {
      debugPrint(
          '⚠️ Warning: Using default weight (70kg) for calorie calculation. User should set profile.');
    }

    switch (type) {
      case ActivityType.running:
        return distance * 70 * (userWeightKg / 70);
      case ActivityType.walking:
        return distance * 45 * (userWeightKg / 70);
      case ActivityType.cycling:
        return distance * 32 * (userWeightKg / 70);
      case ActivityType.swimming:
        return distance * 58 * (userWeightKg / 70);
      case ActivityType.driving:
        return distance * 8 * (userWeightKg / 70);
      case ActivityType.motorcycle:
        return distance * 12 * (userWeightKg / 70);
      case ActivityType.publicTransport:
        return distance * 4 * (userWeightKg / 70);
      case ActivityType.truck:
        return distance * 10 * (userWeightKg / 70);
      case ActivityType.horseRide:
        return distance * 38 * (userWeightKg / 70);
      case ActivityType.workout:
        // No distance-based metric for workouts; use a simple weight-scaled per-minute estimate.
        return durationMinutes * 6.0 * (userWeightKg / 70);
    }
  }

  Future<void> _saveActivity(ActivityData activity) async {
    try {
      // Validate route points before encoding
      final validRoute = activity.route.where((point) {
        final lat = point['lat'];
        final lng = point['lng'];
        return lat != null &&
            lng != null &&
            lat >= -90 &&
            lat <= 90 &&
            lng >= -180 &&
            lng <= 180;
      }).toList();

      if (validRoute.length < activity.route.length) {
        debugPrint(
            '⚠️ Warning: ${activity.route.length - validRoute.length} invalid route points removed');
      }

      final encodedPolyline = PolylineCodec.encodeRoute(validRoute);
      final routeData = jsonEncode({
        'route_polyline': encodedPolyline,
        'notes': activity.notes,
      });

      final payload = {
        'id': activity.id,
        'activity_type': activity.type.name,
        'activity_date': activity.startTime.toIso8601String(),
        'distance_km': activity.distance,
        'duration_minutes': activity.durationSeconds == 0
            ? 0
            : ((activity.durationSeconds + 59) ~/ 60),
        'calories_burned': activity.calories.toInt(),
        'route_data': routeData,
        'note': activity.notes,
        'created_at': DateTime.now().toIso8601String(),
      };

      await _storage.addActivity(payload);
      await StreakService.markActiveToday();
    } catch (e) {
      debugPrint('Error saving activity: $e');
    }
  }
}
