import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_theme.dart';
import '../../services/custom_reminder_service.dart';

/// History Tab - Shows past reminders with calendar view and export functionality
class RemindersHistoryTab extends StatefulWidget {
  const RemindersHistoryTab({super.key});

  @override
  State<RemindersHistoryTab> createState() => _RemindersHistoryTabState();
}

class _RemindersHistoryTabState extends State<RemindersHistoryTab> {
  final CustomReminderService _reminderService = CustomReminderService.instance;
  List<CustomReminder> _allReminders = [];
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  String _filter = 'all'; // all, completed, missed, skipped

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);
    try {
      final all = await _reminderService.getAllReminders();
      if (!mounted) return;
      setState(() {
        _allReminders = all;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<CustomReminder> get _filteredReminders {
    final selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    
    final dayReminders = _allReminders.where((r) {
      final rDate = DateTime(
        r.scheduledTime.year,
        r.scheduledTime.month,
        r.scheduledTime.day,
      );
      return rDate.isAtSameMomentAs(selected);
    }).toList();

    if (_filter == 'all') return dayReminders;
    if (_filter == 'completed') {
      return dayReminders.where((r) => r.metadata['completed_today'] == true).toList();
    }
    if (_filter == 'missed') {
      return dayReminders.where((r) => 
        r.scheduledTime.isBefore(DateTime.now()) && 
        r.metadata['completed_today'] != true &&
        r.metadata['skipped_today'] != true
      ).toList();
    }
    if (_filter == 'skipped') {
      return dayReminders.where((r) => r.metadata['skipped_today'] == true).toList();
    }
    return dayReminders;
  }

  Future<void> _showExportDialog() async {
    DateTime? fromDate;
    DateTime? toDate;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            'Export Notification History',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select date range to export:',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              
              // From Date
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: fromDate ?? DateTime.now().subtract(const Duration(days: 30)),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setDialogState(() => fromDate = picked);
                  }
                },
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  fromDate == null 
                      ? 'From Date' 
                      : DateFormat('MMM dd, yyyy').format(fromDate!),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                ),
              ),
              const SizedBox(height: 12),
              
              // To Date
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: toDate ?? DateTime.now(),
                    firstDate: fromDate ?? DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setDialogState(() => toDate = picked);
                  }
                },
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  toDate == null 
                      ? 'To Date' 
                      : DateFormat('MMM dd, yyyy').format(toDate!),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: fromDate != null && toDate != null
                  ? () {
                      Navigator.pop(context);
                      _exportNotifications(fromDate!, toDate!);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('Export'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportNotifications(DateTime fromDate, DateTime toDate) async {
    try {
      // Show loading
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Exporting notification history...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Filter reminders by date range
      final from = DateTime(fromDate.year, fromDate.month, fromDate.day);
      final to = DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59);
      
      final filteredReminders = _allReminders.where((r) {
        return r.scheduledTime.isAfter(from) && r.scheduledTime.isBefore(to);
      }).toList();

      if (filteredReminders.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No notifications found in selected date range'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Prepare export data
      final exportData = {
        'export_date': DateTime.now().toIso8601String(),
        'date_range': {
          'from': fromDate.toIso8601String(),
          'to': toDate.toIso8601String(),
        },
        'total_notifications': filteredReminders.length,
        'notifications': filteredReminders.map((r) {
          final isCompleted = r.metadata['completed_today'] == true;
          final isSkipped = r.metadata['skipped_today'] == true;
          final isMissed = r.scheduledTime.isBefore(DateTime.now()) && 
                           !isCompleted && !isSkipped;
          
          return {
            'id': r.id,
            'title': r.title,
            'body': r.body,
            'scheduled_time': r.scheduledTime.toIso8601String(),
            'category': r.category,
            'alert_type': r.alertType,
            'repeat': r.repeat,
            'created_by': r.createdBy,
            'status': isCompleted ? 'completed' : 
                     isSkipped ? 'skipped' : 
                     isMissed ? 'missed' : 'pending',
            'is_active': r.isActive,
            'created_at': r.createdAt.toIso8601String(),
            'metadata': r.metadata,
          };
        }).toList(),
        'summary': {
          'completed': filteredReminders.where((r) => 
            r.metadata['completed_today'] == true).length,
          'missed': filteredReminders.where((r) => 
            r.scheduledTime.isBefore(DateTime.now()) && 
            r.metadata['completed_today'] != true &&
            r.metadata['skipped_today'] != true).length,
          'skipped': filteredReminders.where((r) => 
            r.metadata['skipped_today'] == true).length,
        },
      };

      // Save to file
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'vervestride_notifications_${DateFormat('yyyyMMdd').format(fromDate)}_to_${DateFormat('yyyyMMdd').format(toDate)}.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonString);

      // Share file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'VerveStride Notification History (${DateFormat('MMM dd').format(fromDate)} - ${DateFormat('MMM dd, yyyy').format(toDate)})',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${filteredReminders.length} notifications'),
          backgroundColor: AppColors.secondary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadReminders,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'HISTORY',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                onPressed: _showExportDialog,
                icon: const Icon(Icons.file_download),
                tooltip: 'Export History',
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Calendar (simplified - just month/year selector)
          Card(
            color: AppColors.card,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      setState(() {
                        _selectedDate = DateTime(
                          _selectedDate.year,
                          _selectedDate.month,
                          _selectedDate.day - 1,
                        );
                      });
                    },
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    child: Text(
                      DateFormat('MMM dd, yyyy').format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      final next = DateTime(
                        _selectedDate.year,
                        _selectedDate.month,
                        _selectedDate.day + 1,
                      );
                      if (next.isBefore(DateTime.now().add(const Duration(days: 1)))) {
                        setState(() => _selectedDate = next);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                _buildFilterChip('Completed', 'completed'),
                _buildFilterChip('Missed', 'missed'),
                _buildFilterChip('Skipped', 'skipped'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Reminders list
          if (_filteredReminders.isEmpty) ...[
            const SizedBox(height: 40),
            Center(
              child: Text(
                'No reminders for this date',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ] else ...[
            ..._filteredReminders.map((r) => _buildReminderCard(r)),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _filter = value);
        },
        selectedColor: AppColors.primary.withOpacity(0.3),
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
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
      await _loadReminders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder deleted')),
      );
    }
  }

  Widget _buildReminderCard(CustomReminder reminder) {
    final isCompleted = reminder.metadata['completed_today'] == true;
    final isSkipped = reminder.metadata['skipped_today'] == true;
    final isMissed = reminder.scheduledTime.isBefore(DateTime.now()) && 
                     !isCompleted && !isSkipped;

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
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          DateFormat('hh:mm a').format(reminder.scheduledTime),
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: Icon(
          isCompleted ? Icons.check_circle : 
          isSkipped ? Icons.skip_next :
          isMissed ? Icons.error : Icons.schedule,
          color: isCompleted ? Colors.green :
                 isSkipped ? Colors.grey :
                 isMissed ? Colors.red : AppColors.primary,
        ),
      ),
      ),
    ),
    );
  }
}
