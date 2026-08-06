import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../services/custom_reminder_service.dart';
import 'add_reminder_dialog.dart';

/// Upcoming Tab - Shows future reminders grouped by date
class RemindersUpcomingTab extends StatefulWidget {
  const RemindersUpcomingTab({super.key});

  @override
  State<RemindersUpcomingTab> createState() => _RemindersUpcomingTabState();
}

class _RemindersUpcomingTabState extends State<RemindersUpcomingTab> {
  final CustomReminderService _reminderService = CustomReminderService.instance;
  List<CustomReminder> _upcomingReminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUpcomingReminders();
  }

  Future<void> _loadUpcomingReminders() async {
    setState(() => _isLoading = true);
    try {
      final all = await _reminderService.getActiveReminders();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Filter future reminders (including later today + recurring)
      final upcoming = all.where((r) {
        if (r.repeat == 'once') {
          // Include one-time reminders that haven't happened yet (even if today)
          return r.scheduledTime.isAfter(now);
        }
        return r.repeat != 'once'; // Include all recurring reminders
      }).toList();

      upcoming.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

      if (!mounted) return;
      setState(() {
        _upcomingReminders = upcoming;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Map<String, List<CustomReminder>> get _groupedReminders {
    final Map<String, List<CustomReminder>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    
    for (final reminder in _upcomingReminders) {
      if (reminder.repeat != 'once') {
        // Recurring reminders go in separate section
        grouped.putIfAbsent('Recurring', () => []).add(reminder);
      } else {
        final rDate = DateTime(
          reminder.scheduledTime.year,
          reminder.scheduledTime.month,
          reminder.scheduledTime.day,
        );
        
        String key;
        if (rDate.isAtSameMomentAs(today)) {
          key = 'Today (Later)';
        } else if (rDate.isAtSameMomentAs(tomorrow)) {
          key = 'Tomorrow';
        } else if (rDate.isBefore(tomorrow.add(const Duration(days: 7)))) {
          key = DateFormat('EEEE').format(rDate); // Day name
        } else {
          key = DateFormat('MMM dd, yyyy').format(rDate);
        }
        
        grouped.putIfAbsent(key, () => []).add(reminder);
      }
    }
    
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final grouped = _groupedReminders;

    return RefreshIndicator(
      onRefresh: _loadUpcomingReminders,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'UPCOMING REMINDERS',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          if (grouped.isEmpty) ...[
            const SizedBox(height: 40),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.event_note,
                    size: 64,
                    color: Colors.grey.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No upcoming reminders',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            for (final entry in grouped.entries) ...[
              _buildDateHeader(entry.key),
              ...entry.value.map((r) => _buildReminderCard(r)),
              const SizedBox(height: 16),
            ],
          ],

          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showAddReminderDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Reminder'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(String date) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        date,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
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
      await _loadUpcomingReminders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder deleted')),
      );
    }
  }

  Widget _buildReminderCard(CustomReminder reminder) {
    return GestureDetector(
      onLongPress: () => _deleteReminder(reminder),
      child: Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.card,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
        leading: Text(reminder.categoryIcon, style: const TextStyle(fontSize: 28)),
        title: Text(
          reminder.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              reminder.repeat == 'once'
                  ? DateFormat('hh:mm a').format(reminder.scheduledTime)
                  : '${reminder.repeatLabel} • ${DateFormat('hh:mm a').format(reminder.scheduledTime)}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              reminder.alertTypeLabel,
              style: TextStyle(
                fontSize: 12,
                color: reminder.alertType == 'alarm' 
                    ? Colors.orange 
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'edit') {
              _showEditReminderDialog(reminder);
            } else if (value == 'delete') {
              await _reminderService.deleteReminder(reminder.id);
              await _loadUpcomingReminders();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reminder deleted')),
              );
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
      ),
    ),
    );
  }

  void _showAddReminderDialog() {
    showDialog(
      context: context,
      builder: (context) => AddReminderDialog(
        onSaved: _loadUpcomingReminders,
      ),
    );
  }

  void _showEditReminderDialog(CustomReminder reminder) {
    showDialog(
      context: context,
      builder: (context) => AddReminderDialog(
        existingReminder: reminder,
        onSaved: _loadUpcomingReminders,
      ),
    );
  }
}
