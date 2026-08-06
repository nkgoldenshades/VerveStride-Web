import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../services/custom_reminder_service.dart';
import 'add_reminder_dialog.dart';

/// Today Tab - Shows all reminders for current day
/// Grouped into: Past (Completed), Current (Upcoming), Missed
class RemindersTodayTab extends StatefulWidget {
  const RemindersTodayTab({super.key});

  @override
  State<RemindersTodayTab> createState() => _RemindersTodayTabState();
}

class _RemindersTodayTabState extends State<RemindersTodayTab> {
  final CustomReminderService _reminderService = CustomReminderService.instance;
  List<CustomReminder> _todayReminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodayReminders();
  }

  Future<void> _loadTodayReminders() async {
    setState(() => _isLoading = true);
    try {
      final all = await _reminderService.getActiveReminders();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Filter reminders for today
      final todayReminders = all.where((r) {
        if (r.repeat == 'once') {
          final rDate = DateTime(
            r.scheduledTime.year,
            r.scheduledTime.month,
            r.scheduledTime.day,
          );
          return rDate.isAtSameMomentAs(today);
        } else if (r.repeat == 'daily') {
          return true; // Daily reminders show every day
        } else if (r.repeat == 'weekly') {
          // Check if today's weekday matches
          final weekday = now.weekday; // 1=Mon, 7=Sun
          final weekdays = r.metadata['weekdays'] as List<dynamic>?;
          if (weekdays != null) {
            return weekdays.contains(weekday);
          }
          return false;
        }
        return false;
      }).toList();

      todayReminders.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

      if (!mounted) return;
      setState(() {
        _todayReminders = todayReminders;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<CustomReminder> get _pastReminders {
    final now = DateTime.now();
    return _todayReminders.where((r) {
      return r.scheduledTime.isBefore(now) && 
             r.metadata['completed_today'] != true;
    }).toList();
  }

  List<CustomReminder> get _currentReminders {
    final now = DateTime.now();
    return _todayReminders.where((r) {
      return r.scheduledTime.isAfter(now) || 
             r.scheduledTime.isAtSameMomentAs(now);
    }).toList();
  }

  List<CustomReminder> get _completedReminders {
    return _todayReminders.where((r) {
      return r.metadata['completed_today'] == true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadTodayReminders,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'TODAY - ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // Completed Section
          if (_completedReminders.isNotEmpty) ...[
            _buildSectionHeader('Completed', Icons.check_circle, Colors.green),
            ..._completedReminders.map((r) => _buildReminderCard(r, 'completed')),
            const SizedBox(height: 16),
          ],

          // Current Section
          if (_currentReminders.isNotEmpty) ...[
            _buildSectionHeader('Upcoming', Icons.schedule, AppColors.primary),
            ..._currentReminders.map((r) => _buildReminderCard(r, 'current')),
            const SizedBox(height: 16),
          ],

          // Missed Section
          if (_pastReminders.isNotEmpty) ...[
            _buildSectionHeader('Missed', Icons.error_outline, Colors.red),
            ..._pastReminders.map((r) => _buildReminderCard(r, 'missed')),
            const SizedBox(height: 16),
          ],

          // Empty state
          if (_todayReminders.isEmpty) ...[
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.event_available,
                    size: 64,
                    color: Colors.grey.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No reminders for today',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showAddReminderDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Reminder for Today'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteReminder(CustomReminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Reminder', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Delete "${reminder.title}"?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _reminderService.deleteReminder(reminder.id);
      await _loadTodayReminders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder deleted')),
      );
    }
  }

  Widget _buildReminderCard(CustomReminder reminder, String status) {
    return GestureDetector(
      onLongPress: () => _deleteReminder(reminder),
      child: Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(reminder.categoryIcon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          decoration: status == 'completed' 
                              ? TextDecoration.lineThrough 
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('hh:mm a').format(reminder.scheduledTime),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (status == 'completed')
                  const Icon(Icons.check_circle, color: Colors.green, size: 28),
                if (status == 'missed')
                  const Icon(Icons.error, color: Colors.red, size: 28),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (status != 'completed') ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _markAsDone(reminder),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Done'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _skipReminder(reminder),
                      icon: const Icon(Icons.skip_next, size: 18),
                      label: const Text('Skip'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
                if (status == 'completed')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _undoComplete(reminder),
                      icon: const Icon(Icons.undo, size: 18),
                      label: const Text('Undo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }

  Future<void> _markAsDone(CustomReminder reminder) async {
    reminder.metadata['completed_today'] = true;
    await _reminderService.updateReminder(reminder);
    await _loadTodayReminders();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Marked as done')),
    );
  }

  Future<void> _skipReminder(CustomReminder reminder) async {
    reminder.metadata['skipped_today'] = true;
    await _reminderService.updateReminder(reminder);
    await _loadTodayReminders();
  }

  Future<void> _undoComplete(CustomReminder reminder) async {
    reminder.metadata.remove('completed_today');
    await _reminderService.updateReminder(reminder);
    await _loadTodayReminders();
  }

  void _showAddReminderDialog() {
    showDialog(
      context: context,
      builder: (context) => AddReminderDialog(
        initialDate: DateTime.now(),
        onSaved: _loadTodayReminders,
      ),
    );
  }
}
