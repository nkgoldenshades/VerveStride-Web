import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/pwa_service.dart';

/// Banner widget that prompts users to install the PWA
/// Shows platform-specific installation instructions
class PWAInstallBanner extends StatefulWidget {
  final bool showOnlyIfAvailable;
  final VoidCallback? onDismiss;

  const PWAInstallBanner({
    super.key,
    this.showOnlyIfAvailable = true,
    this.onDismiss,
  });

  @override
  State<PWAInstallBanner> createState() => _PWAInstallBannerState();
}

class _PWAInstallBannerState extends State<PWAInstallBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    // Only show on web
    if (!kIsWeb) return const SizedBox.shrink();

    // Don't show if already installed
    if (PWAService.instance.isInstalled) return const SizedBox.shrink();

    // Don't show if dismissed
    if (_dismissed) return const SizedBox.shrink();

    // Only show if install prompt is available (if requested)
    if (widget.showOnlyIfAvailable && !PWAService.instance.canInstall) {
      return const SizedBox.shrink();
    }

    // Don't show if PWA is not supported
    if (!PWAService.instance.supportsPWA) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.get_app,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Install VerveStride',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Get the full app experience',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _dismiss,
                icon: const Icon(
                  Icons.close,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            PWAService.instance.getInstallInstructions(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _dismiss,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Maybe Later'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _install,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Install',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _install() {
    if (PWAService.instance.canInstall) {
      PWAService.instance.showInstallPrompt();
    } else {
      // Show instructions dialog
      _showInstructionsDialog();
    }
  }

  void _dismiss() {
    setState(() {
      _dismissed = true;
    });
    widget.onDismiss?.call();
  }

  void _showInstructionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Install VerveStride'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To install VerveStride as an app on your device:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Text(PWAService.instance.getInstallInstructions()),
            const SizedBox(height: 16),
            const Text(
              'Benefits of installing:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text('• Faster loading'),
            const Text('• Works offline'),
            const Text('• App-like experience'),
            const Text('• Push notifications'),
            const Text('• No browser UI'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

/// Floating action button for PWA installation
class PWAInstallFAB extends StatelessWidget {
  const PWAInstallFAB({super.key});

  @override
  Widget build(BuildContext context) {
    // Only show on web
    if (!kIsWeb) return const SizedBox.shrink();

    // Don't show if already installed
    if (PWAService.instance.isInstalled) return const SizedBox.shrink();

    // Don't show if PWA is not supported
    if (!PWAService.instance.supportsPWA) return const SizedBox.shrink();

    return FloatingActionButton.extended(
      onPressed: () {
        if (PWAService.instance.canInstall) {
          PWAService.instance.showInstallPrompt();
        } else {
          _showInstructionsBottomSheet(context);
        }
      },
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.get_app),
      label: const Text('Install App'),
    );
  }

  void _showInstructionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Icon(
              Icons.get_app,
              size: 48,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Install VerveStride',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Get the full app experience with faster loading, offline access, and push notifications.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How to install:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(PWAService.instance.getInstallInstructions()),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Got it',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }
}

/// Simple install button widget
class PWAInstallButton extends StatelessWidget {
  final String? text;
  final IconData? icon;
  final VoidCallback? onPressed;

  const PWAInstallButton({
    super.key,
    this.text,
    this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Only show on web
    if (!kIsWeb) return const SizedBox.shrink();

    // Don't show if already installed
    if (PWAService.instance.isInstalled) return const SizedBox.shrink();

    // Don't show if PWA is not supported
    if (!PWAService.instance.supportsPWA) return const SizedBox.shrink();

    return ElevatedButton.icon(
      onPressed: onPressed ?? () {
        if (PWAService.instance.canInstall) {
          PWAService.instance.showInstallPrompt();
        }
      },
      icon: Icon(icon ?? Icons.get_app),
      label: Text(text ?? 'Install App'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}