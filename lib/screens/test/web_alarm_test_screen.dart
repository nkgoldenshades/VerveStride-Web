import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/web_alarm_service.dart';
import '../../services/custom_reminder_service.dart';
import '../../services/web_notification_helper.dart';
import '../../core/app_theme.dart';
import '../../widgets/gradient_scaffold.dart';

/// Web Alarm Test Screen
/// 
/// Debug/test screen for web alarms.
/// Allows manual testing and monitoring.
class WebAlarmTestScreen extends StatefulWidget {
  const WebAlarmTestScreen({super.key});

  @override
  State<WebAlarmTestScreen> createState() => _WebAlarmTestScreenState();
}

class _WebAlarmTestScreenState extends State<WebAlarmTestScreen> {
  bool _isMonitoring = false;
  List<CustomReminder> _activeAlarms = [];
  String _statusMessage = 'Not started';
  int _testMinutes = 1;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _loadAlarms();
  }

  void _checkStatus() {
    if (!kIsWeb) {
      setState(() {
        _statusMessage = 'Web alarms only work on web platform';
      });
      return;
    }

    setState(() {
      _isMonitoring = true;
      _statusMessage = 'Monitoring active';
    });
  }

  Future<void> _loadAlarms() async {
    try {
      final reminders = await CustomReminderService.instance.getActiveReminders();
      final alarms = reminders.where((r) => r.alertType == 'alarm').toList();
      
      setState(() {
        _activeAlarms = alarms;
      });
    } catch (e) {
      _showError('Failed to load alarms: $e');
    }
  }

  Future<void> _startMonitoring() async {
    if (!kIsWeb) {
      _showError('Web alarms only work on web platform');
      return;
    }

    try {
      WebAlarmService.instance.startMonitoring();
      setState(() {
        _isMonitoring = true;
        _statusMessage = 'Monitoring started';
      });
      _showSuccess('Web alarm monitoring started');
    } catch (e) {
      _showError('Failed to start: $e');
    }
  }

  Future<void> _stopMonitoring() async {
    try {
      WebAlarmService.instance.stopMonitoring();
      setState(() {
        _isMonitoring = false;
        _statusMessage = 'Monitoring stopped';
      });
      _showSuccess('Web alarm monitoring stopped');
    } catch (e) {
      _showError('Failed to stop: $e');
    }
  }

  Future<void> _createTestAlarm() async {
    try {
      // Check permissions first (especially important for alarms)
      if (!kIsWeb) {
        final hasPermissions = await CustomReminderService.instance.hasAllAlarmPermissions();
        if (!hasPermissions && mounted) {
          final granted = await CustomReminderService.instance.requestAllAlarmPermissions(context);
          if (!granted) {
            _showError('Alarm permissions not granted. Please enable them in Settings.');
            return;
          }
        }
      }
      
      final scheduledTime = DateTime.now().add(Duration(minutes: _testMinutes));
      
      await CustomReminderService.instance.scheduleReminder(
        title: 'Test Alarm',
        body: 'This is a test alarm set for $_testMinutes minute(s) from now',
        scheduledTime: scheduledTime,
        repeat: 'once',
        createdBy: 'user',
        category: 'custom',
        alertType: 'alarm',
        metadata: {
          'alarm_sound_mode': 'ai', // AI voice mode for testing
          'ai_wake_style': 'Test alarm - please verify it works!',
        },
      );

      _showSuccess('Test alarm created for ${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')}');
      await _loadAlarms();
    } catch (e) {
      _showError('Failed to create alarm: $e');
    }
  }

  Future<void> _deleteAlarm(String id) async {
    try {
      await CustomReminderService.instance.cancelReminder(id, cancelNotification: true);
      _showSuccess('Alarm deleted');
      await _loadAlarms();
    } catch (e) {
      _showError('Failed to delete: $e');
    }
  }

  Future<void> _testStopAlarm() async {
    try {
      await WebAlarmService.instance.stopAlarm();
      _showSuccess('Stop alarm command sent');
    } catch (e) {
      _showError('Failed to stop: $e');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildNotificationPermissionCard() {
    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  WebNotificationHelper.permission == 'granted' 
                      ? Icons.notifications_active 
                      : Icons.notifications_off,
                  color: WebNotificationHelper.permission == 'granted' 
                      ? Colors.green 
                      : Colors.orange,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Web Notifications',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Permission: ${WebNotificationHelper.permission}',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: WebNotificationHelper.permission != 'granted' 
                  ? () async {
                      final permission = await WebNotificationHelper.requestPermission();
                      setState(() {});
                      if (permission == 'granted') {
                        _showSuccess('Notification permission granted!');
                      } else {
                        _showError('Notification permission denied');
                      }
                    }
                  : null,
              icon: const Icon(Icons.notifications),
              label: Text(
                WebNotificationHelper.permission == 'granted' 
                    ? 'Permission Granted ✓' 
                    : 'Request Permission',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: WebNotificationHelper.permission == 'granted' 
                    ? Colors.green 
                    : AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Web Alarm Test'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Web Notification Permission (only on web)
            if (kIsWeb) _buildNotificationPermissionCard(),
            
            if (kIsWeb) const SizedBox(height: 16),
            
            // Status Card
            _buildStatusCard(),
            
            const SizedBox(height: 16),
            
            // Quick Test Section
            _buildQuickTestCard(),
            
            const SizedBox(height: 16),
            
            // Active Alarms
            _buildActiveAlarmsCard(),
            
            const SizedBox(height: 16),
            
            // Manual Controls
            _buildManualControlsCard(),
            
            const SizedBox(height: 16),
            
            // Instructions
            _buildInstructionsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isMonitoring ? Icons.check_circle : Icons.cancel,
                  color: _isMonitoring ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Monitoring Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _statusMessage,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isMonitoring ? null : _startMonitoring,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isMonitoring ? _stopMonitoring : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTestCard() {
    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚡ Quick Test',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create a test alarm that will ring in $_testMinutes minute(s)',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Minutes: '),
                Expanded(
                  child: Slider(
                    value: _testMinutes.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '$_testMinutes min',
                    onChanged: (value) {
                      setState(() {
                        _testMinutes = value.round();
                      });
                    },
                  ),
                ),
                Text('$_testMinutes'),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _createTestAlarm,
              icon: const Icon(Icons.alarm_add),
              label: const Text('Create Test Alarm'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveAlarmsCard() {
    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Active Alarms (${_activeAlarms.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: _loadAlarms,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_activeAlarms.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No active alarms',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
            else
              ..._activeAlarms.map((alarm) => _buildAlarmTile(alarm)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmTile(CustomReminder alarm) {
    final now = DateTime.now();
    final diff = alarm.scheduledTime.difference(now);
    final isPast = diff.isNegative;
    final timeText = isPast
        ? 'Passed'
        : '${diff.inHours}h ${diff.inMinutes % 60}m';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPast ? Colors.red : AppColors.primary,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.alarm,
            color: isPast ? Colors.red : AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alarm.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${alarm.scheduledTime.hour}:${alarm.scheduledTime.minute.toString().padLeft(2, '0')} - $timeText',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _deleteAlarm(alarm.id),
            icon: const Icon(Icons.delete, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildManualControlsCard() {
    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🎛️ Manual Controls',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _testStopAlarm,
              icon: const Icon(Icons.stop_circle),
              label: const Text('Force Stop Current Alarm'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _loadAlarms,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Alarm List'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      color: AppColors.card.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📖 How to Test',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInstruction(
              '1',
              'Ensure monitoring is ON (green status)',
            ),
            _buildInstruction(
              '2',
              'Set test alarm to 1-2 minutes',
            ),
            _buildInstruction(
              '3',
              'Click "Create Test Alarm"',
            ),
            _buildInstruction(
              '4',
              'Keep this tab open and wait',
            ),
            _buildInstruction(
              '5',
              'Alarm should ring within 1-2 minutes',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Keep this tab open! Web alarms won\'t work if tab is closed.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstruction(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
