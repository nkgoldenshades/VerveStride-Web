import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../services/local_storage_service.dart';

/// Handles battery optimization exemption across OEMs.
/// Xiaomi/MIUI, Huawei, OnePlus, Oppo, Vivo all have custom
/// battery managers that kill background services — we deep-link
/// directly to the right settings page for each.
class BatteryOptimizationService {
  static final instance = BatteryOptimizationService._();
  BatteryOptimizationService._();

  static const _platform = MethodChannel('com.vervestride/alarm');
  static const _storageKey = 'battery_optimization_asked';

  /// Returns true if we already asked the user before.
  Future<bool> _alreadyAsked() async {
    final s = await LocalStorageService.instance.getAppSettings();
    return (s?[_storageKey] as bool?) ?? false;
  }

  Future<void> _markAsked() async {
    final s = await LocalStorageService.instance.getAppSettings() ?? {};
    s[_storageKey] = true;
    await LocalStorageService.instance.saveAppSettings(s);
  }

  /// Check if battery optimization is already ignored.
  Future<bool> isIgnoring() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      return await _platform.invokeMethod<bool>(
              'isIgnoringBatteryOptimizations') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Show the dialog once if needed. Call this when user creates first alarm.
  Future<void> requestIfNeeded(BuildContext context) async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (await isIgnoring()) return;
    if (await _alreadyAsked()) return;
    if (!context.mounted) return;

    await _markAsked();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _BatteryPermissionDialog(),
    );
  }
}

class _BatteryPermissionDialog extends StatefulWidget {
  const _BatteryPermissionDialog();

  @override
  State<_BatteryPermissionDialog> createState() =>
      _BatteryPermissionDialogState();
}

class _BatteryPermissionDialogState extends State<_BatteryPermissionDialog> {
  static const _platform = MethodChannel('com.vervestride/alarm');

  String _manufacturer = '';
  String _instructions = '';

  @override
  void initState() {
    super.initState();
    _detectDevice();
  }

  Future<void> _detectDevice() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final mfr = info.manufacturer.toLowerCase();
      setState(() {
        _manufacturer = info.manufacturer;
        _instructions = _getInstructions(mfr);
      });
    } catch (_) {}
  }

  String _getInstructions(String mfr) {
    if (mfr.contains('xiaomi') || mfr.contains('redmi') || mfr.contains('poco')) {
      return 'Tap "Allow" below, then tap "No restrictions" on the next screen.';
    }
    if (mfr.contains('huawei') || mfr.contains('honor')) {
      return 'Tap "Allow" below. Then go to Battery → App launch → VerveStride → Manage manually → enable all.';
    }
    if (mfr.contains('oneplus') || mfr.contains('oppo')) {
      return 'Tap "Allow" below, then set Battery optimization to "Don\'t optimize".';
    }
    if (mfr.contains('vivo')) {
      return 'Tap "Allow" below. Then go to iManager → App Manager → VerveStride → Background power consumption → No restrictions.';
    }
    if (mfr.contains('samsung')) {
      return 'Tap "Allow" below, then select "Unrestricted" for VerveStride.';
    }
    return 'Tap "Allow" below and select "Don\'t optimize" so alarms ring reliably.';
  }

  Future<void> _openStandardRequest() async {
    try {
      await _platform.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }

  Future<void> _openAppSettings() async {
    try {
      await _platform.invokeMethod('openBatterySettings');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Text('⏰', style: TextStyle(fontSize: 24)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Allow alarms to ring',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _manufacturer.isNotEmpty
                ? 'Your $_manufacturer device restricts background apps. '
                    'Without this permission, alarms may not ring.'
                : 'Your device restricts background apps. '
                    'Without this permission, alarms may not ring.',
            style: const TextStyle(color: Color(0xFFB0B0C0), fontSize: 14),
          ),
          if (_instructions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _instructions,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Skip',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
        ),
        TextButton(
          onPressed: () async {
            final navigator = Navigator.of(context);
            navigator.pop();
            await _openAppSettings();
          },
          child: const Text('Open settings',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
        ),
        FilledButton(
          onPressed: () async {
            final navigator = Navigator.of(context);
            navigator.pop();
            await _openStandardRequest();
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Allow', style: TextStyle(fontSize: 14)),
        ),
      ],
    );
  }
}
