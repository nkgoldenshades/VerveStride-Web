import 'package:flutter/material.dart';
import 'package:vervestride/services/notification_service.dart';

class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({super.key});

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Test Notifications',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: () async {
                try {
                  await NotificationService.instance.sendActivityMonitoringNotification(
                    title: 'Test Notification',
                    body: 'This is a test notification from VerveStride!',
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Test notification sent!')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Send Test Notification'),
            ),
            
            const SizedBox(height: 10),
            
            ElevatedButton(
              onPressed: () async {
                try {
                  await NotificationService.instance.sendFriendlyNotification(
                    title: 'Friendly Test',
                    body: 'This is a friendly reminder test!',
                    type: 'test_friendly',
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Friendly notification sent!')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Send Friendly Notification'),
            ),
            
            const SizedBox(height: 10),
            
            ElevatedButton(
              onPressed: () async {
                try {
                  await NotificationService.instance.rescheduleHumaneReminders();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Humane reminders rescheduled!')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Reschedule Reminders'),
            ),
            
            const SizedBox(height: 20),
            
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Troubleshooting Tips:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('• Check app notification permissions'),
                    Text('• Ensure Do Not Disturb is off'),
                    Text('• Check notification channels in settings'),
                    Text('• Look for debug messages in console'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
