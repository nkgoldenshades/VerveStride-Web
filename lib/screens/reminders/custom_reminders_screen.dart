import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_theme.dart';
import '../../services/custom_reminder_service.dart';
import '../../widgets/gradient_scaffold.dart';

class CustomRemindersScreen extends StatefulWidget {
  const CustomRemindersScreen({super.key});

  @override
  State<CustomRemindersScreen> createState() => _CustomRemindersScreenState();
}

class _CustomRemindersScreenState extends State<CustomRemindersScreen> {
  final CustomReminderService _reminderService = CustomReminderService.instance;
  List<CustomReminder> _reminders = [];
  bool _isLoading = true;
  String _filterCategory = 'all';

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);
    try {
      final reminders = await _reminderService.getAllReminders();
      if (!mounted) return;
      setState(() {
        _reminders = reminders;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load reminders: $e')),
      );
    }
  }

  Future<void> _exportReminders() async {
    if (_reminders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No reminders to export')),
      );
      return;
    }

    try {
      final data = _reminders.map((r) => r.toJson()).toList();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/vervestride_reminders_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json',
      );
      await file.writeAsString(jsonStr);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'VerveStride Reminders Export',
      );

      // After sharing, ask whether to delete or keep
      if (!mounted) return;
      final delete = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Delete reminders?',
              style: TextStyle(color: AppColors.textPrimary)),
          content: const Text(
            'Your reminders have been exported. Do you want to delete them now?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (delete == true && mounted) {
        await _reminderService.clearAllReminders();
        await _loadReminders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All reminders deleted')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Delete all reminders?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'This will permanently delete all reminders and cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete all', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _reminderService.clearAllReminders();
    await _loadReminders();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All reminders deleted')),
    );
  }

  List<CustomReminder> get _filteredReminders {
    if (_filterCategory == 'all') return _reminders;
    if (_filterCategory == 'ai') {
      return _reminders.where((r) => r.createdBy == 'ai').toList();
    }
    return _reminders.where((r) => r.category == _filterCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        title: const Text('Custom Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddReminderDialog(),
            tooltip: 'Add Reminder',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'export') {
                _exportReminders();
              } else if (value == 'delete_all') {
                _confirmDeleteAll();
              } else {
                setState(() => _filterCategory = value);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Reminders')),
              const PopupMenuItem(value: 'ai', child: Text('AI Suggested')),
              const PopupMenuItem(value: 'workout', child: Text('💪 Workout')),
              const PopupMenuItem(value: 'meal', child: Text('🍽️ Meal')),
              const PopupMenuItem(value: 'water', child: Text('💧 Water')),
              const PopupMenuItem(value: 'medication', child: Text('💊 Medication')),
              const PopupMenuItem(value: 'custom', child: Text('⏰ Custom')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 18),
                    SizedBox(width: 10),
                    Text('Export as JSON'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, size: 18, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Delete all', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredReminders.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadReminders,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredReminders.length,
                    itemBuilder: (context, index) {
                      final reminder = _filteredReminders[index];
                      return _buildReminderCard(reminder);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _filterCategory == 'all'
                ? 'No reminders yet'
                : 'No ${_filterCategory} reminders',
            style: const TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap + to create your first reminder',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddReminderDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Reminder'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(CustomReminder reminder) {
    final isPast = reminder.isPast;
    final isAI = reminder.createdBy == 'ai';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isPast
              ? Colors.red.withOpacity(0.3)
              : (isAI
                  ? AppColors.accent.withOpacity(0.3)
                  : Colors.white.withOpacity(0.1)),
        ),
      ),
      child: InkWell(
        onTap: () => _showReminderDetails(reminder),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    reminder.categoryIcon,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                reminder.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isPast
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                  decoration: isPast
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            if (isAI)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'AI',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reminder.body,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: reminder.isActive,
                    onChanged: (value) async {
                      await _reminderService.toggleReminder(reminder.id);
                      await _loadReminders();
                    },
                    activeThumbColor: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('MMM dd, yyyy • hh:mm a')
                        .format(reminder.scheduledTime),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      reminder.repeatLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
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

  void _showReminderDetails(CustomReminder reminder) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  reminder.categoryIcon,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    reminder.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              reminder.body,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            _buildDetailRow(
              Icons.access_time,
              'Time',
              DateFormat('MMM dd, yyyy • hh:mm a').format(reminder.scheduledTime),
            ),
            _buildDetailRow(
              Icons.repeat,
              'Repeat',
              reminder.repeatLabel,
            ),
            _buildDetailRow(
              Icons.category,
              'Category',
              reminder.category,
            ),
            _buildDetailRow(
              reminder.createdBy == 'ai' ? Icons.smart_toy : Icons.person,
              'Created by',
              reminder.createdBy == 'ai' ? 'AI Assistant' : 'You',
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showEditReminderDialog(reminder);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      
                      navigator.pop();
                      await _reminderService.deleteReminder(reminder.id);
                      await _loadReminders();
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Reminder deleted')),
                        );
                      }
                    },
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddReminderDialog() {
    _showReminderDialog();
  }

  void _showEditReminderDialog(CustomReminder reminder) {
    _showReminderDialog(existingReminder: reminder);
  }

  void _showReminderDialog({CustomReminder? existingReminder}) {
    final titleController = TextEditingController(text: existingReminder?.title);
    final bodyController = TextEditingController(text: existingReminder?.body);
    DateTime selectedDate = existingReminder?.scheduledTime ?? DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);
    String selectedRepeat = existingReminder?.repeat ?? 'once';
    String selectedCategory = existingReminder?.category ?? 'custom';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text(
            existingReminder == null ? 'Add Reminder' : 'Edit Reminder',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g., Drink water',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: bodyController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'e.g., Time to hydrate!',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: Text('Date', style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text(
                    DateFormat('MMM dd, yyyy').format(selectedDate),
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  trailing: Icon(Icons.calendar_today, color: AppColors.primary),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setDialogState(() => selectedDate = date);
                    }
                  },
                ),
                ListTile(
                  title: Text('Time', style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text(
                    selectedTime.format(context),
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  trailing: Icon(Icons.access_time, color: AppColors.primary),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (time != null) {
                      setDialogState(() => selectedTime = time);
                    }
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedRepeat,
                  dropdownColor: AppColors.card,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Repeat',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'once', child: Text('One time')),
                    DropdownMenuItem(value: 'daily', child: Text('Every day')),
                    DropdownMenuItem(value: 'weekly', child: Text('Every week')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedRepeat = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  dropdownColor: AppColors.card,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Category',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'workout', child: Text('💪 Workout')),
                    DropdownMenuItem(value: 'meal', child: Text('🍽️ Meal')),
                    DropdownMenuItem(value: 'water', child: Text('💧 Water')),
                    DropdownMenuItem(value: 'medication', child: Text('💊 Medication')),
                    DropdownMenuItem(value: 'custom', child: Text('⏰ Custom')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedCategory = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final body = bodyController.text.trim();

                if (title.isEmpty || body.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }

                final scheduledDateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);

                try {
                  if (existingReminder == null) {
                    await _reminderService.scheduleReminder(
                      title: title,
                      body: body,
                      scheduledTime: scheduledDateTime,
                      repeat: selectedRepeat,
                      category: selectedCategory,
                      createdBy: 'user',
                    );
                  } else {
                    existingReminder.title = title;
                    existingReminder.body = body;
                    existingReminder.scheduledTime = scheduledDateTime;
                    existingReminder.repeat = selectedRepeat;
                    existingReminder.category = selectedCategory;
                    await _reminderService.updateReminder(existingReminder);
                  }

                  navigator.pop();
                  await _loadReminders();
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        existingReminder == null
                            ? 'Reminder created!'
                            : 'Reminder updated!',
                      ),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: Text(existingReminder == null ? 'Create' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }
}
