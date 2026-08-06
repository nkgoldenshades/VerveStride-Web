import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../screens/report_bug_screen.dart';

class ShakeBugReporter extends StatefulWidget {
  const ShakeBugReporter({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<ShakeBugReporter> createState() => _ShakeBugReporterState();
}

class _ShakeBugReporterState extends State<ShakeBugReporter> {
  StreamSubscription<AccelerometerEvent>? _sub;
  int _shakeCount = 0;
  DateTime? _firstShakeAt;
  DateTime? _lastTriggerAt;
  bool _dialogOpen = false;

  DateTime? _lastShakeEventTime;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    _sub = accelerometerEvents.listen(_onAccel);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onAccel(AccelerometerEvent e) {
    final mag = sqrt((e.x * e.x) + (e.y * e.y) + (e.z * e.z));
    final delta = (mag - 9.81).abs();

    if (delta < 11.0) return;

    final now = DateTime.now();
    if (_lastTriggerAt != null &&
        now.difference(_lastTriggerAt!) < const Duration(seconds: 2)) {
      return;
    }

    // Debounce: Ignore if within 500ms of last shake event
    if (_lastShakeEventTime != null &&
        now.difference(_lastShakeEventTime!) <
            const Duration(milliseconds: 500)) {
      return;
    }
    _lastShakeEventTime = now;

    // Window to get 3 shakes
    const window = Duration(milliseconds: 2500);
    if (_firstShakeAt == null || now.difference(_firstShakeAt!) > window) {
      _firstShakeAt = now;
      _shakeCount = 1;
      return;
    }

    _shakeCount += 1;
    if (_shakeCount >= 3) {
      _lastTriggerAt = now;
      _shakeCount = 0;
      _firstShakeAt = null;
      _trigger();
    }
  }

  Future<void> _trigger() async {
    if (_dialogOpen) return;
    final nav = widget.navigatorKey.currentState;
    if (nav == null) return;

    _dialogOpen = true;
    try {
      nav.push(
        MaterialPageRoute(builder: (_) => const ReportBugScreen()),
      );
    } finally {
      _dialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
