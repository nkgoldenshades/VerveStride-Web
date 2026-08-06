import 'package:flutter/material.dart';
import 'package:vervestride/core/app_theme.dart';
import 'package:vervestride/services/firebase_ai_service.dart';
import 'package:vervestride/services/local_storage_service.dart';
import 'package:vervestride/services/tts_service.dart';
import 'package:vervestride/services/assistant_voice_profile.dart';
import 'package:vervestride/services/user_subscription_service.dart';
import 'package:vervestride/services/ai_floating_assistant_controller.dart';
import 'package:vervestride/services/unified_ai_chat_service.dart';
import 'package:vervestride/widgets/section_card.dart';
import 'package:vervestride/models/ai_language_config.dart';
import 'package:vervestride/models/conversation_thread.dart';
import 'package:vervestride/screens/settings/ai_language_selector_screen.dart';
import 'package:vervestride/screens/settings/ai_voice_selector_screen.dart';

class AISettingsScreen extends StatefulWidget {
  const AISettingsScreen({super.key});

  @override
  State<AISettingsScreen> createState() => _AISettingsScreenState();
}

class _AISettingsScreenState extends State<AISettingsScreen> {
  final _chatInputController = TextEditingController();

  bool _isLoading = false;
  bool _voiceEnabled = true;
  bool _photoAnalysisEnabled = true;
  bool _conversationalAIEnabled = true;
  bool _dataAnalyticsEnabled = true;
  bool _floatingAIEnabled = true;

  // TTS Voice selection
  List<Map<String, String>> _availableVoices = [];
  String? _selectedVoice;
  double _speechRate = 0.5;
  double _pitch = 1.0;
  bool _isLoadingVoices = false;

  /// calm | balanced | energetic — affects AI reply tone + default TTS speed/pitch
  String _assistantVoiceMode = AssistantVoiceMode.balanced;

  /// any | male | female — filters the voice list (best-effort per device)
  String _ttsVoiceGender = VoiceGenderFilter.any;

  /// Stream AI responses + speak TTS sentence-by-sentence (Settings → AI Voice)
  bool _streamingVoiceEnabled = false;

  /// Selected AI language configuration
  String _selectedLanguageId = AILanguageConfig.defaultLanguage.id;

  /// Unified chat service for shared conversation history
  final UnifiedAIChatService _chatService = UnifiedAIChatService.instance;
  List<Map<String, dynamic>> _chatHistory = [];
  List<Map<String, dynamic>> _savedMemories = [];
  
  /// Thread management (matching Floating AI)
  ConversationThread? _currentThread;
  List<ConversationThread> _threads = [];
  
  /// Search functionality
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadSettings();
    
    // Initialize unified chat service
    await _chatService.initialize();
    _chatService.addListener(_onChatUpdated);
    
