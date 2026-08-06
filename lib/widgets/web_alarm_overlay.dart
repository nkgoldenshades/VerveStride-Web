import 'package:flutter/material.dart';
import '../services/web_alarm_service.dart';
import '../services/custom_reminder_service.dart';
import '../core/app_theme.dart';

/// Web Alarm Overlay Widget
/// 
/// Shows a full-screen alarm overlay when alarm rings on web.
/// User can stop or snooze the alarm.
class WebAlarmOverlay extends StatelessWidget {
  final CustomReminder reminder;
  final VoidCallback onDismiss;

  const WebAlarmOverlay({
    super.key,
    required this.reminder,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.95),
      child: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.2),
                  AppColors.secondary.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Alarm Icon with Animation
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.8 + (value * 0.2),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.secondary,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.5),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.alarm,
                          size: 64,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Time Display
                Text(
                  _formatTime(reminder.scheduledTime),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 16),

                // Alarm Title
                Text(
                  reminder.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                if (reminder.body.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    reminder.body,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ],

                const SizedBox(height: 40),

                // Action Buttons
                Row(
                  children: [
                    // Snooze Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await WebAlarmService.instance.snoozeAlarm(10);
                          onDismiss();
                        },
                        icon: const Icon(Icons.snooze),
                        label: const Text('Snooze\n10 min'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Stop Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await WebAlarmService.instance.stopAlarm();
                          await CustomReminderService.instance.cancelReminder(
                            reminder.id,
                            cancelNotification: true,
                          );
                          onDismiss();
                        },
                        icon: const Icon(Icons.stop_circle),
                        label: const Text('Stop'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Custom Snooze
                TextButton.icon(
                  onPressed: () => _showCustomSnooze(context),
                  icon: const Icon(Icons.timer),
                  label: const Text('Custom Snooze'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<void> _showCustomSnooze(BuildContext context) async {
    final controller = TextEditingController(text: '10');
    
    final minutes = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Custom Snooze'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Minutes',
            hintText: 'e.g., 5, 10, 15',
            suffixText: 'min',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value != null && value > 0) {
                Navigator.pop(ctx, value);
              }
            },
            child: const Text('Snooze'),
          ),
        ],
      ),
    );

    if (minutes != null && context.mounted) {
      await WebAlarmService.instance.snoozeAlarm(minutes);
      onDismiss();
    }
  }
}
