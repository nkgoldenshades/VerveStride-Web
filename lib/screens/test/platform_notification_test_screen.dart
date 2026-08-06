import 'package:flutter/material.dart';
import '../../services/platform_notification_service.dart';
import '../../services/friendly_notification_service.dart';

class PlatformNotificationTestScreen extends StatefulWidget {
  const PlatformNotificationTestScreen({super.key});

  @override
  State<PlatformNotificationTestScreen> createState() => _PlatformNotificationTestScreenState();
}

class _PlatformNotificationTestScreenState extends State<PlatformNotificationTestScreen> {
  bool _isInitialized = false;
  bool _hasPermission = false;
  String _platformInfo = 'Unknown';
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      await PlatformNotificationService.instance.initialize();
      final hasPermission = await PlatformNotificationService.instance.hasPermission();
      final platformInfo = PlatformNotificationService.instance.getPlatformInfo();
      
      setState(() {
        _isInitialized = true;
        _hasPermission = hasPermission;
        _platformInfo = platformInfo;
      });
    } catch (e) {
      setState(() {
        _platformInfo = 'Error: $e';
      });
    }
  }

  Future<void> _requestPermission() async {
    await PlatformNotificationService.instance.requestPermission();
    final hasPermission = await PlatformNotificationService.instance.hasPermission();
    setState(() {
      _hasPermission = hasPermission;
    });
  }

  Future<void> _sendTestNotification() async {
    setState(() {
      _notificationCount++;
    });
    
    await PlatformNotificationService.instance.showFriendlyNotification(
      title: 'Test Notification #$_notificationCount',
      body: 'This is a test notification on $_platformInfo! 🎉',
      payload: 'test_notification_$_notificationCount',
    );
  }

  Future<void> _sendScheduledNotification() async {
    final scheduledTime = DateTime.now().add(const Duration(seconds: 10));
    await PlatformNotificationService.instance.showScheduledNotification(
      title: 'Scheduled Notification',
      body: 'This was scheduled 10 seconds ago! ⏰',
      scheduledTime: scheduledTime,
      payload: 'scheduled_notification',
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification scheduled for 10 seconds from now')),
      );
    }
  }

  Future<void> _sendFriendlyNotification() async {
    await FriendlyNotificationService.instance.sendImmediateFriendlyMessage(type: 'motivation');
  }

  Future<void> _sendPlatformSpecificNotification() async {
    String message;
    switch (_platformInfo.toLowerCase()) {
      case 'android':
        message = 'Hey Android buddy! 🤖 Let\'s get moving!';
        break;
      case 'ios':
        message = 'Hello iOS friend! 🍎 Ready for some fitness magic?';
        break;
      case 'web':
        message = 'Web warrior! 🌐 Time to stand up and stretch!';
        break;
      default:
        message = 'Platform power! 💻 Let\'s get moving!';
    }
    
    setState(() {
      _notificationCount++;
    });
    
    await PlatformNotificationService.instance.showFriendlyNotification(
      title: 'Platform Specific 💪',
      body: message,
      payload: 'platform_specific_$_notificationCount',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Notifications'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Platform Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Platform Information',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Platform: $_platformInfo'),
                    Text('Initialized: ${_isInitialized ? "✅ Yes" : "❌ No"}'),
                    Text('Permission: ${_hasPermission ? "✅ Granted" : "❌ Denied"}'),
                    Text('Notifications Sent: $_notificationCount'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Permission Button
            if (!_hasPermission)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _requestPermission,
                  child: const Text('Request Notification Permission'),
                ),
              ),
            
            if (!_hasPermission) const SizedBox(height: 16),
            
            // Test Buttons
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildTestButton(
                    icon: Icons.notifications,
                    label: 'Test Notification',
                    onPressed: _hasPermission ? _sendTestNotification : null,
                  ),
                  _buildTestButton(
                    icon: Icons.schedule,
                    label: 'Scheduled (10s)',
                    onPressed: _hasPermission ? _sendScheduledNotification : null,
                  ),
                  _buildTestButton(
                    icon: Icons.favorite,
                    label: 'Friendly Message',
                    onPressed: _hasPermission ? _sendFriendlyNotification : null,
                  ),
                  _buildTestButton(
                    icon: Icons.devices,
                    label: 'Platform Specific',
                    onPressed: _hasPermission ? _sendPlatformSpecificNotification : null,
                  ),
                ],
              ),
            ),
            
            // Instructions
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Platform Features:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('🤖 Android: Custom channels, vibration, sound'),
                    Text('🍎 iOS: Badge numbers, alerts, sounds'),
                    Text('🌐 Web: Browser notifications'),
                    Text('💻 Desktop: System notifications'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Card(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: onPressed != null 
                  ? Theme.of(context).colorScheme.primary 
                  : Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: onPressed != null 
                    ? null 
                    : Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
