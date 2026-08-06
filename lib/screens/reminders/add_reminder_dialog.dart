import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../core/app_theme.dart';
import '../../services/custom_reminder_service.dart';
import '../../services/battery_optimization_service.dart';

class AddReminderDialog extends StatefulWidget {
  final CustomReminder? existingReminder;
  final DateTime? initialDate;
  final VoidCallback? onSaved;

  const AddReminderDialog({
    super.key,
    this.existingReminder,
    this.initialDate,
    this.onSaved,
  });

  @override
  State<AddReminderDialog> createState() => _AddReminderDialogState();
}

class _AddReminderDialogState extends State<AddReminderDialog> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _snoozeMinutesController = TextEditingController();
  final _reminderService = CustomReminderService.instance;
  
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  DateTime? _fromDate;
  DateTime? _toDate;
  String _selectedRepeat = 'once';
  String _selectedCategory = 'custom';
  String _selectedAlertType = 'notification';
  List<int> _selectedWeekdays = [];
  int _snoozeMinutes = 10;
  String? _customSoundPath; // path to user-picked MP3
  String _alarmSoundMode = 'normal'; // 'normal' | 'mp3' | 'ai' | 'ai_music'
  final _aiWakeStyleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    
    if (widget.existingReminder != null) {
      final r = widget.existingReminder!;
      _titleController.text = r.title;
      _bodyController.text = r.body;
      _selectedDate = r.scheduledTime;
      _selectedTime = TimeOfDay.fromDateTime(r.scheduledTime);
      _selectedRepeat = r.repeat;
      _selectedCategory = r.category;
      _selectedAlertType = r.alertType;
      _selectedWeekdays = (r.metadata['weekdays'] as List<dynamic>?)
          ?.map((e) => e as int).toList() ?? [];
      _fromDate = _parseMetadataDate(r.metadata['from_date']);
      _toDate = _parseMetadataDate(r.metadata['to_date']);
      if (r.repeat != 'once') {
        _fromDate ??= DateTime(
          r.scheduledTime.year,
          r.scheduledTime.month,
          r.scheduledTime.day,
        );
        _toDate ??= _fromDate!.add(const Duration(days: 30));
      }
      final rawSnooze = r.metadata['snooze_minutes'];
      if (rawSnooze is num) {
        _snoozeMinutes = rawSnooze.toInt();
      } else {
        _snoozeMinutes = 10;
      }
      _snoozeMinutesController.text = _snoozeMinutes.toString();
      _customSoundPath = r.metadata['custom_sound_uri'] as String?;
      _alarmSoundMode = r.metadata['alarm_sound_mode'] as String? ?? 'normal';
      _aiWakeStyleController.text = r.metadata['ai_wake_style'] as String? ?? '';
    } else {
      _selectedDate = widget.initialDate ?? DateTime.now();
      _selectedTime = TimeOfDay.now();
      _snoozeMinutes = 10;
      _snoozeMinutesController.text = '10';
    }
    
    // Auto-select alert type based on category
    if (widget.existingReminder == null) {
      _selectedAlertType = CustomReminder.getDefaultAlertType(_selectedCategory);
    }
  }

  DateTime? _parseMetadataDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _snoozeMinutesController.dispose();
    _aiWakeStyleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(
        widget.existingReminder == null ? 'Add Reminder' : 'Edit Reminder',
        style: const TextStyle(color: AppColors.textPrimary),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g., Take medicine',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bodyController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'e.g., Don\'t forget your vitamins',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            
            // Category
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              dropdownColor: AppColors.card,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Category'),
              items: const [
                DropdownMenuItem(value: 'workout', child: Text('💪 Workout')),
                DropdownMenuItem(value: 'meal', child: Text('🍽️ Meal')),
                DropdownMenuItem(value: 'water', child: Text('💧 Water')),
                DropdownMenuItem(value: 'medication', child: Text('💊 Medication')),
                DropdownMenuItem(value: 'appointment', child: Text('📅 Appointment')),
                DropdownMenuItem(value: 'custom', child: Text('⏰ Custom')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                  // Auto-update alert type based on category
                  _selectedAlertType = CustomReminder.getDefaultAlertType(value);
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Alert Type
            const Text(
              'Alert Type',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildAlertTypeCard(
                    '🔔 Alarm',
                    'Full-screen\nRings on silent',
                    'alarm',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAlertTypeCard(
                    '📱 Notification',
                    'Notification bar\nRespects silent',
                    'notification',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Repeat Type
            DropdownButtonFormField<String>(
              initialValue: _selectedRepeat,
              dropdownColor: AppColors.card,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Repeat'),
              items: const [
                DropdownMenuItem(value: 'once', child: Text('One time')),
                DropdownMenuItem(value: 'daily', child: Text('Every day')),
                DropdownMenuItem(value: 'weekly', child: Text('Every week')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedRepeat = value!;
                  // Initialize date range for recurring reminders
                  if (value != 'once' && _fromDate == null) {
                    _fromDate = DateTime.now();
                    _toDate = DateTime.now().add(const Duration(days: 30));
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Date Range for recurring reminders
            if (_selectedRepeat != 'once') ...[
              const Text(
                'Date Range',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'From',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      subtitle: Text(
                        _fromDate != null 
                            ? DateFormat('MMM dd, yyyy').format(_fromDate!)
                            : 'Select date',
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                      trailing: Icon(Icons.calendar_today, 
                          color: AppColors.primary, size: 20),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _fromDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() {
                            _fromDate = date;
                            // Ensure toDate is after fromDate
                            if (_toDate != null && _toDate!.isBefore(date)) {
                              _toDate = date.add(const Duration(days: 7));
                            }
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'To',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      subtitle: Text(
                        _toDate != null 
                            ? DateFormat('MMM dd, yyyy').format(_toDate!)
                            : 'Select date',
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                      trailing: Icon(Icons.calendar_today, 
                          color: AppColors.primary, size: 20),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _toDate ?? 
                              (_fromDate ?? DateTime.now()).add(const Duration(days: 30)),
                          firstDate: _fromDate ?? DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() => _toDate = date);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            // Weekly days selector
            if (_selectedRepeat == 'weekly') ...[
              const Text(
                'Select Days',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildDayChip('Mon', 1),
                  _buildDayChip('Tue', 2),
                  _buildDayChip('Wed', 3),
                  _buildDayChip('Thu', 4),
                  _buildDayChip('Fri', 5),
                  _buildDayChip('Sat', 6),
                  _buildDayChip('Sun', 7),
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            // Date picker (only for one-time reminders)
            if (_selectedRepeat == 'once') ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Date', style: TextStyle(color: AppColors.textPrimary)),
                subtitle: Text(
                  DateFormat('MMM dd, yyyy').format(_selectedDate),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                trailing: Icon(Icons.calendar_today, color: AppColors.primary),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                  }
                },
              ),
            ],
            
            // Time picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Time', style: TextStyle(color: AppColors.textPrimary)),
              subtitle: Text(
                _selectedTime.format(context),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              trailing: Icon(Icons.access_time, color: AppColors.primary),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime,
                );
                if (time != null) {
                  setState(() => _selectedTime = time);
                }
              },
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _snoozeMinutesController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Snooze minutes',
                hintText: 'e.g., 10',
              ),
              onChanged: (v) {
                final parsed = int.tryParse(v);
                if (parsed == null) return;
                setState(() => _snoozeMinutes = parsed);
              },
            ),

            // Alarm sound mode — only for alarm type
            if (_selectedAlertType == 'alarm') ...[
              const SizedBox(height: 16),
              const Text(
                'Wake-up Sound',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              // 4-mode selector
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSoundModeChip('normal', '🔔 Normal'),
                  _buildSoundModeChip('mp3', '🎵 MP3'),
                  _buildSoundModeChip('ai', '🤖 AI Voice'),
                  _buildSoundModeChip('ai_music', '🤖+🎵 AI + Music'),
                ],
              ),

              // MP3 picker — shown for mp3 and ai_music modes
              if (_alarmSoundMode == 'mp3' || _alarmSoundMode == 'ai_music') ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickAlarmSound,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _customSoundPath != null
                            ? AppColors.primary
                            : Colors.grey.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: _customSoundPath != null
                          ? AppColors.primary.withOpacity(0.08)
                          : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.music_note,
                            color: _customSoundPath != null
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _customSoundPath != null
                                ? p.basename(_customSoundPath!)
                                : 'Tap to pick MP3 / audio file',
                            style: TextStyle(
                              color: _customSoundPath != null
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_customSoundPath != null)
                          GestureDetector(
                            onTap: () =>
                                setState(() => _customSoundPath = null),
                            child: const Icon(Icons.close,
                                size: 18,
                                color: AppColors.textSecondary),
                          )
                        else
                          const Icon(Icons.upload_file,
                              size: 18,
                              color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              ],

              // AI wake style — shown for ai and ai_music modes
              if (_alarmSoundMode == 'ai' || _alarmSoundMode == 'ai_music') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _aiWakeStyleController,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 13),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Describe wake-up style (optional)',
                    hintText:
                        'e.g. "be aggressive", "motivate me for gym", "speak softly"',
                    hintStyle:
                        TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveReminder,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
          ),
          child: Text(widget.existingReminder == null ? 'Create' : 'Update'),
        ),
      ],
    );
  }

  Widget _buildAlertTypeCard(String title, String subtitle, String type) {
    final isSelected = _selectedAlertType == type;
    return InkWell(
      onTap: () => setState(() => _selectedAlertType = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected 
              ? AppColors.primary.withOpacity(0.1) 
              : Colors.transparent,
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayChip(String label, int weekday) {
    final isSelected = _selectedWeekdays.contains(weekday);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedWeekdays.add(weekday);
          } else {
            _selectedWeekdays.remove(weekday);
          }
        });
      },
      selectedColor: AppColors.primary.withOpacity(0.3),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
      ),
    );
  }

  Widget _buildSoundModeChip(String mode, String label) {
    final selected = _alarmSoundMode == mode;
    return FilterChip(
      label: Text(label,
          style: TextStyle(
              fontSize: 12,
              color: selected ? AppColors.primary : AppColors.textSecondary)),
      selected: selected,
      onSelected: (_) => setState(() => _alarmSoundMode = mode),
      selectedColor: AppColors.primary.withOpacity(0.15),
      backgroundColor: Colors.transparent,
      side: BorderSide(
          color: selected
              ? AppColors.primary
              : Colors.grey.withOpacity(0.3)),
      showCheckmark: false,
    );
  }

  Future<void> _pickAlarmSound() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'ogg', 'm4a'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) return;
      setState(() => _customSoundPath = path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick file: $e')),
      );
    }
  }

  Future<void> _saveReminder() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final snoozeMinutesRaw = _snoozeMinutesController.text.trim();
    final snoozeMinutesParsed = int.tryParse(snoozeMinutesRaw);
    if (snoozeMinutesParsed != null) {
      _snoozeMinutes = snoozeMinutesParsed;
    }

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    if (_selectedRepeat == 'weekly' && _selectedWeekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day')),
      );
      return;
    }

    // Validate date range for recurring reminders
    if (_selectedRepeat != 'once') {
      if (_fromDate == null || _toDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select from and to dates')),
        );
        return;
      }
      if (_toDate!.isBefore(_fromDate!)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('To date must be after from date')),
        );
        return;
      }
    }

    final scheduledDateTime = DateTime(
      _selectedRepeat == 'once' ? _selectedDate.year : (_fromDate ?? DateTime.now()).year,
      _selectedRepeat == 'once' ? _selectedDate.month : (_fromDate ?? DateTime.now()).month,
      _selectedRepeat == 'once' ? _selectedDate.day : (_fromDate ?? DateTime.now()).day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    try {
      if (widget.existingReminder == null) {
        // Ask for battery optimization exemption on first alarm creation
        if (_selectedAlertType == 'alarm' && context.mounted) {
          await BatteryOptimizationService.instance.requestIfNeeded(context);
        }
        final metadata = <String, dynamic>{};
        if (_selectedRepeat == 'weekly') {
          metadata['weekdays'] = _selectedWeekdays;
        }
        if (_selectedRepeat != 'once') {
          metadata['from_date'] = _fromDate!.toIso8601String();
          metadata['to_date'] = _toDate!.toIso8601String();
        }
        metadata['snooze_minutes'] = _snoozeMinutes;
        if (_customSoundPath != null) {
          metadata['custom_sound_uri'] = _customSoundPath;
        }
        metadata['alarm_sound_mode'] = _alarmSoundMode;
        if (_aiWakeStyleController.text.trim().isNotEmpty) {
          metadata['ai_wake_style'] = _aiWakeStyleController.text.trim();
        }
        
        await _reminderService.scheduleReminder(
          title: title,
          body: body,
          scheduledTime: scheduledDateTime,
          repeat: _selectedRepeat,
          category: _selectedCategory,
          alertType: _selectedAlertType,
          createdBy: 'user',
          metadata: metadata,
        );
      } else {
        final updated = widget.existingReminder!;
        updated.title = title;
        updated.body = body;
        updated.scheduledTime = scheduledDateTime;
        updated.repeat = _selectedRepeat;
        updated.category = _selectedCategory;
        updated.alertType = _selectedAlertType;
        if (_selectedRepeat == 'weekly') {
          updated.metadata['weekdays'] = _selectedWeekdays;
        }
        if (_selectedRepeat != 'once') {
          updated.metadata['from_date'] = _fromDate!.toIso8601String();
          updated.metadata['to_date'] = _toDate!.toIso8601String();
        }
        updated.metadata['snooze_minutes'] = _snoozeMinutes;
        if (_customSoundPath != null) {
          updated.metadata['custom_sound_uri'] = _customSoundPath;
        } else {
          updated.metadata.remove('custom_sound_uri');
        }
        updated.metadata['alarm_sound_mode'] = _alarmSoundMode;
        final style = _aiWakeStyleController.text.trim();
        if (style.isNotEmpty) {
          updated.metadata['ai_wake_style'] = style;
        } else {
          updated.metadata.remove('ai_wake_style');
        }
        await _reminderService.updateReminder(updated);
      }

      if (!mounted) return;
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      
      navigator.pop();
      widget.onSaved?.call();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.existingReminder == null
                ? 'Reminder created!'
                : 'Reminder updated!',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }
}
