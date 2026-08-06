import 'package:flutter/material.dart';
import 'package:vervestride/core/app_theme.dart';
import 'package:vervestride/services/firebase_ai_service.dart';
import 'package:vervestride/widgets/ai_helper.dart';
import 'package:vervestride/widgets/section_card.dart';

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen> {
  bool _isListening = false;
  bool _isProcessing = false;
  String _lastCommand = '';
  String _aiResponse = '';
  final List<VoiceCommand> _commandHistory = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Voice Assistant'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            AIHelper.buildAIStatusBanner(
              context: context,
              message: 'Add an API key to enable voice commands and AI responses.',
            ),
            
            const SizedBox(height: 24),
            
            // Voice Control Section
            SectionCard(
              title: 'Voice Control',
              child: Column(
                children: [
                  // Microphone Button (AI-gated)
                  FutureBuilder<bool>(
                    future: FirebaseAIService.instance.isFeatureEnabled('voice_commands'),
                    builder: (context, snapshot) {
                      final voiceEnabled = snapshot.data ?? false;
                      final canInteract = voiceEnabled && !_isProcessing;

                      return Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: (canInteract && _isListening)
                                ? [AppColors.primary, AppColors.secondary]
                                : [Colors.grey.shade700, Colors.grey.shade600],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (canInteract && _isListening)
                                  ? AppColors.primary.withOpacity(0.3)
                                  : Colors.black.withOpacity(0.2),
                              blurRadius: (canInteract && _isListening) ? 20 : 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(60),
                            onTap: !canInteract
                                ? () async {
                                    if (!voiceEnabled) {
                                      if (mounted) {
                                        await AIHelper.showAIRequiredDialog(
                                          context: context,
                                          feature: 'voice_commands',
                                          message:
                                              'Add an API key to enable voice commands.',
                                        );
                                      }
                                    }
                                  }
                                : (_isListening ? _stopListening : _startListening),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  !voiceEnabled
                                      ? Icons.lock_outline
                                      : (_isListening ? Icons.mic : Icons.mic_none),
                                  size: 40,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  !voiceEnabled
                                      ? 'AI Required'
                                      : (_isListening ? 'Listening...' : 'Tap to Speak'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Processing Indicator
                  if (_isProcessing)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 3,
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'Processing command...',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Last Command Display
                  if (_lastCommand.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'You said:',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _lastCommand,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // AI Response Display (PERSISTENT - DOESN'T AUTO-CLOSE)
                  if (_aiResponse.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.secondary.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.smart_toy,
                                    size: 16,
                                    color: AppColors.secondary,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'VerveStride AI:',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              // Clear button to manually dismiss
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                color: AppColors.textSecondary,
                                onPressed: () {
                                  setState(() {
                                    _aiResponse = '';
                                    _lastCommand = '';
                                  });
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _aiResponse,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Command History Section
            if (_commandHistory.isNotEmpty) ...[
              SectionCard(
                title: 'Command History',
                child: Column(
                  children: _commandHistory.reversed.take(5).map((command) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.card.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _getActionIcon(command.action),
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  command.action.toUpperCase(),
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                _formatTime(DateTime.now()),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          if (command.response.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              command.response,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Available Commands Section
            SectionCard(
              title: 'Available Commands',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCommandItem('Start Workout', 'Start running, cycling, gym, etc.'),
                  _buildCommandItem('Log Meal', 'Log what you ate with calories'),
                  _buildCommandItem('Log Water', 'Record water intake'),
                  _buildCommandItem('Show Progress', 'View your fitness progress'),
                  _buildCommandItem('Export Data', 'Export all your data'),
                  _buildCommandItem('Delete Data', 'Delete all user data'),
                  _buildCommandItem('Chat', 'General conversation with AI'),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Data Management Section
            SectionCard(
              title: 'Data Management',
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.download, color: AppColors.primary),
                    title: const Text(
                      'Export All Data',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    subtitle: const Text(
                      'Download your complete data as JSON',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    onTap: _exportData,
                  ),
                  const Divider(height: 1, color: Colors.white12),
                  ListTile(
                    leading: Icon(Icons.delete_forever, color: Colors.red),
                    title: const Text(
                      'Delete All Data',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    subtitle: const Text(
                      'Permanently delete all user data',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    onTap: _deleteData,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandItem(String command, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  command,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'start_workout':
        return Icons.fitness_center;
      case 'log_meal':
        return Icons.restaurant;
      case 'log_water':
        return Icons.water_drop;
      case 'show_progress':
        return Icons.trending_up;
      case 'export_data':
        return Icons.download;
      case 'delete_data':
        return Icons.delete_forever;
      case 'chat':
        return Icons.chat;
      default:
        return Icons.help;
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _startListening() async {
    if (!await FirebaseAIService.instance.isFeatureEnabled('voice_commands')) {
      if (mounted) {
        await AIHelper.showAIRequiredDialog(
          context: context,
          feature: 'voice_commands',
          message: 'Add an API key to enable voice commands.',
        );
      }
      return;
    }

    setState(() {
      _isListening = true;
      // DON'T clear previous response - keep it visible
    });

    // Integrate with a speech-to-text package (e.g. speech_to_text) to capture real voice input.
    // For now, simulate voice input
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      final simulatedCommand = 'start workout running'; // Simulated input
      _processCommand(simulatedCommand);
    }
  }

  Future<void> _stopListening() async {
    setState(() {
      _isListening = false;
    });
  }

  Future<void> _processCommand(String command) async {
    setState(() {
      _isListening = false;
      _isProcessing = true;
      _lastCommand = command;
    });

    try {
      final voiceCommand = await FirebaseAIService.instance.processVoiceCommand(command);
      
      if (voiceCommand != null) {
        setState(() {
          _aiResponse = voiceCommand.response;
          _commandHistory.add(voiceCommand);
        });
        
        // Scroll to show the response
        _scrollToBottom();
        
        // Execute the command
        await _executeCommand(voiceCommand);
        
        // Speak response
        await FirebaseAIService.instance.speakResponse(voiceCommand.response);
      } else {
        setState(() {
          _aiResponse = 'Sorry, I couldn\'t understand that command. Please try again.';
        });
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        _aiResponse = 'Error processing command: $e';
      });
      _scrollToBottom();
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _executeCommand(VoiceCommand command) async {
    switch (command.action) {
      case 'start_workout':
        // Navigate to workout screen when routing is wired up.
        debugPrint('Starting workout: ${command.parameters['workout_type']}');
        break;
      case 'log_meal':
        // Navigate to meals screen with pre-filled data when routing is wired up.
        debugPrint('Logging meal: ${command.parameters['meal_name']}');
        break;
      case 'log_water':
        // Log water intake when hydration logging is wired up.
        debugPrint('Logging water: ${command.parameters['water_ml']}ml');
        break;
      case 'show_progress':
        // Navigate to progress screen when routing is wired up.
        debugPrint('Showing progress for: ${command.parameters['time_range']}');
        break;
      case 'export_data':
        await _exportData();
        break;
      case 'delete_data':
        await _deleteData();
        break;
      case 'chat':
        // Already handled by response
        break;
    }
  }

  Future<void> _exportData() async {
    try {
      final filePath = await FirebaseAIService.instance.exportAllUserData();
      await FirebaseAIService.instance.shareExportedData(filePath);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Data exported successfully!'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Delete All Data?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This will permanently delete all your data including meals, workouts, settings, and AI configurations. This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseAIService.instance.deleteAllUserData();
        
        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);
          
          messenger.showSnackBar(
            const SnackBar(
              content: Text('All data deleted successfully'),
              backgroundColor: Colors.red,
            ),
          );
          navigator.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delete failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
