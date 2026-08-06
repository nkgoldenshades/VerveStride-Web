import 'package:flutter/material.dart';
import '../../services/platform_notification_service.dart';
import '../../services/friendly_notification_service.dart';

class Android10DemoScreen extends StatefulWidget {
  const Android10DemoScreen({super.key});

  @override
  State<Android10DemoScreen> createState() => _Android10DemoScreenState();
}

class _Android10DemoScreenState extends State<Android10DemoScreen> {
  bool _isAndroid10Plus = false;
  bool _isInitialized = false;
  String _androidVersion = 'Unknown';
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _checkAndroidVersion();
  }

  Future<void> _checkAndroidVersion() async {
    try {
      await PlatformNotificationService.instance.initialize();
      final isAndroid10Plus = await PlatformNotificationService.instance.isAndroid10Plus();
      final platformInfo = PlatformNotificationService.instance.getPlatformInfo();
      
      setState(() {
        _isInitialized = true;
        _isAndroid10Plus = isAndroid10Plus && platformInfo.toLowerCase() == 'android';
        _androidVersion = platformInfo;
      });
    } catch (e) {
      setState(() {
        _androidVersion = 'Error: $e';
      });
    }
  }

  Future<void> _sendAndroid10PlusNotification() async {
    setState(() {
      _notificationCount++;
    });
    
    await PlatformNotificationService.instance.showFriendlyNotification(
      title: 'Android 10+ Features 🎯',
      body: 'LED lights, vibration, and enhanced notifications!',
      payload: 'android_10_plus_demo_$_notificationCount',
    );
  }

  Future<void> _sendFriendlyMessage() async {
    await FriendlyNotificationService.instance.sendImmediateFriendlyMessage(type: 'motivation');
  }

  Future<void> _sendScheduledNotification() async {
    final scheduledTime = DateTime.now().add(const Duration(seconds: 5));
    await PlatformNotificationService.instance.showScheduledNotification(
      title: 'Scheduled Android 10+',
      body: 'This notification uses Android 10+ advanced features!',
      scheduledTime: scheduledTime,
      payload: 'scheduled_android_10_plus',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Android 10+ Demo'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Android 10+ Status Card
            Card(
              color: _isAndroid10Plus ? Colors.green.shade50 : Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isAndroid10Plus ? Icons.check_circle : Icons.info,
                          color: _isAndroid10Plus ? Colors.green : Colors.orange,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Android 10+ Status',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Platform: $_androidVersion'),
                    Text('Android 10+: ${_isAndroid10Plus ? "✅ Yes" : "❌ No"}'),
                    Text('Service Ready: ${_isInitialized ? "✅ Yes" : "❌ No"}'),
                    if (_isAndroid10Plus) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '🎯 Advanced features enabled:\n• LED notification lights\n• Enhanced vibration patterns\n• Custom notification channels\n• Green fitness theme color',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Feature Buttons
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildFeatureButton(
                    icon: Icons.android,
                    label: 'Android 10+ Test',
                    description: 'LED + Vibration',
                    onPressed: _isAndroid10Plus ? _sendAndroid10PlusNotification : null,
                    color: Colors.green,
                  ),
                  _buildFeatureButton(
                    icon: Icons.favorite,
                    label: 'Friendly Message',
                    description: 'Smart Content',
                    onPressed: _sendFriendlyMessage,
                    color: Colors.pink,
                  ),
                  _buildFeatureButton(
                    icon: Icons.schedule,
                    label: 'Scheduled',
                    description: '5 sec delay',
                    onPressed: _sendScheduledNotification,
                    color: Colors.blue,
                  ),
                  _buildFeatureButton(
                    icon: Icons.settings,
                    label: 'Check Version',
                    description: 'Device info',
                    onPressed: _checkAndroidVersion,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
            
            // Android 10+ Features Info
            Card(
              color: Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Android 10+ Exclusive Features:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text('🔔 Advanced notification channels'),
                    const Text('💚 LED notification lights (green)'),
                    const Text('📳 Enhanced vibration patterns'),
                    const Text('🎨 Custom notification colors'),
                    const Text('📱 Improved notification management'),
                    const Text('🚀 Better background handling'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureButton({
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback? onPressed,
    required Color color,
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
                color: onPressed != null ? color : Colors.grey,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: onPressed != null ? null : Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: onPressed != null ? Colors.grey.shade600 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