    await _loadChatData();
    await _loadVoices();
  }

  @override
  void dispose() {
    _chatInputController.dispose();
    _searchController.dispose();
    _chatService.removeListener(_onChatUpdated);
    super.dispose();
  }

  /// Handle chat updates from unified service
  void _onChatUpdated() {
    if (mounted) {
      setState(() {
        _currentThread = _chatService.activeThread;
        _threads = _chatService.getAllThreads();
      });
      _loadChatData();
    }
  }

  Future<void> _loadVoices() async {
    setState(() => _isLoadingVoices = true);

    await TTSService.instance.initialize();

    final voices = TTSService.instance.availableVoices;
    final selected = TTSService.instance.selectedVoice;

    if (!mounted) return;

    final voicesList = voices.toList();
    final filtered =
        VoiceGenderFilter.filter(voicesList, _ttsVoiceGender);

    String? pick = selected;

    // If the saved voice does not match the selected gender filter,
    // choose a best-effort match from available voices.
    if (_ttsVoiceGender != VoiceGenderFilter.any &&
        pick != null &&
        filtered.isNotEmpty &&
        !filtered.any((v) => v['name'] == pick)) {
      pick = null;
    }

    if (pick == null) {
      if (filtered.isNotEmpty) {
        pick = filtered.first['name'];
      } else if (_ttsVoiceGender == VoiceGenderFilter.male ||
          _ttsVoiceGender == VoiceGenderFilter.female) {
        final wantFemale = _ttsVoiceGender == VoiceGenderFilter.female;
        for (final v in voicesList) {
          final g = VoiceGenderFilter.inferGender(
            v['name'] ?? '',
            v['locale'] ?? '',
          );
          if (wantFemale ? g == true : g == false) {
            pick = v['name'];
            break;
          }
        }
      }
    }

    pick ??= voicesList.isNotEmpty ? voicesList.first['name'] : null;

    setState(() {
      _availableVoices = voicesList;
      _speechRate = TTSService.instance.speechRate;
      _pitch = TTSService.instance.pitch;
      _selectedVoice = pick;
      _isLoadingVoices = false;
    });

    if (pick != null) {
      await TTSService.instance.saveSelectedVoice(pick);
    }
  }

  List<Map<String, String>> _voicesForCurrentGender() {
    final filtered =
        VoiceGenderFilter.filter(_availableVoices, _ttsVoiceGender);
    return filtered.isNotEmpty ? filtered : _availableVoices;
  }

  Future<void> _onAssistantModeChanged(String mode) async {
    if (!AssistantVoiceMode.all.contains(mode)) return;
    setState(() => _assistantVoiceMode = mode);
    await TTSService.instance.applyAssistantVoiceMode(mode);
    if (!mounted) return;
    setState(() {
      _speechRate = TTSService.instance.speechRate;
      _pitch = TTSService.instance.pitch;
    });
    final s = await LocalStorageService.instance.getAISettings();
    s['assistant_voice_mode'] = mode;
    await LocalStorageService.instance.saveAISettings(s);
  }

  Future<void> _onGenderChanged(String gender) async {
    if (!VoiceGenderFilter.all.contains(gender)) return;
    setState(() => _ttsVoiceGender = gender);

    final voicesList = _availableVoices;
    final filtered = VoiceGenderFilter.filter(voicesList, gender);

    String? pick = _selectedVoice;
    if (gender != VoiceGenderFilter.any && pick != null) {
      // Keep the current voice only if it matches the target gender
      // (best-effort inference).
      final current = voicesList.where((v) => v['name'] == pick).toList();
      final g = current.isNotEmpty
          ? VoiceGenderFilter.inferGender(
              current.first['name'] ?? '',
              current.first['locale'] ?? '',
            )
          : null;
      final wantFemale = gender == VoiceGenderFilter.female;
      final matchesTarget = wantFemale ? g == true : g == false;
      if (!matchesTarget) pick = null;
    }

    if (pick == null) {
      if (filtered.isNotEmpty) {
        pick = filtered.first['name'];
      } else if (gender == VoiceGenderFilter.male ||
          gender == VoiceGenderFilter.female) {
        final wantFemale = gender == VoiceGenderFilter.female;
        for (final v in voicesList) {
          final g = VoiceGenderFilter.inferGender(
            v['name'] ?? '',
            v['locale'] ?? '',
          );
          if (wantFemale ? g == true : g == false) {
            pick = v['name'];
            break;
          }
        }
      }
    }

    pick ??= voicesList.isNotEmpty ? voicesList.first['name'] : null;
    if (pick != null) {
      await TTSService.instance.saveSelectedVoice(pick);
    }
    if (!mounted) return;
    setState(() => _selectedVoice = pick);
    final s = await LocalStorageService.instance.getAISettings();
    s['tts_voice_gender'] = gender;
    await LocalStorageService.instance.saveAISettings(s);
  }

  Future<void> _onVoiceChanged(String? voiceName) async {
    if (voiceName == null || voiceName == _selectedVoice) return;
    
    await TTSService.instance.saveSelectedVoice(voiceName);
    
    if (!mounted) return;
    setState(() => _selectedVoice = voiceName);
    
    // Test the voice
    await TTSService.instance.testVoice('Hello! This is how I will sound.');
  }

  Future<void> _onSpeechRateChanged(double rate) async {
    await TTSService.instance.setSpeechRate(rate);
    if (!mounted) return;
    setState(() => _speechRate = rate);
  }

  Future<void> _onPitchChanged(double pitch) async {
    await TTSService.instance.setPitch(pitch);
    if (!mounted) return;
    setState(() => _pitch = pitch);
  }

  Future<void> _testVoice() async {
    await TTSService.instance.testVoice('');
  }

  Future<void> _loadSettings() async {
    debugPrint('📂 Loading AI settings...');
    final settings = await LocalStorageService.instance.getAISettings();
    debugPrint('📂 Raw settings loaded: $settings');
    
    setState(() {
      _voiceEnabled = (settings['voice_enabled'] as bool?) ?? true;
      _photoAnalysisEnabled = (settings['photo_analysis_enabled'] as bool?) ?? true;
      _conversationalAIEnabled = (settings['conversational_ai_enabled'] as bool?) ?? true;
      _dataAnalyticsEnabled = (settings['data_analytics_enabled'] as bool?) ?? true;
      _floatingAIEnabled = (settings['floating_ai_enabled'] as bool?) ?? true; // Default to TRUE
      _selectedLanguageId = (settings['selected_language'] as String?) ?? AILanguageConfig.defaultLanguage.id;
      _assistantVoiceMode =
          (settings['assistant_voice_mode'] as String?) ??
              AssistantVoiceMode.balanced;
      if (!AssistantVoiceMode.all.contains(_assistantVoiceMode)) {
        _assistantVoiceMode = AssistantVoiceMode.balanced;
      }
      _ttsVoiceGender =
          (settings['tts_voice_gender'] as String?) ?? VoiceGenderFilter.any;
      if (!VoiceGenderFilter.all.contains(_ttsVoiceGender)) {
        _ttsVoiceGender = VoiceGenderFilter.any;
      }
      _streamingVoiceEnabled =
          (settings['streaming_voice_enabled'] as bool?) ?? false;
    });
    
    debugPrint('📂 ✅ Settings loaded: voice=$_voiceEnabled, photo=$_photoAnalysisEnabled, conversational=$_conversationalAIEnabled, analytics=$_dataAnalyticsEnabled, floating=$_floatingAIEnabled');
  }

  Future<void> _loadChatData() async {
    // Load current thread and all threads from unified service
    _currentThread = _chatService.activeThread;
    _threads = _chatService.getAllThreads();
    
    // Load messages from current thread
    final messages = _chatService.getCurrentMessages();
    final memories = await LocalStorageService.instance.getAISavedMemories();
    
    if (!mounted) return;
    setState(() {
      _chatHistory = messages;
      _savedMemories = memories;
    });
  }
  
  /// Create new thread (matching Floating AI validation)
  Future<void> _createNewThread() async {
    try {
      debugPrint('🆕 AI Settings: _createNewThread() called');
      
      // Allow creating new thread anytime - no blocking
      // Users should have flexibility to start fresh conversations
      
      // Create new thread
      final newThread = await _chatService.createNewThread();
      if (mounted) {
        setState(() {
          _currentThread = newThread;
          _threads = _chatService.getAllThreads();
        });
        await _loadChatData();
      }
      debugPrint('✅ AI Settings: Created new thread: ${newThread.id}');
      
      // Show feedback to user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New conversation started'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('❌ AI Settings: Failed to create new thread: $e');
    }
  }
  
  /// Switch to a different thread
  Future<void> _switchThread(ConversationThread thread) async {
    try {
      await _chatService.switchToThread(thread.id);
      if (mounted) {
        setState(() {
          _currentThread = thread;
        });
        await _loadChatData();
      }
      debugPrint('🔄 AI Settings: Switched to thread: ${thread.title}');
    } catch (e) {
      debugPrint('❌ AI Settings: Failed to switch thread: $e');
    }
  }
  
  /// Delete a thread
  Future<void> _deleteThread(String threadId) async {
    try {
      await _chatService.deleteThread(threadId);
      if (mounted) {
        setState(() {
          _threads = _chatService.getAllThreads();
          if (_currentThread?.id == threadId) {
            _currentThread = _threads.isNotEmpty ? _threads.first : null;
          }
        });
        await _loadChatData();
      }
      debugPrint('🗑️ AI Settings: Deleted thread: $threadId');
    } catch (e) {
      debugPrint('❌ AI Settings: Failed to delete thread: $e');
    }
  }
  
  /// Confirm before deleting thread
  Future<void> _confirmDeleteThread(String threadId) async {
    final thread = _threads.firstWhere((t) => t.id == threadId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Conversation?'),
        content: Text(
          'Are you sure you want to delete "${thread.title}"?\n\nThis will permanently delete ${thread.messages.length} messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _deleteThread(threadId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conversation deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _sendChat() async {
    final text = _chatInputController.text.trim();
    if (text.isEmpty) return;

    // Don't set local _isChatLoading - use shared state from unified service
    _chatInputController.clear();
    
    // Force rebuild to show shared processing state
    setState(() {});

    try {
      // Use unified chat service instead of direct AI service
      await _chatService.sendMessage(text);

      if (!mounted) return;
      
      // Reload chat data to show the new messages
      await _loadChatData();
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chat failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _exportAIChatData() async {
    try {
      // Export from unified chat service
      final chatData = await _chatService.exportAllData();
      final memories = await LocalStorageService.instance.getAISavedMemories();
      
      final exportData = {
        ...chatData,
        'saved_memories': memories,
        'ai_settings': await LocalStorageService.instance.getAISettings(),
      };
      
      final filePath = await FirebaseAIService.instance.exportUserData(exportData);
      await FirebaseAIService.instance.shareExportedData(filePath);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Exported successfully!'),
          backgroundColor: AppColors.secondary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteAIChatData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Delete AI Chat Data?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This will remove your AI chat history and saved memories. This affects both the settings chat and floating AI assistant.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    
    // Clear from unified chat service
    await _chatService.clearAllHistory();
    await LocalStorageService.instance.saveAISavedMemories([]);
    
    if (!mounted) return;
    setState(() {
      _chatHistory = [];
      _savedMemories = [];
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    final settings = await LocalStorageService.instance.getAISettings();
    settings.addAll({
      'voice_enabled': _voiceEnabled,
      'photo_analysis_enabled': _photoAnalysisEnabled,
      'conversational_ai_enabled': _conversationalAIEnabled,
      'data_analytics_enabled': _dataAnalyticsEnabled,
      'floating_ai_enabled': _floatingAIEnabled,
      'selected_language': _selectedLanguageId,
      'assistant_voice_mode': _assistantVoiceMode,
      'tts_voice_gender': _ttsVoiceGender,
      'streaming_voice_enabled': _streamingVoiceEnabled,
      'last_updated': DateTime.now().toIso8601String(),
    });
    
    debugPrint('💾 Saving AI settings: voice_enabled=$_voiceEnabled, photo_analysis=$_photoAnalysisEnabled');
    await LocalStorageService.instance.saveAISettings(settings);
    debugPrint('✅ AI settings saved successfully');
    
    // Reset AI models to use new language
    FirebaseAIService.instance.resetModels();
    
    // Update the controller so FloatingAI shows/hides immediately
    AIFloatingAssistantController.enabled.value = _floatingAIEnabled;
    
    // If user enables floating AI, also unhide it (so it actually shows)
    if (_floatingAIEnabled) {
      AIFloatingAssistantController.hidden.value = false;
      await LocalStorageService.instance.setAIFloatingAssistantHidden(false);
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
      // Don't show popup for auto-save (too annoying)
      // Settings are saved automatically when toggles change
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserSubscriptionService.instance,
      builder: (context, _) {
        // AI features are available to everyone now (with limits for free users)
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('AI Settings'),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusCard(),
                const SizedBox(height: 24),
                _buildLanguageSection(),
                const SizedBox(height: 24),
                _buildFeaturesSection(),
                const SizedBox(height: 24),
                _buildAIToolsSection(),
                const SizedBox(height: 24),
                _buildVoiceSection(),
                const SizedBox(height: 24),
                _buildSaveButton(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusCard() {
    final sub = UserSubscriptionService.instance;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.2),
            AppColors.secondary.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 32,
            color: AppColors.secondary,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VerveStride AI Active',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sub.planKey != null
                      ? 'VerveStride AI · ${sub.tierLabel} plan'
                      : 'VerveStride AI · Free plan (10 AI meals/month)',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSection() {
    final selectedLanguage = AILanguageConfig.getById(_selectedLanguageId) ?? AILanguageConfig.defaultLanguage;
    
    return SectionCard(
      title: 'AI Language & Accent',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose how VerveStride AI speaks and responds. This affects both text responses and voice output.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          
          // Current selection display
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
                Text(
                  selectedLanguage.flag,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedLanguage.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedLanguage.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.check_circle,
                  color: AppColors.primary,
                  size: 24,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Change language button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final result = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AILanguageSelectorScreen(),
                  ),
                );
                
                // Reload settings if language was changed
                if (result != null || mounted) {
                  await _loadSettings();
                }
              },
              icon: const Icon(Icons.language),
              label: const Text('Change Language & Accent'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withOpacity(0.6)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection() {
    return SectionCard(
      title: 'AI Features',
      child: Column(
        children: [
          _buildFeatureToggle(
            'Floating AI Assistant',
            'Show floating AI button on all screens',
            Icons.assistant,
            _floatingAIEnabled,
            (v) {
              setState(() => _floatingAIEnabled = v);
              // Update controller immediately so it shows/hides without needing to save
              AIFloatingAssistantController.enabled.value = v;
              // If enabling, also unhide it
              if (v) {
                AIFloatingAssistantController.hidden.value = false;
                LocalStorageService.instance.setAIFloatingAssistantHidden(false);
              }
              _saveSettings(); // Auto-save when toggle changes
            },
          ),
          _buildFeatureToggle(
            'Voice Commands',
            'Always-on voice listening with wake word',
            Icons.mic,
            _voiceEnabled,
            (v) {
              setState(() => _voiceEnabled = v);
              _saveSettings(); // Auto-save when toggle changes
            },
          ),
          _buildFeatureToggle(
            'Photo Meal Analysis',
            'Analyze meals from camera or gallery',
            Icons.camera_alt,
            _photoAnalysisEnabled,
            (v) {
              setState(() => _photoAnalysisEnabled = v);
              _saveSettings(); // Auto-save when toggle changes
            },
          ),
          _buildFeatureToggle(
            'ML Analytics',
            'AI reads all app data for insights (uses more credits)',
            Icons.insights,
            _dataAnalyticsEnabled,
            (v) {
              setState(() => _dataAnalyticsEnabled = v);
              _saveSettings(); // Auto-save when toggle changes
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAIToolsSection() {
    return SectionCard(
      title: 'AI Creative Tools',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Generate images and videos using AI. Perfect for workout visualizations, meal ideas, and motivational content.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          
          // Image Generation
          _buildToolButton(
            icon: Icons.image,
            title: 'Image Generation',
            subtitle: '20 credits per image',
            description: 'Create workout diagrams, meal visuals, and motivational posters',
            onTap: () => Navigator.pushNamed(context, '/ai/image_generator'),
          ),
          
          const SizedBox(height: 12),
          
          // Video Generation
          _buildToolButton(
            icon: Icons.video_library,
            title: 'Video Generation',
            subtitle: '50 credits per video',
            description: 'Generate workout demonstrations and exercise videos',
            onTap: () => Navigator.pushNamed(context, '/ai/video_generator'),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceSection() {
    return SectionCard(
      title: 'AI Voice',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose how the assistant sounds and speaks. Premium AI voices provide natural, human-like speech quality.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          
          // Premium AI Voice Selection
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
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
                      Icons.record_voice_over,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Premium AI Voices',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Natural, human-like AI voices powered by ElevenLabs and Google Neural networks. Perfect for fitness coaching and motivation.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AIVoiceSelectorScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.voice_chat),
                    label: const Text('Choose AI Voice'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary.withOpacity(0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          const SizedBox(height: 14),
          // Stream voice toggle removed - not implemented yet
          const Text(
            'Assistant style',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: AssistantVoiceMode.calm,
                label: Text('Calm'),
                icon: Icon(Icons.spa_outlined, size: 18),
              ),
              ButtonSegment<String>(
                value: AssistantVoiceMode.balanced,
                label: Text('Balanced'),
                icon: Icon(Icons.balance, size: 18),
              ),
              ButtonSegment<String>(
                value: AssistantVoiceMode.energetic,
                label: Text('Energetic'),
                icon: Icon(Icons.bolt, size: 18),
              ),
            ],
            selected: {_assistantVoiceMode},
            onSelectionChanged: (Set<String> next) {
              if (next.isEmpty) return;
              _onAssistantModeChanged(next.first);
            },
          ),
          const SizedBox(height: 6),
          Text(
            'Calm = softer replies & slower TTS · Energetic = upbeat & faster',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Voice gender (filter)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: VoiceGenderFilter.any,
                label: Text('All'),
              ),
              ButtonSegment<String>(
                value: VoiceGenderFilter.male,
                label: Text('Male'),
              ),
              ButtonSegment<String>(
                value: VoiceGenderFilter.female,
                label: Text('Female'),
              ),
            ],
            selected: {_ttsVoiceGender},
            onSelectionChanged: (Set<String> next) {
              if (next.isEmpty) return;
              _onGenderChanged(next.first);
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Speaking voice',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          if (_isLoadingVoices)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_availableVoices.isEmpty)
            const Text(
              'No voices available on this device.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else if (_voicesForCurrentGender().isEmpty)
            const Text(
              'No voices matched this filter — try “All”.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedVoice != null &&
                          _voicesForCurrentGender()
                              .any((v) => v['name'] == _selectedVoice)
                      ? _selectedVoice
                      : _voicesForCurrentGender().first['name'],
                  isExpanded: true,
                  dropdownColor: AppColors.card,
                  style: const TextStyle(color: AppColors.textPrimary),
                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                  items: _voicesForCurrentGender().map((voice) {
                    return DropdownMenuItem<String>(
                      value: voice['name'],
                      child: Text(
                        '${voice['name']} (${voice['locale']})',
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                    );
                  }).toList(),
                  onChanged: _onVoiceChanged,
                ),
              ),
            ),
          const SizedBox(height: 20),
          
          // Speech Rate Slider
          Row(
            children: [
              const Icon(Icons.speed, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              const Text(
                'Speed',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              Expanded(
                child: Slider(
                  value: _speechRate,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  label: _speechRate.toStringAsFixed(1),
                  activeColor: AppColors.primary,
                  onChanged: (v) => _onSpeechRateChanged(v),
                ),
              ),
              Text(
                '${(_speechRate * 100).toInt()}%',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          
          // Pitch Slider
          Row(
            children: [
              const Icon(Icons.music_note, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              const Text(
                'Pitch',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              Expanded(
                child: Slider(
                  value: _pitch,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  label: _pitch.toStringAsFixed(1),
                  activeColor: AppColors.secondary,
                  onChanged: (v) => _onPitchChanged(v),
                ),
              ),
              Text(
                '${_pitch.toStringAsFixed(1)}x',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Test Voice Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoadingVoices ? null : _testVoice,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Test Voice'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withOpacity(0.6)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatSection() {
    // Filter threads based on search query
    final filteredThreads = _searchQuery.isEmpty
        ? _threads
        : _threads.where((thread) {
            final titleMatch = thread.title.toLowerCase().contains(_searchQuery.toLowerCase());
            final messageMatch = thread.messages.any((msg) => 
              msg.content.toLowerCase().contains(_searchQuery.toLowerCase())
            );
            return titleMatch || messageMatch;
          }).toList();
    
    return SectionCard(
      title: 'AI Chat',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chat history and saved facts are stored locally on this device.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          
          // Search bar
          TextField(
            controller: _searchController,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search conversations...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      color: AppColors.textSecondary,
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),
          
          // Thread selector and New Chat button
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _currentThread?.id,
                      isExpanded: true,
                      dropdownColor: AppColors.card,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                      hint: const Text(
                        'Select conversation',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                      items: filteredThreads.map((thread) {
                        return DropdownMenuItem<String>(
                          value: thread.id,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  thread.title,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              Text(
                                ' (${thread.messages.length})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (threadId) {
                        if (threadId != null) {
                          final thread = _threads.firstWhere((t) => t.id == threadId);
                          _switchThread(thread);
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Delete current thread button
              if (_currentThread != null && _threads.length > 1)
                IconButton(
                  onPressed: () => _confirmDeleteThread(_currentThread!.id),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.red.withOpacity(0.8),
                  tooltip: 'Delete conversation',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _createNewThread,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Chat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Show search results count
          if (_searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Found ${filteredThreads.length} conversation${filteredThreads.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          
          if (_chatHistory.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Text(
                _currentThread == null 
                    ? 'No conversations yet. Click "New Chat" to start!'
                    : _searchQuery.isNotEmpty
                        ? 'No messages match your search.'
                        : 'Start chatting by sending a message below.',
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 340),
              decoration: BoxDecoration(
                color: AppColors.card.withOpacity(0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _chatHistory.length,
                itemBuilder: (context, index) {
                  final m = _chatHistory[index];
                  final role = (m['role'] ?? '').toString();
                  final content = (m['content'] ?? '').toString();
                  final isUser = role == 'user';
                  final bubbleColor = isUser
                      ? AppColors.primary.withOpacity(0.18)
                      : AppColors.secondary.withOpacity(0.12);

                  final memoryUsed = m['memory_used'];
                  final hasMemoryPanel = !isUser && memoryUsed is Map;

                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(maxWidth: 520),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            content,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              height: 1.35,
                            ),
                          ),
                          if (hasMemoryPanel) ...[
                            const SizedBox(height: 10),
                            Theme(
                              data: Theme.of(context).copyWith(
                                dividerColor: Colors.transparent,
                              ),
                              child: ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                childrenPadding: const EdgeInsets.only(top: 6),
                                title: const Text(
                                  'Memory used',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                children: [
                                  _buildMemoryRow(
                                    'Chat context sent',
                                    '${memoryUsed['context_messages_sent'] ?? 0} messages',
                                  ),
                                  _buildMemoryRow(
                                    'Saved facts sent',
                                    '${memoryUsed['saved_memories_sent'] ?? 0} items',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatInputController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Ask VerveStride AI…',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      filled: true,
                      fillColor: AppColors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _chatService.isProcessing ? null : _sendChat(),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  width: 48,
                  child: ElevatedButton(
                    onPressed: _chatService.isProcessing ? null : _sendChat,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _chatService.isProcessing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
          if (_chatHistory.isNotEmpty || _savedMemories.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exportAIChatData,
                    icon: const Icon(Icons.download),
                    label: const Text('Export'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary.withOpacity(0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _deleteAIChatData,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.withOpacity(0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'Save Settings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildFeatureToggle(
    String title,
    String description,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildMemoryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
