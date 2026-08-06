import 'dart:math' as math;
import 'dart:async';
import 'dart:convert' show base64Encode;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:vervestride/core/app_theme.dart';
import 'package:vervestride/core/routes.dart';
import 'package:vervestride/main.dart' show appNavigatorKey;
import 'package:vervestride/services/firebase_ai_service.dart';
import 'package:vervestride/services/ai_floating_assistant_controller.dart';
import 'package:vervestride/services/local_storage_service.dart';
import 'package:vervestride/services/user_subscription_service.dart';
import 'package:vervestride/services/credits_service.dart';
import 'package:vervestride/services/unified_ai_chat_service.dart';
import 'package:vervestride/widgets/ai_message_content.dart';
import 'package:vervestride/services/storage_tracking_service.dart';
import 'package:vervestride/services/ai_persona_service.dart';
import 'package:vervestride/models/conversation_thread.dart';
import 'package:vervestride/models/ai_model_config.dart';
import 'package:vervestride/models/ai_feature_costs.dart';

enum _ResizeEdge {
  topLeft,
  top,
  topRight,
  left,
  right,
  bottomLeft,
  bottom,
  bottomRight,
}

/// Floating AI Assistant - Available anywhere in the app
///
/// Features:
/// - Floating button that follows you everywhere
/// - Voice input with visual feedback
/// - Quick chat interface
/// - Works during workouts
class FloatingAIAssistant extends StatefulWidget {
  const FloatingAIAssistant({super.key});

  @override
  State<FloatingAIAssistant> createState() => _FloatingAIAssistantState();
}

class _FloatingAIAssistantState extends State<FloatingAIAssistant>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isExpanded = false;
  bool _isFullMode = false;
  bool _isListening = false;
  bool _isProcessing = false; // Local processing state
  bool _continuousVoice = false;
  DateTime? _processingStartTime;
  Timer? _continuousVoiceWatchdog;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late stt.SpeechToText _speech;
  bool _speechAvailable = false;
  String _speechError = '';
  bool _voiceEnabled = true;
  bool _photoAnalysisEnabled = true;

  // Memory mode toggles
  bool _threadMemoryEnabled = true; // Use thread-specific memory
  bool _chatMemoryEnabled = true; // Use cross-thread chat memory

  // Unified chat service
  final UnifiedAIChatService _chatService = UnifiedAIChatService.instance;
  ConversationThread? _currentThread;
  List<ConversationThread> _threads = []; // Local threads list for UI
  bool _showSidebar = false;
  bool _showModelPicker = false;
  bool _webSearchEnabled = false; // toggle: use Google Search grounding
  String? _activeModelId;

  // Image and file attachments
  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _pickedImageBytes;
  final List<PlatformFile> _attachedFiles = []; // Multiple file support

  // Scroll controller for chat messages
  final ScrollController _scrollController = ScrollController();

  // Draggable position (main FAB)
  double _xPosition = -1; // -1 = not yet positioned
  double _yPosition = -1;
  // Draggable position ("Show AI" chip when assistant is hidden)
  double _showAiX = 0;
  double _showAiY = 0;
  static const double _kShowAiChipW = 124;
  static const double _kShowAiChipH = 44;
  bool _isHidden = false;
  bool _hiddenLoaded = false;

  void _onControllerHiddenChanged() {
    final hidden = AIFloatingAssistantController.hidden.value;
    if (hidden == _isHidden) return;
    if (!mounted) return;
    if (hidden) _textFocusNode.unfocus();
    setState(() {
      _isHidden = hidden;
      _hiddenLoaded = true;
      if (hidden) _isExpanded = false;
      if (hidden) _continuousVoice = false;
      if (hidden) _panelLayoutInitialized = false;
      if (hidden) _showModelPicker = false;
    });
  }

  /// Floating AI panel (free-form window)
  double _panelLeft = 16;
  double _panelTop = 120;
  double _panelWidth = 320;
  double _panelHeight = 380;
  bool _panelLayoutInitialized = false;
  bool _panelMinimized = false;

  static const double _kPanelMinW = 220;
  static const double _kPanelMinH = 180;
  static const double _kPanelHandle = 18;
  static const double _kMiniPanelH = 52;
  static const double _kPanelBottomReserve = 108;

  bool _hasActiveAIAccess() {
    // AI is now available to everyone!
    // Free users have limits, Pro/Elite have more/unlimited
    return true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    // DON'T initialize speech here - lazy init when user taps mic to avoid startup sound
    // _initSpeech();

    AIFloatingAssistantController.hidden
        .addListener(_onControllerHiddenChanged);

    _loadHiddenState();
    _loadVoiceEnabled();
    _loadSavedPosition();

    // Load credits and unified chat service (force reload to show actual balance)
    CreditsService.instance.load(force: true);
    StorageTrackingService.instance.load();

    // Initialize unified chat service
    _chatService.initialize().then((_) {
      _chatService.addListener(_onChatUpdated);
      _loadCurrentThread();
    });

    _loadActiveModel();
    _loadMemorySettings();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reload settings when app resumes (in case they changed in Settings)
      _loadVoiceEnabled();
    }
  }

  Future<void> _loadSavedPosition() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final size = MediaQuery.sizeOf(context);
      final w = size.width;
      final h = size.height;

      // Set safe default immediately so button is visible right away
      double x = w - 76;
      double y = h - 160;
      double showX = w - _kShowAiChipW - 16;
      double showY = h - 120 - _kShowAiChipH;

      // Then try to load saved position
      try {
        final saved =
            await LocalStorageService.instance.getAIFloatingPosition();
        if (saved != null && mounted) {
          x = saved['x']!.clamp(0.0, w - 60);
          y = saved['y']!.clamp(0.0, h - 60);
        }
      } catch (_) {}

      if (!mounted) return;

      debugPrint('🤖 FloatingAI position set: x=$x, y=$y (screen: ${w}x$h)');

      setState(() {
        _xPosition = x;
        _yPosition = y;
        _showAiX = showX;
        _showAiY = showY;
      });
    });
  }

  Future<void> _loadHiddenState() async {
    try {
      final hidden =
          await LocalStorageService.instance.getAIFloatingAssistantHidden();
      debugPrint('🤖 FloatingAI loaded hidden state: $hidden');
      if (!mounted) return;
      setState(() {
        if (!_hiddenLoaded) {
          _isHidden = hidden;
        }
        _hiddenLoaded = true;
      });

      // Keep controller in sync so Settings toggles update immediately.
      if (AIFloatingAssistantController.hidden.value != hidden) {
        AIFloatingAssistantController.hidden.value = hidden;
      }
    } catch (e) {
      debugPrint('🤖 FloatingAI error loading hidden state: $e');
      if (!mounted) return;
      setState(() => _hiddenLoaded = true);
    }
  }

  Future<void> _setHidden(bool hidden) async {
    if (!mounted) return;
    if (hidden) _textFocusNode.unfocus();
    setState(() {
      _isHidden = hidden;
      _hiddenLoaded = true;
      if (hidden) _isExpanded = false;
      if (hidden) _panelLayoutInitialized = false;
      if (hidden) _showModelPicker = false;
    });

    if (AIFloatingAssistantController.hidden.value != hidden) {
      AIFloatingAssistantController.hidden.value = hidden;
    }

    try {
      await LocalStorageService.instance.setAIFloatingAssistantHidden(hidden);
    } catch (_) {}
  }

  Future<void> _loadVoiceEnabled() async {
    try {
      final settings = await LocalStorageService.instance.getAISettings();
      final enabled = (settings['voice_enabled'] as bool?) ?? true;
      final photo = (settings['photo_analysis_enabled'] as bool?) ?? true;
      debugPrint(
          '🔊 Loaded voice settings: voice_enabled=$enabled, photo_analysis=$photo');
      debugPrint('🔊 Full settings map: $settings');
      if (!mounted) return;
      setState(() {
        _voiceEnabled = enabled;
        _photoAnalysisEnabled = photo;
      });
      debugPrint(
          '🔊 State updated: _voiceEnabled=$_voiceEnabled, _photoAnalysisEnabled=$_photoAnalysisEnabled');
    } catch (e) {
      debugPrint('❌ Error loading voice settings: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final x = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (x == null || !mounted) return;
      final bytes = await x.readAsBytes();
      setState(() => _pickedImageBytes = bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(appNavigatorKey.currentContext ?? context)
            .showSnackBar(
          SnackBar(
            content: Text('Could not pick image: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  /// Pick files (PDFs, documents, etc.) - like Gemini
  /// Supports: Documents, Images, Videos, Audio, Archives, Code files
  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true, // Upload as many as you want!
        type: FileType.any, // Accept ANY file type
        withData: kIsWeb, // Load file data on web
        // No size limit - let the AI API handle it
      );

      if (result != null && mounted) {
        setState(() {
          _attachedFiles.addAll(result.files);
        });

        debugPrint('📎 Uploaded ${result.files.length} files');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(appNavigatorKey.currentContext ?? context)
            .showSnackBar(
          SnackBar(
            content: Text('Could not pick files: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  /// Remove a file from attachments
  void _removeFile(int index) {
    setState(() {
      _attachedFiles.removeAt(index);
    });
  }

  bool _showAttachMenu = false; // Toggle for inline menu

  void _toggleAttachMenu() {
    setState(() {
      _showAttachMenu = !_showAttachMenu;
      debugPrint('📎 Attach menu toggled: $_showAttachMenu');
    });
  }

  Widget _buildInlineMenuOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  void _promptImageGeneration() {
    // Pre-fill the text field with a prompt starter
    setState(() {
      _textController.text = 'Create an image of ';
    });
    // Focus the text field
    _textFocusNode.requestFocus();
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: _textController.text.length),
    );
  }

  /// Image attachment preview - compact, below input like Gemini
  Widget _buildImageAttachmentPreview() {
    if (_pickedImageBytes == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Small thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.memory(
              _pickedImageBytes!,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          // Compact text
          const Text(
            'Image',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          // Remove button
          GestureDetector(
            onTap: () => setState(() => _pickedImageBytes = null),
            child: Icon(
              Icons.close,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// File attachments preview - compact horizontal chips like Gemini
  Widget _buildFileAttachmentsPreview() {
    if (_attachedFiles.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      height: 40, // Compact height
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _attachedFiles.length,
        itemBuilder: (context, index) {
          final file = _attachedFiles[index];
          final ext = file.extension?.toUpperCase() ?? 'FILE';
          final isImage =
              ['JPG', 'JPEG', 'PNG', 'GIF', 'WEBP', 'BMP'].contains(ext);

          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A3A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Show image thumbnail if it's an image file, otherwise show icon
                if (isImage && file.bytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.memory(
                      file.bytes!,
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Icon(
                    _getFileIcon(ext),
                    size: 16,
                    color: _getFileColor(ext),
                  ),
                const SizedBox(width: 6),
                // File name (shorter)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 80),
                  child: Text(
                    file.name,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                // Remove button
                GestureDetector(
                  onTap: () => _removeFile(index),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _getFileIcon(String ext) {
    switch (ext.toUpperCase()) {
      // Documents
      case 'PDF':
        return Icons.picture_as_pdf;
      case 'DOC':
      case 'DOCX':
        return Icons.description;
      case 'TXT':
      case 'MD':
        return Icons.text_snippet;

      // Spreadsheets
      case 'CSV':
      case 'XLS':
      case 'XLSX':
        return Icons.table_chart;

      // Presentations
      case 'PPT':
      case 'PPTX':
        return Icons.slideshow;

      // Images
      case 'JPG':
      case 'JPEG':
      case 'PNG':
      case 'GIF':
      case 'SVG':
      case 'WEBP':
        return Icons.image;

      // Videos
      case 'MP4':
      case 'MOV':
      case 'AVI':
      case 'MKV':
      case 'WEBM':
        return Icons.videocam;

      // Audio
      case 'MP3':
      case 'WAV':
      case 'M4A':
      case 'OGG':
      case 'FLAC':
        return Icons.music_note;

      // Code
      case 'JS':
      case 'TS':
      case 'PY':
      case 'JAVA':
      case 'CPP':
      case 'C':
      case 'HTML':
      case 'CSS':
      case 'JSON':
      case 'XML':
      case 'DART':
        return Icons.code;

      // Archives
      case 'ZIP':
      case 'RAR':
      case '7Z':
      case 'TAR':
      case 'GZ':
        return Icons.folder_zip;

      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String ext) {
    switch (ext.toUpperCase()) {
      // Documents
      case 'PDF':
        return Colors.redAccent;
      case 'DOC':
      case 'DOCX':
        return Colors.blueAccent;
      case 'TXT':
      case 'MD':
        return Colors.grey;

      // Spreadsheets
      case 'CSV':
      case 'XLS':
      case 'XLSX':
        return Colors.greenAccent;

      // Presentations
      case 'PPT':
      case 'PPTX':
        return Colors.orangeAccent;

      // Images
      case 'JPG':
      case 'JPEG':
      case 'PNG':
      case 'GIF':
      case 'SVG':
      case 'WEBP':
        return Colors.purple;

      // Videos
      case 'MP4':
      case 'MOV':
      case 'AVI':
      case 'MKV':
      case 'WEBM':
        return Colors.pinkAccent;

      // Audio
      case 'MP3':
      case 'WAV':
      case 'M4A':
      case 'OGG':
      case 'FLAC':
        return Colors.cyan;

      // Code
      case 'JS':
      case 'TS':
      case 'PY':
      case 'JAVA':
      case 'CPP':
      case 'C':
      case 'HTML':
      case 'CSS':
      case 'JSON':
      case 'XML':
      case 'DART':
        return Colors.amber;

      // Archives
      case 'ZIP':
      case 'RAR':
      case '7Z':
      case 'TAR':
      case 'GZ':
        return Colors.brown;

      default:
        return AppColors.primary;
    }
  }

  Future<void> _initSpeech() async {
    _speech = stt.SpeechToText();
    try {
      _speechAvailable = await _speech.initialize(
        onError: (error) {
          final msg = error.errorMsg.toLowerCase();
          debugPrint('Speech error: ${error.errorMsg}');

          // "not-allowed" = mic permission denied or HTTP (not HTTPS)
          // Silently disable voice — don't spam the user
          if (msg.contains('not-allowed') || msg.contains('not_allowed')) {
            if (mounted) {
              setState(() {
                _speechAvailable = false;
                _speechError = 'not-allowed';
                _isListening = false;
                _continuousVoice = false; // Turn off for permission errors
              });
            }
            return; // Don't restart wake word on permission denial
          }

          if (mounted) {
            setState(() {
              _speechError = error.errorMsg;
              _isListening = false;
              // Don't turn off _continuousVoice for non-permission errors
            });
          }
        },
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
      );
      if (_speechAvailable) {
        debugPrint('✓ Speech recognition initialized');
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      debugPrint('Speech init error: $e');
      _speechAvailable = false;
      // Silently handle permission errors
      _speechError = msg.contains('not-allowed') || msg.contains('not_allowed')
          ? 'not-allowed'
          : 'Failed to initialize: $e';
    }
  }

  @override
  void dispose() {
    // Unfocus BEFORE disposing to prevent editable_text.dart assertion
    _textFocusNode.unfocus();
    WidgetsBinding.instance.removeObserver(this);
    AIFloatingAssistantController.hidden
        .removeListener(_onControllerHiddenChanged);
    _chatService.removeListener(_onChatUpdated);
    _continuousVoice = false;
    _stopContinuousVoiceWatchdog();
    _pulseController.dispose();
    _textController.dispose();
    _textFocusNode.dispose();
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
  }

  /// Handle chat updates from unified service
  void _onChatUpdated() {
    if (mounted) {
      setState(() {
        _currentThread = _chatService.activeThread;
        _threads = _chatService.getAllThreads();
        // Sync processing state from unified service
        _isProcessing = _chatService.isProcessing;
      });
    }
  }

  /// Load current thread from unified service
  Future<void> _loadCurrentThread() async {
    try {
      // Get active thread and all threads from service
      final thread = _chatService.activeThread;
      final allThreads = _chatService.getAllThreads();

      // If no threads exist at all, create the first one automatically
      if (allThreads.isEmpty) {
        debugPrint('📝 No threads found - creating first thread automatically');
        final firstThread = await _chatService.createNewThread();
        if (mounted) {
          setState(() {
            _currentThread = firstThread;
            _threads = _chatService.getAllThreads();
          });
        }
        return;
      }

      // Threads exist - load them
      if (mounted) {
        setState(() {
          _currentThread = thread;
          _threads = allThreads;
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to load current thread: $e');
    }
  }

  // Thread management methods
  void _createNewThread() async {
    try {
      debugPrint('🆕 _createNewThread() called');

      // Check if current thread is empty - don't create if it is
      if (_currentThread != null && _currentThread!.messages.isEmpty) {
        debugPrint('⚠️ Current thread is empty - not creating new thread');
        ScaffoldMessenger.of(appNavigatorKey.currentContext ?? context)
            .showSnackBar(
          const SnackBar(
            content:
                Text('Current conversation is empty. Start chatting first!'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Create new thread
      debugPrint('✅ Creating new thread...');
      final newThread = await _chatService.createNewThread();
      if (mounted) {
        setState(() {
          _currentThread = newThread;
          _threads = _chatService.getAllThreads();
        });
      }
      debugPrint('✅ Created new thread: ${newThread.id}');

      // Show feedback to user
      ScaffoldMessenger.of(appNavigatorKey.currentContext ?? context)
          .showSnackBar(
        const SnackBar(
          content: Text('New conversation started'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('❌ Failed to create new thread: $e');
    }
  }

  void _switchThread(ConversationThread thread) async {
    try {
      await _chatService.switchToThread(thread.id);
      if (mounted) {
        setState(() {
          _currentThread = thread;
        });
      }
      debugPrint(
          '🔄 Switched to thread: ${thread.title} (${thread.messages.length} messages)');
    } catch (e) {
      debugPrint('❌ Failed to switch thread: $e');
    }
  }

  void _deleteThread(String threadId) async {
    try {
      await _chatService.deleteThread(threadId);
      if (mounted) {
        setState(() {
          _threads = _chatService.getAllThreads();
          if (_currentThread?.id == threadId) {
            _currentThread = _threads.isNotEmpty ? _threads.first : null;
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to delete thread: $e');
    }
  }

  /// Load active model ID into state cache
  Future<void> _loadActiveModel() async {
    try {
      final settings = await LocalStorageService.instance.getAISettings();
      final id = settings['selected_general_model'] as String? ??
          AIModelConfig.defaultGeneral.id;
      if (mounted) setState(() => _activeModelId = id);
    } catch (_) {
      if (mounted)
        setState(() => _activeModelId = AIModelConfig.defaultGeneral.id);
    }
  }

  /// Save selected model and update state immediately
  Future<void> _selectModel(AIModelConfig model) async {
    setState(() {
      _activeModelId = model.id;
      _showModelPicker = false;
    });
    final settings = await LocalStorageService.instance.getAISettings();
    settings['selected_general_model'] = model.id;
    if (model.supportsVision) settings['selected_vision_model'] = model.id;
    await LocalStorageService.instance.saveAISettings(settings);
    // Reset cached model instance so next message uses new model
    FirebaseAIService.instance.resetModels();
  }

  /// Returns the display name of the currently active model (from cache)
  String get _activeModelLabel {
    final config = AIModelConfig.getById(
      _activeModelId ?? AIModelConfig.defaultGeneral.id,
    );
    return config?.displayName ?? 'VerveStride AI Speed';
  }

  /// Get memory status text for display
  String _getMemoryStatusText() {
    if (_threadMemoryEnabled && _chatMemoryEnabled) {
      return 'Full Memory Active';
    } else if (_threadMemoryEnabled) {
      return 'Thread Memory Only';
    } else if (_chatMemoryEnabled) {
      return 'Cross-Chat Memory Only';
    } else {
      return 'No Memory (Fresh Start)';
    }
  }

  /// Get memory status icon for compact display
  String _getMemoryStatusIcon() {
    if (_threadMemoryEnabled && _chatMemoryEnabled) {
      return '🧠'; // Full memory
    } else if (_threadMemoryEnabled) {
      return '🧵'; // Thread only
    } else if (_chatMemoryEnabled) {
      return '💬'; // Chat only
    } else {
      return '🆕'; // No memory
    }
  }

  /// Get memory status color
  Color _getMemoryStatusColor() {
    if (_threadMemoryEnabled && _chatMemoryEnabled) {
      return const Color(0xFF42A5F5); // Blue for full memory
    } else if (_threadMemoryEnabled) {
      return AppColors.primary; // Primary for thread only
    } else if (_chatMemoryEnabled) {
      return const Color(0xFF66BB6A); // Green for chat only
    } else {
      return AppColors.textSecondary; // Gray for no memory
    }
  }

  /// Save memory settings to local storage
  Future<void> _saveMemorySettings() async {
    try {
      final settings = await LocalStorageService.instance.getAISettings();
      settings['thread_memory_enabled'] = _threadMemoryEnabled;
      settings['chat_memory_enabled'] = _chatMemoryEnabled;
      await LocalStorageService.instance.saveAISettings(settings);
    } catch (e) {
      debugPrint('⚠️ Failed to save memory settings: $e');
    }
  }

  /// Load memory settings from local storage
  Future<void> _loadMemorySettings() async {
    try {
      final settings = await LocalStorageService.instance.getAISettings();
      setState(() {
        _threadMemoryEnabled =
            settings['thread_memory_enabled'] as bool? ?? true;
        _chatMemoryEnabled = settings['chat_memory_enabled'] as bool? ?? true;
      });
    } catch (e) {
      debugPrint('⚠️ Failed to load memory settings: $e');
    }
  }

  /// Get recent messages from other threads for cross-thread memory
  Future<List<ChatMessage>> _getCrossThreadHistory() async {
    try {
      final crossThreadMessages = <ChatMessage>[];

      // Get recent messages from other threads (last 24 hours)
      final cutoffTime = DateTime.now().subtract(const Duration(hours: 24));
      final allThreads = _chatService.getAllThreads();

      for (final thread in allThreads) {
        if (thread.id == _currentThread?.id) continue; // Skip current thread

        final recentMessages = thread.messages
            .where((m) => m.timestamp.isAfter(cutoffTime))
            .toList();

        crossThreadMessages.addAll(recentMessages);
      }

      // Sort by timestamp and take most recent 10
      crossThreadMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return crossThreadMessages.length > 10
          ? crossThreadMessages.sublist(crossThreadMessages.length - 10)
          : crossThreadMessages;
    } catch (e) {
      debugPrint('⚠️ Failed to get cross-thread history: $e');
      return [];
    }
  }

  /// Show memory mode help dialog
  void _showMemoryHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Memory Controls'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.forum, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Thread Memory: Remembers this conversation',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.history, size: 16, color: Color(0xFF66BB6A)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Chat Memory: Remembers recent messages from all threads',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Status: ${_getMemoryStatusIcon()} ${_getMemoryStatusText()}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the icons in the header to toggle each mode.',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  /// Force reset processing state (for debugging stuck states)
  void _forceResetProcessing() {
    debugPrint(
        '🔄 Force reset processing called - current state: $_isProcessing');
    setState(() {
      _isProcessing = false;
      _isListening = false;
      _continuousVoice = false;
      _processingStartTime = null;
    });

    // Stop any ongoing speech recognition
    try {
      _speech.stop();
    } catch (e) {
      debugPrint('⚠️ Error stopping speech during force reset: $e');
    }

    debugPrint('🔄 Processing state force reset complete');
  }

  String _formatThreadTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }

  Widget _buildChatMessages() {
    final messages = _currentThread?.messages ?? [];
    final isEmpty = messages.isEmpty;

    // Empty state — clean text only
    if (isEmpty && !_isProcessing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _currentThread?.persona != null
                    ? AIPersonaService.personaLabel(_currentThread!.persona)
                    : 'VerveStride AI',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _currentThread?.persona != null
                    ? 'I\'m in ${AIPersonaService.personaLabel(_currentThread!.persona)} — say anything!'
                    : 'Just start talking — I\'ll adapt to you',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Build item list: messages + optional "thinking" indicator
    final isProcessing = _isProcessing;
    final itemCount = messages.length + (isProcessing ? 1 : 0);

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            // Thinking indicator — left-aligned like an AI message
            if (index == messages.length) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                        ),
                      ),
                      child: const Icon(Icons.smart_toy,
                          color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.card.withOpacity(0.6),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(16),
                        ),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: _ThinkingDots(),
                    ),
                  ],
                ),
              );
            }

            final message = messages[index];

            // System suggestion — web search enable banner
            if (message.role == 'system_suggestion') {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _webSearchEnabled = true),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4285F4).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF4285F4).withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.language,
                            size: 14, color: Color(0xFF4285F4)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            message.content,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4285F4),
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: const Color(0xFF4285F4),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Text('Enable',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final isUser = message.isUser;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Message bubble
                  Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        // User bubbles: max 75% of panel width
                        // AI bubbles: use full available width
                        maxWidth: isUser
                            ? MediaQuery.of(context).size.width * 0.65
                            : double.infinity,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUser
                              ? AppColors.primary.withOpacity(0.25)
                              : AppColors.card.withOpacity(0.6),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isUser ? 16 : 4),
                            bottomRight: Radius.circular(isUser ? 4 : 16),
                          ),
                          border: Border.all(
                            color: isUser
                                ? AppColors.primary.withOpacity(0.3)
                                : Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: AIMessageContent(
                          content: message.content,
                          isUser: isUser,
                          message:
                              message, // Pass full message for image/video/audio display
                        ),
                      ),
                    ),
                  ),
                  // Credit badge + copy button + elapsed time for AI messages
                  if (!isUser) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Copy button
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: message.content));
                            ScaffoldMessenger.of(
                                    appNavigatorKey.currentContext ?? context)
                                .showSnackBar(const SnackBar(
                              content: Text('Copied to clipboard'),
                              duration: Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.1)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.copy,
                                    size: 10, color: AppColors.textSecondary),
                                SizedBox(width: 3),
                                Text('Copy',
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                        // Elapsed time
                        if (message.elapsedLabel != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.08)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.timer_outlined,
                                    size: 9, color: AppColors.textSecondary),
                                const SizedBox(width: 3),
                                Text(
                                  message.elapsedLabel!,
                                  style: const TextStyle(
                                      fontSize: 9,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                        // Credit badge — always show precise usage
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (message.preciseCredits != null &&
                                    message.preciseCredits! > 0)
                                ? AppColors.primary.withOpacity(0.08)
                                : Colors.green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (message.preciseCredits != null &&
                                      message.preciseCredits! > 0)
                                  ? AppColors.primary.withOpacity(0.2)
                                  : Colors.green.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                (message.preciseCredits != null &&
                                        message.preciseCredits! > 0)
                                    ? '💎'
                                    : '✓',
                                style: const TextStyle(fontSize: 9),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                message.preciseCreditLabel,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: (message.preciseCredits != null &&
                                          message.preciseCredits! > 0)
                                      ? AppColors.textSecondary
                                      : Colors.green.shade300,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _openPanel() {
    debugPrint(
        '🔵 _openPanel() called - _isExpanded: $_isExpanded, _panelLayoutInitialized: $_panelLayoutInitialized');

    // Safely stop speech if available
    try {
      if (_speechAvailable) {
        _speech.stop();
        debugPrint('🔵 Speech stopped successfully');
      }
    } catch (e) {
      debugPrint('⚠️ Speech stop error (non-critical): $e');
    }

    final mq = MediaQuery.of(context);
    final sw = mq.size.width;
    final sh = mq.size.height - mq.viewInsets.bottom;
    final topSafe = mq.padding.top + 8;

    debugPrint('🔵 Screen size: ${sw}x$sh, topSafe: $topSafe');

    setState(() {
      debugPrint('🔵 Setting _isExpanded = true');
      _isExpanded = true;
      _panelMinimized = false;
      if (!_panelLayoutInitialized) {
        double left = 16;
        if (_xPosition < sw / 2) {
          left =
              (_xPosition + 70).clamp(16.0, sw - _kPanelMinW - 16.0).toDouble();
        }
        final width =
            (sw - left - 16.0).clamp(_kPanelMinW, sw - 32.0).toDouble();
        final height = math
            .min(400.0, sh - topSafe - _kPanelBottomReserve)
            .clamp(_kPanelMinH, sh - topSafe - _kPanelBottomReserve)
            .toDouble();
        final top = (sh - _kPanelBottomReserve - height)
            .clamp(topSafe, sh - _kPanelBottomReserve - _kPanelMinH)
            .toDouble();
        _panelLeft = left.toDouble();
        _panelTop = top;
        _panelWidth = width;
        _panelHeight = height;
        _panelLayoutInitialized = true;
        debugPrint(
            '🔵 Panel initialized - left: $left, top: $top, width: $width, height: $height');
      }
      debugPrint(
          '🔵 _openPanel() setState completed - _isExpanded: $_isExpanded');
    });
  }

  void _clampPanelRect() {
    final mq = MediaQuery.of(context);
    final sw = mq.size.width;
    final sh = mq.size.height - mq.viewInsets.bottom;
    final topSafe = mq.padding.top;
    final visH = _panelMinimized ? _kMiniPanelH : _panelHeight;
    final maxH = sh - topSafe - _kPanelBottomReserve;

    _panelLeft =
        _panelLeft.clamp(0.0, math.max(0.0, sw - _kPanelMinW)).toDouble();
    _panelWidth = _panelWidth.clamp(_kPanelMinW, sw - _panelLeft).toDouble();
    if (!_panelMinimized) {
      _panelHeight = _panelHeight
          .clamp(
            _kPanelMinH,
            math.max(_kPanelMinH, maxH),
          )
          .toDouble();
    }
    _panelTop = _panelTop
        .clamp(
          topSafe,
          math.max(topSafe, sh - _kPanelBottomReserve - visH),
        )
        .toDouble();
  }

  void _onPanelMove(DragUpdateDetails d) {
    if (_isFullMode) return;
    // Defer setState out of gesture processing to avoid hit-test coordinate mismatch
    final dx = d.delta.dx;
    final dy = d.delta.dy;
    Future.microtask(() {
      if (!mounted) return;
      setState(() {
        _panelLeft += dx;
        _panelTop += dy;
        _clampPanelRect();
      });
    });
  }

  void _applyResize(_ResizeEdge edge, Offset delta) {
    if (_panelMinimized || _isFullMode) return;
    double l = _panelLeft;
    double t = _panelTop;
    double w = _panelWidth;
    double h = _panelHeight;
    final dx = delta.dx;
    final dy = delta.dy;
    switch (edge) {
      case _ResizeEdge.right:
        w += dx;
        break;
      case _ResizeEdge.bottom:
        h += dy;
        break;
      case _ResizeEdge.bottomRight:
        w += dx;
        h += dy;
        break;
      case _ResizeEdge.left:
        l += dx;
        w -= dx;
        break;
      case _ResizeEdge.top:
        t += dy;
        h -= dy;
        break;
      case _ResizeEdge.topRight:
        w += dx;
        t += dy;
        h -= dy;
        break;
      case _ResizeEdge.bottomLeft:
        l += dx;
        w -= dx;
        h += dy;
        break;
      case _ResizeEdge.topLeft:
        l += dx;
        t += dy;
        w -= dx;
        h -= dy;
        break;
    }
    final fl = l;
    final ft = t;
    final fw = w;
    final fh = h;
    Future.microtask(() {
      if (!mounted) return;
      setState(() {
        _panelLeft = fl;
        _panelTop = ft;
        _panelWidth = fw;
        _panelHeight = fh;
        _clampPanelRect();
      });
    });
  }

  Widget _resizeHandle(
    _ResizeEdge edge,
    Alignment alignment, {
    double? width,
    double? height,
    MouseCursor? cursor,
  }) {
    final hitW = width ?? _kPanelHandle;
    final hitH = height ?? _kPanelHandle;
    Widget child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (d) => _applyResize(edge, d.delta),
      child:
          SizedBox(width: hitW, height: hitH, child: const SizedBox.expand()),
    );
    if (cursor != null) {
      child = MouseRegion(cursor: cursor, child: child);
    }
    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: child,
      ),
    );
  }

  List<Widget> _buildResizeHandles() {
    final h = _kPanelHandle;
    return [
      _resizeHandle(
        _ResizeEdge.topLeft,
        Alignment.topLeft,
        cursor: SystemMouseCursors.resizeUpLeft,
      ),
      _resizeHandle(
        _ResizeEdge.topRight,
        Alignment.topRight,
        cursor: SystemMouseCursors.resizeUpRight,
      ),
      _resizeHandle(
        _ResizeEdge.bottomLeft,
        Alignment.bottomLeft,
        cursor: SystemMouseCursors.resizeDownLeft,
      ),
      _resizeHandle(
        _ResizeEdge.bottomRight,
        Alignment.bottomRight,
        cursor: SystemMouseCursors.resizeDownRight,
      ),
      _resizeHandle(
        _ResizeEdge.top,
        Alignment.topCenter,
        width: 120,
        height: h,
        cursor: SystemMouseCursors.resizeUp,
      ),
      _resizeHandle(
        _ResizeEdge.bottom,
        Alignment.bottomCenter,
        width: 120,
        height: h,
        cursor: SystemMouseCursors.resizeDown,
      ),
      _resizeHandle(
        _ResizeEdge.left,
        Alignment.centerLeft,
        width: h,
        height: 120,
        cursor: SystemMouseCursors.resizeLeft,
      ),
      _resizeHandle(
        _ResizeEdge.right,
        Alignment.centerRight,
        width: h,
        height: 120,
        cursor: SystemMouseCursors.resizeRight,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserSubscriptionService.instance,
      builder: (context, _) {
        final hasAI = _hasActiveAIAccess();

        debugPrint(
            '🤖 FloatingAI build: hasAI=$hasAI, hidden=$_isHidden, xPos=$_xPosition, hiddenLoaded=$_hiddenLoaded');

        if (!hasAI) return const SizedBox.shrink();

        // Wrap in Material to provide Overlay context for tooltips and other widgets
        return Material(
          type: MaterialType.transparency,
          child: SizedBox.expand(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Expanded chat panel
                if (_isExpanded && !_isHidden) _buildChatPanel(),

                // Floating button (only show if not hidden)
                if (!_isHidden && _xPosition >= 0)
                  Positioned(
                    left: _xPosition,
                    top: _yPosition,
                    child: _buildFloatingButton(),
                  ),

                // "Show AI" chip when hidden
                if (_isHidden && _hiddenLoaded)
                  Positioned(
                    left: _showAiX,
                    top: _showAiY,
                    child: _buildShowAIChip(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFloatingButton() {
    return GestureDetector(
      onTap: () {
        debugPrint('🟢 Floating button tapped - _isExpanded: $_isExpanded');
        if (_isExpanded) {
          // When already open, a single tap should start voice input,
          // not collapse the assistant.
          debugPrint('🟢 Already expanded - toggling continuous voice');
          _toggleContinuousVoice();
          return;
        }
        debugPrint('🟢 Not expanded - calling _openPanel()');
        _openPanel();
      },
      onLongPress: () {
        _setHidden(true);
      },
      onDoubleTap: () {
        // Keep double-tap as quick voice shortcut.
        if (!_isExpanded) _openPanel();
        Future.delayed(const Duration(milliseconds: 180), () {
          if (mounted) _startVoiceInput();
        });
      },
      onPanUpdate: (details) {
        final dx = details.delta.dx;
        final dy = details.delta.dy;
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        Future.microtask(() {
          if (!mounted) return;
          setState(() {
            _xPosition =
                (_xPosition + dx).clamp(0.0, screenWidth - 60).toDouble();
            _yPosition =
                (_yPosition + dy).clamp(0.0, screenHeight - 60).toDouble();
          });
        });
      },
      onPanEnd: (_) {
        // Persist position so it survives app restarts and re-logins
        LocalStorageService.instance
            .setAIFloatingPosition(_xPosition, _yPosition);
      },
      child: AnimatedBuilder(
        animation:
            _isListening ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
        builder: (context, child) {
          return Transform.scale(
            scale: _isListening ? _pulseAnimation.value : 1.0,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isListening
                      ? [Colors.red, Colors.redAccent]
                      : [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      _isListening
                          ? Icons.mic
                          : _isExpanded
                              ? Icons.mic_none
                              : Icons.smart_toy,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  if (_isProcessing) ...[
                    // Centered loading spinner
                    Positioned.fill(
                      child: Center(
                        child: GestureDetector(
                          onDoubleTap: _forceResetProcessing,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    ),
                    // Timer positioned below center
                    if (_processingStartTime != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 8,
                        child: Center(
                          child: StreamBuilder<int>(
                            stream: Stream.periodic(
                                const Duration(seconds: 1), (i) => i),
                            builder: (context, snapshot) {
                              final elapsed = DateTime.now()
                                  .difference(_processingStartTime!)
                                  .inSeconds;
                              return Text(
                                '${elapsed}s',
                                style: TextStyle(
                                  color: elapsed > 30
                                      ? Colors.orange
                                      : Colors.white.withOpacity(0.7),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatPanel() {
    final mq = MediaQuery.of(context);
    final screenWidth = mq.size.width;
    final screenHeight = mq.size.height;
    const edge = 16.0;
    const panelBottomFromNav = 150.0;
    const fullModeEdge = 8.0;
    const fullModeBottom = 16.0;

    // Prefer panel near FAB, but never wider than remaining screen width (avoids horizontal overflow).
    double panelLeft = edge;
    if (!_isFullMode && _xPosition < screenWidth / 2) {
      panelLeft = _xPosition + 70;
    }
    final maxPanelWidth = screenWidth - 2 * edge;
    final widthFromLeft = screenWidth - panelLeft - edge;
    // Never wider than space to the right of panelLeft (prevents horizontal overflow).
    final panelWidth = _isFullMode
        ? (screenWidth - 2 * fullModeEdge)
        : math.min(maxPanelWidth, math.max(0.0, widthFromLeft));
    if (!_isFullMode && panelLeft + panelWidth > screenWidth - edge) {
      panelLeft = math.max(edge, screenWidth - edge - panelWidth);
    }

    // Cap height so panel + bottom offset + keyboard never exceed viewport.
    final viewH = screenHeight - mq.viewInsets.bottom;
    final topSafe = mq.padding.top + edge;
    final rawCompact = viewH - panelBottomFromNav - topSafe;
    // Never taller than space above bottom anchor (avoids vertical overflow).
    // Minimum 220 so the panel is always usable
    final compactHeight =
        rawCompact <= 0 ? 220.0 : math.min(460.0, math.max(220.0, rawCompact));
    final rawFull = viewH - fullModeBottom - topSafe;
    final fullHeight = math.min(rawFull, viewH).clamp(220.0, viewH);

    final panelHeight = _isFullMode ? fullHeight : compactHeight;

    if (!_panelLayoutInitialized) {
      _panelLeft = panelLeft;
      _panelWidth = panelWidth.toDouble();
      _panelHeight = panelHeight.toDouble();
      // Ensure panel top is always visible — never below the bottom nav
      _panelTop = (viewH - panelBottomFromNav - panelHeight)
          .clamp(topSafe,
              math.max(topSafe, viewH - panelBottomFromNav - _kPanelMinH))
          .toDouble();
      _panelLayoutInitialized = true;
    }

    return Positioned(
      left: _isFullMode ? fullModeEdge : _panelLeft,
      right: _isFullMode ? fullModeEdge : null,
      top: _isFullMode ? topSafe : _panelTop,
      bottom: _isFullMode ? fullModeBottom : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: _isFullMode ? null : _onPanelMove,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(20),
            color: AppColors.surface,
            child: SizedBox(
              // ignore: sized_box_for_whitespace
              width: _isFullMode ? null : _panelWidth,
              height: _isFullMode
                  ? null
                  : (_panelMinimized ? _kMiniPanelH : _panelHeight),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header — avoid Row overflow on narrow screens
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.primary,
                                            AppColors.secondary
                                          ],
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: Image.asset(
                                          'assets/images/vervestridelogo.png',
                                          width: 36,
                                          height: 36,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'VerveStride AI',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => setState(() =>
                                                _showModelPicker =
                                                    !_showModelPicker),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _currentThread?.persona !=
                                                          null
                                                      ? AIPersonaService
                                                          .personaLabel(
                                                              _currentThread!
                                                                  .persona)
                                                      : _activeModelLabel,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: _currentThread
                                                                ?.persona !=
                                                            null
                                                        ? const Color(
                                                            0xFFFFB74D)
                                                        : AppColors.primary
                                                            .withOpacity(0.9),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(width: 3),
                                                Icon(
                                                  _showModelPicker
                                                      ? Icons.expand_less
                                                      : Icons.expand_more,
                                                  size: 13,
                                                  color: AppColors.primary
                                                      .withOpacity(0.7),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Icons row - wrapped in horizontal scrollview for small screens
                              Flexible(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Sidebar toggle (menu icon)
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        constraints: const BoxConstraints(
                                            minWidth: 36, minHeight: 36),
                                        padding: EdgeInsets.zero,
                                        icon: Icon(
                                          _showSidebar
                                              ? Icons.menu_open
                                              : Icons.menu,
                                          size: 20,
                                        ),
                                        color: AppColors.textSecondary,
                                        onPressed: () {
                                          setState(() {
                                            _showSidebar = !_showSidebar;
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 2),
                                      // Download chat button
                                      if (_currentThread != null &&
                                          _currentThread!
                                              .messages.isNotEmpty) ...[
                                        IconButton(
                                          visualDensity: VisualDensity.compact,
                                          constraints: const BoxConstraints(
                                              minWidth: 36, minHeight: 36),
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(
                                              Icons.download_outlined,
                                              size: 18),
                                          color: AppColors.textSecondary,
                                          onPressed: _downloadChat,
                                        ),
                                        const SizedBox(width: 2),
                                      ],

                                      // Memory toggles as compact icons
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        constraints: const BoxConstraints(
                                            minWidth: 36, minHeight: 36),
                                        padding: EdgeInsets.zero,
                                        icon: Icon(
                                          _threadMemoryEnabled
                                              ? Icons.forum
                                              : Icons.forum_outlined,
                                          size: 18,
                                        ),
                                        color: _threadMemoryEnabled
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                        tooltip:
                                            'Thread Memory: ${_threadMemoryEnabled ? 'ON' : 'OFF'}',
                                        onPressed: () {
                                          setState(() {
                                            _threadMemoryEnabled =
                                                !_threadMemoryEnabled;
                                          });
                                          _saveMemorySettings();
                                        },
                                      ),
                                      const SizedBox(width: 2),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        constraints: const BoxConstraints(
                                            minWidth: 36, minHeight: 36),
                                        padding: EdgeInsets.zero,
                                        icon: Icon(
                                          _chatMemoryEnabled
                                              ? Icons.history
                                              : Icons.history_outlined,
                                          size: 18,
                                        ),
                                        color: _chatMemoryEnabled
                                            ? const Color(0xFF66BB6A)
                                            : AppColors.textSecondary,
                                        tooltip:
                                            'Chat Memory: ${_chatMemoryEnabled ? 'ON' : 'OFF'}',
                                        onPressed: () {
                                          setState(() {
                                            _chatMemoryEnabled =
                                                !_chatMemoryEnabled;
                                          });
                                          _saveMemorySettings();
                                        },
                                      ),

                                      const SizedBox(width: 6),
                                      // Voice command button
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        constraints: const BoxConstraints(
                                            minWidth: 36, minHeight: 36),
                                        padding: EdgeInsets.zero,
                                        icon: Icon(
                                          _isListening
                                              ? Icons.mic
                                              : Icons.mic_none,
                                          size: 18,
                                        ),
                                        color: _isListening
                                            ? const Color(0xFFFF6B6B)
                                            : AppColors.textSecondary,
                                        tooltip: _isListening
                                            ? 'Listening...'
                                            : 'Voice Command (Tap to speak)',
                                        onPressed: _voiceEnabled
                                            ? () async {
                                                if (_isListening) {
                                                  // Stop listening
                                                  if (_speech.isListening) {
                                                    await _speech.stop();
                                                  }
                                                  if (mounted) {
                                                    setState(() =>
                                                        _isListening = false);
                                                  }
                                                } else {
                                                  // Start listening
                                                  if (!_speechAvailable) {
                                                    await _initSpeech();
                                                  }
                                                  if (_speechAvailable) {
                                                    await _startVoiceInput();
                                                  }
                                                }
                                              }
                                            : null,
                                      ),
                                      const SizedBox(width: 6),
                                      // Credits display
                                      ListenableBuilder(
                                        listenable: CreditsService.instance,
                                        builder: (context, _) {
                                          final credits = CreditsService
                                              .instance.availableCredits;
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary
                                                  .withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: AppColors.primary
                                                    .withOpacity(0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              '💎 $credits',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                          );
                                        },
                                      ),

                                      const SizedBox(width: 6),
                                      // Memory status indicator
                                      GestureDetector(
                                        onTap: _showMemoryHelp,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getMemoryStatusColor()
                                                .withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: _getMemoryStatusColor()
                                                  .withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            _getMemoryStatusIcon(),
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 6),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        constraints: const BoxConstraints(
                                            minWidth: 36, minHeight: 36),
                                        padding: EdgeInsets.zero,
                                        icon: Icon(
                                          _isFullMode
                                              ? Icons.fullscreen_exit
                                              : Icons.fullscreen,
                                          size: 20,
                                        ),
                                        color: AppColors.textSecondary,
                                        onPressed: () {
                                          setState(() {
                                            _isFullMode = !_isFullMode;
                                          });
                                        },
                                      ),
                                      const SizedBox(width: 2),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        constraints: const BoxConstraints(
                                            minWidth: 36, minHeight: 36),
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(Icons.visibility_off,
                                            size: 20),
                                        color: AppColors.textSecondary,
                                        onPressed: () {
                                          _setHidden(true);
                                        },
                                      ),
                                      const SizedBox(width: 2),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        constraints: const BoxConstraints(
                                            minWidth: 36, minHeight: 36),
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(Icons.close, size: 22),
                                        color: AppColors.textSecondary,
                                        onPressed: () {
                                          _textFocusNode.unfocus();
                                          setState(() {
                                            _isExpanded = false;
                                            _isFullMode = false;
                                            _pickedImageBytes = null;
                                            _continuousVoice = false;
                                            _panelLayoutInitialized =
                                                false; // reset so panel re-positions correctly on next open
                                            _showModelPicker = false;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),

                          // Persona indicator — shown when a persona is active
                          if (_currentThread?.persona != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFB74D)
                                          .withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFFFFB74D)
                                            .withOpacity(0.4),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          AIPersonaService.personaEmoji(
                                              _currentThread!.persona),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          AIPersonaService.personaLabel(
                                              _currentThread!.persona),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFFFFB74D),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _currentThread!.persona = null;
                                              _currentThread!.userStyle = null;
                                            });
                                            // Thread will be saved automatically by unified service
                                          },
                                          child: const Icon(
                                            Icons.close,
                                            size: 12,
                                            color: Color(0xFFFFB74D),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Tap × to reset to default',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary
                                            .withOpacity(0.6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 4),

                          // Main content area with sidebar
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Sidebar with conversation threads
                                if (_showSidebar)
                                  Container(
                                    width: 240,
                                    decoration: BoxDecoration(
                                      color: AppColors.card.withOpacity(0.2),
                                      border: Border(
                                        right: BorderSide(
                                          color: Colors.white.withOpacity(0.08),
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        // New Chat button
                                        Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: FilledButton.icon(
                                            onPressed: _createNewThread,
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primary,
                                              minimumSize: const Size(
                                                  double.infinity, 40),
                                            ),
                                            icon:
                                                const Icon(Icons.add, size: 18),
                                            label: const Text('New Chat'),
                                          ),
                                        ),
                                        const Divider(height: 1),
                                        // Thread list
                                        Expanded(
                                          child: _threads.isEmpty
                                              ? const Center(
                                                  child: Padding(
                                                    padding: EdgeInsets.all(16),
                                                    child: Text(
                                                      'No conversations yet\nStart a new chat!',
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : ListView.builder(
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 8),
                                                  itemCount: _threads.length,
                                                  itemBuilder:
                                                      (context, index) {
                                                    final thread =
                                                        _threads[index];
                                                    final isActive =
                                                        _currentThread?.id ==
                                                            thread.id;
                                                    return Container(
                                                      margin: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: isActive
                                                            ? AppColors.primary
                                                                .withOpacity(
                                                                    0.15)
                                                            : Colors
                                                                .transparent,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      child: ListTile(
                                                        dense: true,
                                                        contentPadding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 12,
                                                          vertical: 4,
                                                        ),
                                                        leading: Icon(
                                                          Icons
                                                              .chat_bubble_outline,
                                                          size: 18,
                                                          color: isActive
                                                              ? AppColors
                                                                  .primary
                                                              : AppColors
                                                                  .textSecondary,
                                                        ),
                                                        title: Text(
                                                          thread.title,
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            color: isActive
                                                                ? AppColors
                                                                    .textPrimary
                                                                : AppColors
                                                                    .textSecondary,
                                                            fontWeight: isActive
                                                                ? FontWeight
                                                                    .w600
                                                                : FontWeight
                                                                    .normal,
                                                          ),
                                                        ),
                                                        subtitle: Text(
                                                          _formatThreadTime(thread
                                                              .lastMessageAt),
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 11,
                                                            color: AppColors
                                                                .textSecondary,
                                                          ),
                                                        ),
                                                        trailing: IconButton(
                                                          icon: const Icon(
                                                              Icons
                                                                  .delete_outline,
                                                              size: 16),
                                                          color: AppColors
                                                              .textSecondary,
                                                          padding:
                                                              EdgeInsets.zero,
                                                          constraints:
                                                              const BoxConstraints(
                                                            minWidth: 32,
                                                            minHeight: 32,
                                                          ),
                                                          onPressed: () =>
                                                              _deleteThread(
                                                                  thread.id),
                                                        ),
                                                        onTap: () =>
                                                            _switchThread(
                                                                thread),
                                                      ),
                                                    );
                                                  },
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                // Chat messages area
                                Expanded(
                                  child: _buildChatMessages(),
                                ),
                              ],
                            ),
                          ),

                          // Input area - wrapped in Column to avoid overflow
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Main input row
                              Row(
                                children: [
                                  // Web search toggle — no Tooltip (requires Overlay)
                                  GestureDetector(
                                    onTap: () => setState(() =>
                                        _webSearchEnabled = !_webSearchEnabled),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: _webSearchEnabled
                                            ? const Color(0xFF4285F4)
                                                .withOpacity(0.2)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _webSearchEnabled
                                              ? const Color(0xFF4285F4)
                                                  .withOpacity(0.6)
                                              : Colors.white.withOpacity(0.15),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.language,
                                        size: 16,
                                        color: _webSearchEnabled
                                            ? const Color(0xFF4285F4)
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Attach button — between globe and mic
                                  InkWell(
                                    onTap: () {
                                      debugPrint(
                                          '📎 Attach button tapped! _isProcessing=$_isProcessing');
                                      if (!_isProcessing) {
                                        _toggleAttachMenu();
                                      } else {
                                        debugPrint(
                                            '⚠️ Processing in progress, button disabled');
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: _showAttachMenu
                                            ? AppColors.primary.withOpacity(0.2)
                                            : AppColors.card.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _showAttachMenu
                                              ? AppColors.primary
                                                  .withOpacity(0.5)
                                              : Colors.white.withOpacity(0.15),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 16,
                                        color: _isProcessing
                                            ? AppColors.textSecondary
                                                .withOpacity(0.4)
                                            : _showAttachMenu
                                                ? AppColors.primary
                                                : AppColors.primary
                                                    .withOpacity(0.7),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Voice button — compact
                                  GestureDetector(
                                    onTap: _toggleContinuousVoice,
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color:
                                            (_isListening || _continuousVoice)
                                                ? Colors.red.withOpacity(0.2)
                                                : AppColors.primary
                                                    .withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _isListening
                                            ? Icons.mic
                                            : _continuousVoice
                                                ? Icons.mic
                                                : Icons.mic_none,
                                        color:
                                            (_isListening || _continuousVoice)
                                                ? Colors.red
                                                : AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Text input
                                  Expanded(
                                    child: TextField(
                                      controller: _textController,
                                      focusNode: _textFocusNode,
                                      style: const TextStyle(
                                          color: AppColors.textPrimary),
                                      decoration: InputDecoration(
                                        hintText: 'Type a message...',
                                        hintStyle: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                        ),
                                        filled: true,
                                        fillColor: AppColors.card,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(22),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                      ),
                                      textInputAction: TextInputAction.send,
                                      onSubmitted: (_) => _sendMessage(),
                                      maxLines: 1,
                                      enabled: !_isProcessing,
                                      autocorrect: true,
                                      enableSuggestions: true,
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Send button
                                  GestureDetector(
                                    onTap: _isProcessing ? null : _sendMessage,
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.primary,
                                            AppColors.secondary
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.send,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // File chips below input - like Gemini
                              if (_pickedImageBytes != null ||
                                  _attachedFiles.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      if (_pickedImageBytes != null)
                                        _buildImageAttachmentPreview(),
                                      if (_attachedFiles.isNotEmpty)
                                        Expanded(
                                            child:
                                                _buildFileAttachmentsPreview()),
                                    ],
                                  ),
                                ),

                              // Voice hint
                              if (_isListening)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Center(
                                    child: Text(
                                      'Listening... Speak now',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red.withOpacity(0.8),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ), // close Positioned.fill Container
                  ), // close Positioned.fill
                  if (!_isFullMode) ..._buildResizeHandles(),

                  // Inline model picker overlay
                  if (_showModelPicker) _buildInlineModelPicker(),

                  // Attach menu overlay - positioned absolute like Gemini
                  if (_showAttachMenu)
                    Positioned(
                      left: 60,
                      bottom: 70,
                      child: Material(
                        elevation: 16,
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFF2A2A3A),
                        child: Container(
                          width: 200,
                          constraints: const BoxConstraints(maxHeight: 350),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.15)),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 4),
                                _buildInlineMenuOption(
                                  icon: Icons.photo_library_outlined,
                                  label: 'Upload Image',
                                  color: AppColors.primary,
                                  onTap: () {
                                    setState(() => _showAttachMenu = false);
                                    _pickImage(ImageSource.gallery);
                                  },
                                ),
                                _buildInlineMenuOption(
                                  icon: Icons.attach_file,
                                  label: 'Upload Files',
                                  color: Colors.blue,
                                  onTap: () {
                                    setState(() => _showAttachMenu = false);
                                    _pickFiles();
                                  },
                                ),
                                if (!kIsWeb)
                                  _buildInlineMenuOption(
                                    icon: Icons.camera_alt_outlined,
                                    label: 'Take Photo',
                                    color: AppColors.primary,
                                    onTap: () {
                                      setState(() => _showAttachMenu = false);
                                      _pickImage(ImageSource.camera);
                                    },
                                  ),
                                _buildInlineMenuOption(
                                  icon: Icons.videocam_outlined,
                                  label: 'Live Video',
                                  color: Colors.redAccent,
                                  onTap: () {
                                    setState(() => _showAttachMenu = false);
                                    Navigator.pushNamed(
                                      appNavigatorKey.currentContext!,
                                      Routes.liveVideoSession,
                                    );
                                  },
                                ),
                                const Divider(
                                    height: 1,
                                    color: Colors.white24,
                                    thickness: 1),
                                _buildInlineMenuOption(
                                  icon: Icons.auto_awesome,
                                  label: 'Generate Image',
                                  color: Colors.purpleAccent,
                                  onTap: () {
                                    setState(() => _showAttachMenu = false);
                                    _promptImageGeneration();
                                  },
                                ),
                                _buildInlineMenuOption(
                                  icon: Icons.video_library,
                                  label: 'Generate Video',
                                  color: Colors.pinkAccent,
                                  onTap: () {
                                    setState(() {
                                      _showAttachMenu = false;
                                      _textController.text =
                                          'Create a video of ';
                                      _textFocusNode.requestFocus();
                                      _textController.selection =
                                          TextSelection.fromPosition(
                                        TextPosition(
                                            offset:
                                                _textController.text.length),
                                      );
                                    });
                                  },
                                ),
                                _buildInlineMenuOption(
                                  icon: Icons.music_note,
                                  label: 'Generate Audio',
                                  color: Colors.orangeAccent,
                                  onTap: () {
                                    setState(() {
                                      _showAttachMenu = false;
                                      _textController.text =
                                          'Create music for ';
                                      _textFocusNode.requestFocus();
                                      _textController.selection =
                                          TextSelection.fromPosition(
                                        TextPosition(
                                            offset:
                                                _textController.text.length),
                                      );
                                    });
                                  },
                                ),
                                const SizedBox(height: 4),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ), // close ClipRRect
        ),
      ),
    );
  }

  Future<void> _startVoiceInput() async {
    if (_isProcessing || _isListening) return;
    _continuousVoice = false;
    _stopContinuousVoiceWatchdog();

    // Note: _voiceEnabled only controls TTS output, not voice input
    // Manual mic tap should always work (if mic permission is granted)

    // Lazy initialization: Initialize speech only when user taps mic
    if (!_speechAvailable) {
      debugPrint('🎤 Lazy initializing speech recognition...');
      await _initSpeech();

      // If still not available after init, show error
      if (!_speechAvailable) {
        if (mounted) {
          final isPermissionDenied = _speechError == 'not-allowed';
          ScaffoldMessenger.of(appNavigatorKey.currentContext ?? context)
              .showSnackBar(
            SnackBar(
              content: Text(
                isPermissionDenied
                    ? 'Microphone access denied. Allow mic permission in your browser settings.'
                    : _speechError.isEmpty
                        ? 'Voice not available on this browser. Try Chrome or Edge.'
                        : 'Voice unavailable: $_speechError',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    }

    // Stop any previous recognition session before starting a new manual one.
    // Check if already listening using the speech library's state
    if (_speech.isListening) {
      try {
        await _speech.stop();
        // Small delay to ensure state is fully cleared
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        debugPrint('⚠️ Error stopping existing speech: $e');
      }
    }

    setState(() {
      _isListening = true;
      _speechError = '';
    });
    _textController.clear();

    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;

          // Get recognized text
          final text = result.recognizedWords.trim();

          // Skip empty results
          if (text.isEmpty) return;

          // Get current text for comparison
          final currentText = _textController.text.trim();

          // Remove duplicate words that appear consecutively
          final cleanedText = _removeDuplicateWords(text);

          // Only update if text actually changed
          if (cleanedText != currentText) {
            _textController.value = TextEditingValue(
              text: cleanedText,
              selection: TextSelection.collapsed(offset: cleanedText.length),
            );
          }

          // Auto-send when speech is finalized and text is not empty
          // Keep listening for more input (continuous mode)
          if (result.finalResult && cleanedText.isNotEmpty) {
            _sendMessageAndContinueListening();
          }
        },
        listenFor: const Duration(
            seconds: 60), // Increased from 30 to 60 for longer sessions
        pauseFor: const Duration(
            seconds: 3), // Reduced from 5 to 3 for quicker response
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.confirmation,
      );
    } catch (e) {
      debugPrint('Speech listen error: $e');
      final msg = e.toString();

      // Handle "already started" error specifically
      if (msg.contains('already started') ||
          msg.contains('InvalidStateError')) {
        debugPrint(
            '⚠️ Speech recognition was already active, attempting to reset...');
        try {
          await _speech.stop();
          await Future.delayed(const Duration(milliseconds: 150));
        } catch (resetError) {
          debugPrint('⚠️ Error resetting speech: $resetError');
        }
      }

      if (mounted) {
        setState(() {
          _isListening = false;
          // Don't turn off _continuousVoice on speech errors - keep it active
          if (msg.contains("type 'Null' is not a subtype of type 'bool'")) {
            _speechAvailable = false;
            _speechError =
                'Voice service unavailable on this device. Update Google app and Speech Services, then restart app.';
          } else {
            _speechError = msg;
          }
        });

        // Reduced snackbar duration to minimize UI interruption
        ScaffoldMessenger.of(appNavigatorKey.currentContext ?? context)
            .showSnackBar(
          SnackBar(
            content: Text(
              msg.contains("type 'Null' is not a subtype of type 'bool'")
                  ? 'Voice service failed on this device. Please update Google voice services.'
                  : 'Voice input error: $msg',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2), // Reduced from 4 to 2 seconds
          ),
        );
      }
    }
  }

  Future<void> _stopVoiceInput() async {
    if (!_isListening && _textController.text.trim().isEmpty) return;

    // Check if speech recognition is actually listening before stopping
    if (_speech.isListening) {
      try {
        await _speech.stop();
        // Small delay to ensure state is cleared
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (e) {
        debugPrint('⚠️ Error stopping speech: $e');
      }
    }

    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }

    // Send message if we captured text
    if (_textController.text.trim().isNotEmpty) {
      await _sendMessage();
    }

    // Wake word listening disabled by default
  }

  /// Remove consecutive duplicate words from speech recognition text
  /// Handles both space-separated duplicates and concatenated duplicates
  /// Example: "hello hello world" -> "hello world"
  /// Example: "whatwhatwhat" -> "what"
  String _removeDuplicateWords(String text) {
    if (text.length <= 3) return text;

    // First, handle space-separated duplicates
    final words = text.split(' ');
    final result = <String>[];
    String? lastWord;

    for (final word in words) {
      final cleanWord = word.trim().toLowerCase();
      if (cleanWord.isEmpty) continue;

      // Check for concatenated duplicates within the word itself
      final dedupWord = _deduplicateConcatenated(word);

      // Only add if different from last word
      if (cleanWord != lastWord) {
        result.add(dedupWord); // Use deduplicated version
        lastWord = cleanWord;
      }
    }

    return result.join(' ');
  }

  /// Remove pattern-based duplicates like "whatwhatwhat" -> "what"
  String _deduplicateConcatenated(String word) {
    if (word.length < 6) return word; // Too short to have duplicates

    // Try different pattern lengths (from half the word down to 2 chars)
    for (int patternLen = word.length ~/ 2; patternLen >= 2; patternLen--) {
      final pattern = word.substring(0, patternLen).toLowerCase();

      // Check if the word is just this pattern repeated
      bool isRepeated = true;
      int pos = 0;

      while (pos < word.length) {
        int endPos = pos + patternLen;
        if (endPos > word.length) endPos = word.length;

        final chunk = word.substring(pos, endPos).toLowerCase();
        if (chunk != pattern.substring(0, chunk.length)) {
          isRepeated = false;
          break;
        }
        pos += patternLen;
      }

      if (isRepeated && word.length >= patternLen * 2) {
        // Found a repeated pattern, return just one instance
        return word.substring(0, patternLen);
      }
    }

    return word; // No duplication found
  }

  /// Send message and restart listening for continuous voice input
  Future<void> _sendMessageAndContinueListening() async {
    final textToSend = _textController.text.trim();
    if (textToSend.isEmpty) return;

    // Prevent duplicate sends - if already processing, skip
    if (_isProcessing) {
      debugPrint('⚠️ [Continuous] Already processing, skipping duplicate send');
      return;
    }

    debugPrint('🎤 [Continuous] Sending message: $textToSend');

    // Send the message WITHOUT stopping listening state
    // Don't call _stopVoiceInput() - we want to keep listening

    // Clear input and send message
    final messageText = textToSend;
    _textController.clear();

    // Send to chat service
    if (mounted) {
      setState(() => _isProcessing = true);
    }

    try {
      await _chatService.sendMessage(messageText);
      debugPrint('✅ [Continuous] Message sent successfully');
    } catch (e) {
      debugPrint('❌ [Continuous] Error sending message: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }

    // Short delay before restarting listening
    await Future.delayed(const Duration(milliseconds: 500));

    // Restart speech recognition if still in listening mode
    if (mounted && _isListening && !_isProcessing) {
      debugPrint('🎤 [Continuous] Restarting listening...');

      // Stop current listening session
      if (_speech.isListening) {
        try {
          await _speech.stop();
          await Future.delayed(const Duration(milliseconds: 150));
        } catch (e) {
          debugPrint('⚠️ [Continuous] Error stopping speech: $e');
        }
      }

      // Restart listening
      try {
        await _speech.listen(
          onResult: (result) {
            if (!mounted || _isProcessing) return;

            // Get recognized text
            final text = result.recognizedWords.trim();

            // Skip empty results
            if (text.isEmpty) return;

            // Get current text for comparison
            final currentText = _textController.text.trim();

            // Remove duplicate words that appear consecutively
            final cleanedText = _removeDuplicateWords(text);

            // Only update if text actually changed
            if (cleanedText != currentText) {
              _textController.value = TextEditingValue(
                text: cleanedText,
                selection: TextSelection.collapsed(offset: cleanedText.length),
              );
            }

            if (result.finalResult && cleanedText.isNotEmpty) {
              _sendMessageAndContinueListening();
            }
          },
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.confirmation,
        );
        debugPrint('✅ [Continuous] Listening restarted, ready for next input');
      } catch (e) {
        debugPrint('❌ [Continuous] Error restarting speech: $e');
        if (mounted) {
          setState(() {
            _isListening = false;
          });
        }
      }
    } else {
      debugPrint(
          'ℹ️ [Continuous] Not restarting: mounted=$mounted, listening=$_isListening, processing=$_isProcessing');
    }
  }

  Future<void> _toggleContinuousVoice() async {
    // Check if voice is enabled first
    if (!_voiceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(appNavigatorKey.currentContext ?? context)
            .showSnackBar(
          const SnackBar(
            content: Text(
                'Voice commands are disabled. Enable them in AI Settings.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Manual mic: tap to listen, tap again to stop and send captured text.
    if (_isListening) {
      debugPrint('🎤 Stopping continuous voice mode');
      _continuousVoice = false;
      _stopContinuousVoiceWatchdog();
      await _stopVoiceInput();
      return;
    }

    if (_chatService.isProcessing) return;
    debugPrint('🎤 Starting continuous voice mode');
    _continuousVoice = false;
    await _startVoiceInput();
  }

  void _stopContinuousVoiceWatchdog() {
    _continuousVoiceWatchdog?.cancel();
    _continuousVoiceWatchdog = null;
  }

  Future<void> _sendMessage() async {
    // Guard against double-send at the wrapper level
    if (_isProcessing) return;
    if (_textController.text.trim().isEmpty) return;

    // Processing state is managed by UnifiedAIChatService
    if (mounted) setState(() {});
    // Wrap the entire send message process with a timeout to prevent infinite loading
    try {
      await _sendMessageInternal().timeout(
        const Duration(seconds: 90), // Slightly longer than AI service timeout
        onTimeout: () {
          debugPrint('🚫 _sendMessage timed out after 90 seconds');
          if (mounted) {
            setState(() {
              // Processing state managed by UnifiedAIChatService
              _isListening = false;
              _continuousVoice = false;
            });

            // Add timeout message to thread
            if (_currentThread != null) {
              setState(() {
                final mutableMessages =
                    List<ChatMessage>.from(_currentThread!.messages);
                mutableMessages.add(ChatMessage(
                  role: 'system',
                  content:
                      '⏱️ Request timed out after 90 seconds. Please try a shorter message or check your internet connection.',
                  timestamp: DateTime.now(),
                  creditLabel: 'Timeout',
                ));
                _currentThread = ConversationThread(
                  id: _currentThread!.id,
                  title: _currentThread!.title,
                  createdAt: _currentThread!.createdAt,
                  lastMessageAt: _currentThread!.lastMessageAt,
                  messages: mutableMessages,
                  persona: _currentThread!.persona,
                  userStyle: _currentThread!.userStyle,
                );
              });
            }
          }
          throw Exception('Message processing timed out');
        },
      );
    } catch (e) {
      debugPrint('❌ _sendMessage wrapper error: $e');
      // Ensure processing state is reset even if timeout handler fails
      if (mounted) {
        setState(() {
          // Processing state managed by UnifiedAIChatService
          _isListening = false;
          _continuousVoice = false;
        });
      }
    }
  }

  Future<void> _sendMessageInternal() async {
    debugPrint('🔴 _sendMessageInternal START');
    final message = _textController.text.trim();
    final imageBytes = _pickedImageBytes; // Capture single image if attached
    final attachedFiles =
        List<PlatformFile>.from(_attachedFiles); // Capture all files

    debugPrint(
        '🎤 _sendMessage called: message="$message", hasImage=${imageBytes != null}, attachedFiles=${attachedFiles.length}, continuousVoice=$_continuousVoice, processing=${_chatService.isProcessing}');

    if (message.isEmpty && imageBytes == null && attachedFiles.isEmpty) {
      debugPrint('🔴 Message, image, and files all empty, returning');
      return;
    }

    debugPrint('🟣 Message or attachments present, checking credits...');

    // Clear the picked image and files state now that we've captured them
    if (imageBytes != null) {
      setState(() => _pickedImageBytes = null);
    }
    if (attachedFiles.isNotEmpty) {
      setState(() => _attachedFiles.clear());
    }

    // Check if user has enough credits
    final preciseCredits = CreditsService.instance.preciseCredits;
    debugPrint('🟣 User has $preciseCredits credits');

    if (preciseCredits <= 0.001) {
      final navContext = appNavigatorKey.currentContext;
      if (navContext != null) {
        ScaffoldMessenger.of(navContext).showSnackBar(
          SnackBar(
            content: const Text(
                '⚠️ No credits left. Buy credits to continue using AI.'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Buy Credits',
              textColor: Colors.white,
              onPressed: () {},
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    // ── Image/Video generation detection (BEFORE unified service) ──────────
    final lowerMessage = message.toLowerCase();
    final isImageRequest = (lowerMessage.contains('generate') ||
            lowerMessage.contains('create') ||
            lowerMessage.contains('make') ||
            lowerMessage.contains('draw') ||
            lowerMessage.contains('design')) &&
        (lowerMessage.contains('image') ||
            lowerMessage.contains('picture') ||
            lowerMessage.contains('photo') ||
            lowerMessage.contains('illustration') ||
            lowerMessage.contains('poster') ||
            lowerMessage.contains('logo') ||
            lowerMessage.contains('art'));

    final isVideoRequest = (lowerMessage.contains('generate') ||
            lowerMessage.contains('create') ||
            lowerMessage.contains('make') ||
            lowerMessage.contains('record')) &&
        (lowerMessage.contains('video') ||
            lowerMessage.contains('clip') ||
            lowerMessage.contains('animation') ||
            lowerMessage.contains('demonstration') ||
            lowerMessage.contains('demo'));

    // Handle image generation - AI asks for confirmation first
    if (isImageRequest) {
      debugPrint(
          '🎨 Image generation request detected - asking for confirmation');

      // Add user message
      final userMessage = ChatMessage(
        role: 'user',
        content: message,
        timestamp: DateTime.now(),
      );

      // Add AI warning message with pending action
      final confirmMessage = ChatMessage(
        role: 'assistant',
        content:
            '⚠️ **Credit Cost Warning**\n\nGenerating this image will cost **${AIFeatureCosts.imageGeneration} credits**.\n\nIs it okay to proceed?',
        timestamp: DateTime.now(),
        pendingAction: 'generate_image',
        pendingData: {'prompt': message},
      );

      // Add to current thread
      if (_currentThread != null) {
        _currentThread!.messages.add(userMessage);
        _currentThread!.messages.add(confirmMessage);
        _currentThread!.lastMessageAt = DateTime.now();
        await _chatService.initialize(); // Save the thread

        setState(() {
          _threads = _chatService.getAllThreads();
        });
      }

      _textController.clear();
      return; // Exit early - wait for user confirmation
    }

    // Check if user is responding to a pending action
    final lastMessage = _currentThread?.messages.lastOrNull;
    if (lastMessage != null && lastMessage.hasPendingAction) {
      final lowerReply = message.toLowerCase().trim();

      // Check for affirmative responses
      if (lowerReply == 'yes' ||
          lowerReply == 'sure' ||
          lowerReply == 'ok' ||
          lowerReply == 'okay' ||
          lowerReply == 'go' ||
          lowerReply == 'go ahead' ||
          lowerReply == 'continue' ||
          lowerReply == 'proceed' ||
          lowerReply == 'yep' ||
          lowerReply == 'yeah' ||
          lowerReply == 'yea') {
        // User confirmed - execute the pending action
        debugPrint(
            '✅ User confirmed pending action: ${lastMessage.pendingAction}');

        // Add user confirmation message
        final userConfirm = ChatMessage(
          role: 'user',
          content: message,
          timestamp: DateTime.now(),
        );
        _currentThread!.messages.add(userConfirm);

        // Execute the action
        if (lastMessage.pendingAction == 'generate_image') {
          await _executeImageGeneration(
              lastMessage.pendingData!['prompt'] as String);
        }

        _textController.clear();
        return;
      }

      // Check for negative responses
      if (lowerReply == 'no' ||
          lowerReply == 'nope' ||
          lowerReply == 'cancel' ||
          lowerReply == 'nevermind' ||
          lowerReply == 'never mind' ||
          lowerReply == 'stop' ||
          lowerReply == 'dont' ||
          lowerReply == "don't" ||
          lowerReply == 'nah') {
        // User cancelled - remove pending action
        debugPrint('❌ User cancelled pending action');

        // Add user cancellation message
        final userCancel = ChatMessage(
          role: 'user',
          content: message,
          timestamp: DateTime.now(),
        );

        // Add AI acknowledgment
        final aiAck = ChatMessage(
          role: 'assistant',
          content: 'No problem! Let me know if you need anything else.',
          timestamp: DateTime.now(),
        );

        _currentThread!.messages.add(userCancel);
        _currentThread!.messages.add(aiAck);
        _currentThread!.lastMessageAt = DateTime.now();

        await _chatService.initialize(); // Save

        setState(() {
          _threads = _chatService.getAllThreads();
        });

        _textController.clear();
        return;
      }
    }

    // Handle video generation
    if (isVideoRequest) {
      debugPrint('🎬 Video generation request detected');
      // TODO: Implement video generation similar to image
      final navContext = appNavigatorKey.currentContext;
      if (navContext != null) {
        ScaffoldMessenger.of(navContext).showSnackBar(
          const SnackBar(
            content: Text('🎬 Video generation coming soon!'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      return; // Exit early
    }

    // Show credit cost confirmation for free users (not for Pro/Elite)
    // TEMPORARILY DISABLED FOR DEBUGGING - Re-enable after fixing Vertex AI
    final sub = UserSubscriptionService.instance;
    final isFreeUser = !sub.isPro && !sub.isElite && !sub.isLifetime;
    debugPrint(
        '🟣 isFreeUser: $isFreeUser, continuousVoice: $_continuousVoice');
    debugPrint('🟣 Credit confirmation dialog DISABLED for debugging');

    // Set local processing state immediately for UI responsiveness
    setState(() {
      _processingStartTime = DateTime.now();
      _isProcessing = true;
    });

    _textController.clear();

    try {
      debugPrint('🔴 Using unified chat service to send message (STREAMING)');

      // Prepare the message - if attachments exist, add context
      String finalMessage =
          message.isNotEmpty ? message : 'What can you tell me about this?';

      // Collect all image bytes (from both image picker and file picker)
      final allImageBytes = <Uint8List>[];
      if (imageBytes != null) {
        allImageBytes.add(imageBytes);
      }
      // Add images from file picker
      for (final file in attachedFiles) {
        final ext = file.extension?.toUpperCase() ?? '';
        final isImage =
            ['JPG', 'JPEG', 'PNG', 'GIF', 'WEBP', 'BMP'].contains(ext);
        if (isImage && file.bytes != null) {
          allImageBytes.add(file.bytes!);
        }
      }

      if (allImageBytes.isNotEmpty) {
        finalMessage =
            '[${allImageBytes.length} image${allImageBytes.length > 1 ? 's' : ''} attached] $finalMessage';
        debugPrint('📷 ${allImageBytes.length} image(s) attached to message');
      }

      // Use streaming so text appears word-by-word as it's generated
      // Send all images to AI (multi-image support)
      await for (final _ in _chatService.sendMessageStream(
        finalMessage,
        persona: _currentThread?.persona,
        userStyle: _currentThread?.userStyle,
        useWebSearch: _webSearchEnabled,
        imageBytesList: allImageBytes.isNotEmpty
            ? allImageBytes
            : null, // Send all images at once
      )) {
        // Each chunk triggers _notifyListeners() inside the service,
        // which calls _onChatUpdated() here and rebuilds the message bubble
        // incrementally — giving the typewriter streaming effect.
        if (mounted) {
          setState(() {
            _currentThread = _chatService.activeThread;
          });
        }
      }

      debugPrint('✅ Streaming complete');

      // Final state sync after stream finishes
      if (mounted) {
        setState(() {
          _currentThread = _chatService.activeThread;
          _threads = _chatService.getAllThreads();
          _processingStartTime = null;
          _isProcessing = _chatService.isProcessing;
        });
      }

      // Handle TTS if voice is enabled
      final lastMessage = _currentThread?.messages.lastOrNull;
      if (lastMessage != null &&
          lastMessage.role == 'assistant' &&
          _voiceEnabled) {
        debugPrint('🎤 Speaking response...');
        try {
          await FirebaseAIService.instance.speakResponse(lastMessage.content);
          debugPrint('🎤 TTS completed');
        } catch (e) {
          debugPrint('⚠️ TTS error: $e');
        }
      }

      // Handle continuous voice mode
      if (_continuousVoice && mounted && !_isListening) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted && _continuousVoice && !_isListening) {
          try {
            await _startVoiceInput();
          } catch (e) {
            debugPrint('⚠️ Error restarting voice: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      if (mounted) {
        setState(() {
          _isProcessing =
              _chatService.isProcessing; // Sync with unified service
          _processingStartTime = null;
        });

        ScaffoldMessenger.of(appNavigatorKey.currentContext ?? context)
            .showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Execute image generation after user confirms
  Future<void> _executeImageGeneration(String prompt) async {
    debugPrint('🎨 Executing image generation with prompt: $prompt');

    setState(() {
      _isProcessing = true;
    });

    try {
      // Show "Generating..." message to user
      final generatingMessage = ChatMessage(
        role: 'assistant',
        content: '🎨 Generating your image... This may take 30-60 seconds.',
        timestamp: DateTime.now(),
      );

      _currentThread!.messages.add(generatingMessage);
      await _chatService.initialize();
      setState(() {
        _threads = _chatService.getAllThreads();
      });

      // Generate the image
      final result = await FirebaseAIService.instance.generateImage(prompt);

      // Remove "Generating..." message
      _currentThread!.messages.removeLast();

      if (result != null && mounted) {
        // Convert bytes to base64
        final imageBase64 = base64Encode(result);

        // Add success message with image
        final imageMessage = ChatMessage(
          role: 'assistant',
          content: '✨ Here\'s your generated image!',
          timestamp: DateTime.now(),
          imageBase64: imageBase64,
          creditsUsed: AIFeatureCosts.imageGeneration,
          preciseCredits: AIFeatureCosts.imageGeneration.toDouble(),
        );

        _currentThread!.messages.add(imageMessage);
        _currentThread!.lastMessageAt = DateTime.now();

        await _chatService.initialize(); // Save

        setState(() {
          _threads = _chatService.getAllThreads();
        });

        // Show success snackbar
        ScaffoldMessenger.of(appNavigatorKey.currentContext ?? context)
            .showSnackBar(
          SnackBar(
            content: Text(
                '✅ Image generated! ${AIFeatureCosts.imageGeneration} credits used'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        // Failed to generate - NO CREDITS DEDUCTED
        final errorMessage = ChatMessage(
          role: 'assistant',
          content:
              '❌ Sorry, I couldn\'t generate the image. The service might be busy.\n\n✅ No credits were deducted.\n\nPlease try again in a moment.',
          timestamp: DateTime.now(),
        );

        _currentThread!.messages.add(errorMessage);
        await _chatService.initialize();

        setState(() {
          _threads = _chatService.getAllThreads();
        });

        // Show no credits deducted message
        ScaffoldMessenger.of(appNavigatorKey.currentContext ?? context)
            .showSnackBar(
          const SnackBar(
            content: Text('⚠️ Image generation failed - No credits deducted'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error generating image: $e');

      if (mounted) {
        final errorMessage = ChatMessage(
          role: 'assistant',
          content:
              '❌ Error generating image: $e\n\n✅ No credits were deducted.',
          timestamp: DateTime.now(),
        );

        _currentThread!.messages.add(errorMessage);
        await _chatService.initialize();

        setState(() {
          _threads = _chatService.getAllThreads();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _executeVoiceCommand(VoiceCommand command) async {
    switch (command.action) {
      case 'export_data':
        final filePath = await FirebaseAIService.instance.exportAllUserData();
        await FirebaseAIService.instance.shareExportedData(filePath);
        if (mounted) {
          ScaffoldMessenger.of(appNavigatorKey.currentContext ?? context)
              .showSnackBar(
            SnackBar(
              content: const Text('Data exported successfully!'),
              backgroundColor: AppColors.secondary,
            ),
          );
        }
        break;
      case 'delete_data':
        await _confirmAndDeleteAllData();
        break;
      case 'start_workout':
      case 'log_meal':
      case 'log_water':
      case 'show_progress':
      case 'chat':
        // Handled by response/navigation, no explicit side effect here.
        break;
      default:
        // Unknown actions gracefully fall back to response-only behavior.
        break;
    }
  }

  /// Detect if the question/response suggests live web data is needed
  bool _needsWebSearch(String question, String response) {
    final q = question.toLowerCase();
    final r = response.toLowerCase();

    // Question keywords that suggest live data
    final liveKeywords = [
      'today',
      'now',
      'current',
      'latest',
      'recent',
      'news',
      'price',
      'weather',
      'stock',
      'live',
      'right now',
      'this week',
      'this month',
      'trending',
      'update',
      '2024',
      '2025',
      '2026',
    ];
    final questionNeedsLive = liveKeywords.any((k) => q.contains(k));

    // Response phrases that indicate the AI couldn't access live data
    final cantSearchPhrases = [
      "don't have access",
      "cannot browse",
      "can't browse",
      "no internet",
      "not able to search",
      "training data",
      "knowledge cutoff",
      "real-time",
      "up-to-date information",
      "cannot access",
      "unable to access",
    ];
    final responseAdmitsCantSearch =
        cantSearchPhrases.any((p) => r.contains(p));

    return questionNeedsLive || responseAdmitsCantSearch;
  }

  /// Safe navigation — uses root navigator, works outside Overlay scope.
  void _navigate(String route) {
    appNavigatorKey.currentState?.pushNamed(route);
  }

  /// Download the current chat thread as a text file
  void _downloadChat() {
    final thread = _currentThread;
    if (thread == null || thread.messages.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('VerveStride AI — Chat Export');
    buffer.writeln('Thread: ${thread.title}');
    buffer.writeln('Date: ${DateTime.now().toLocal()}');
    buffer.writeln('=' * 50);
    buffer.writeln();

    for (final msg in thread.messages) {
      final role = msg.isUser ? 'You' : 'VerveStride AI';
      final time =
          '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';
      buffer.writeln('[$time] $role:');
      buffer.writeln(msg.content);
      buffer.writeln();
    }

    final text = buffer.toString();

    if (kIsWeb) {
      // Web: copy to clipboard and show snackbar (download via anchor not reliable in Flutter web)
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(appNavigatorKey.currentContext ?? context)
          .showSnackBar(
        const SnackBar(
          content: Text(
              'Chat copied to clipboard — paste into any text editor to save'),
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // Mobile: copy to clipboard
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(appNavigatorKey.currentContext ?? context)
          .showSnackBar(
        const SnackBar(
          content: Text('Chat copied to clipboard'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool> _handleAppNavigationIntent({
    required String action,
    required String rawMessage,
  }) async {
    final a = action.toLowerCase();
    final text = rawMessage.toLowerCase();

    final screenMap = {
      'home': Routes.home,
      'meals': Routes.meals,
      'meal': Routes.meals,
      'workout': Routes.workoutPiP,
      'workouts': Routes.workoutPiP,
      'profile': Routes.profile,
      'progress': Routes.profile,
      'calendar': Routes.calendar,
      'activity': Routes.activity,
      'activities': Routes.activity,
      'reminders': Routes.customReminders,
      'reminder': Routes.customReminders,
      'settings': Routes.settings,
      'premium': Routes.premium,
      'subscription': Routes.premium,
    };

    if (screenMap.containsKey(a)) {
      _navigate(screenMap[a]!);
      return true;
    }
    if (text.contains('workout') ||
        text.contains('exercise') ||
        a == 'start_workout') {
      _navigate(Routes.workoutPiP);
      return true;
    }
    if (text.contains('meal') ||
        text.contains('food') ||
        text.contains('eat') ||
        a == 'log_meal') {
      _navigate(Routes.meals);
      return true;
    }
    if (text.contains('progress') ||
        text.contains('profile') ||
        a == 'show_progress') {
      _navigate(Routes.profile);
      return true;
    }
    if (text.contains('water') || a == 'log_water') {
      _navigate(Routes.home);
      return true;
    }
    if (text.contains('calendar')) {
      _navigate(Routes.calendar);
      return true;
    }
    if (text.contains('activity') || text.contains('activities')) {
      _navigate(Routes.activity);
      return true;
    }
    if (text.contains('reminder') || text.contains('alarm')) {
      _navigate(Routes.customReminders);
      return true;
    }
    if (text.contains('settings')) {
      _navigate(Routes.settings);
      return true;
    }
    if (text.contains('premium') ||
        text.contains('subscription') ||
        text.contains('upgrade')) {
      _navigate(Routes.premium);
      return true;
    }
    return false;
  }

  Future<void> _handleKeywordNavigationFallback(String rawMessage) async {
    final text = rawMessage.toLowerCase();
    if (text.contains('open home') || text == 'home') _navigate(Routes.home);
  }

  Future<void> _confirmAndDeleteAllData() async {
    final dlgContext = appNavigatorKey.currentContext;
    if (dlgContext == null) return;
    final confirmed = await showDialog<bool>(
      context: dlgContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Delete all data?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This permanently deletes your local app data. This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await FirebaseAIService.instance.deleteAllUserData();
    if (mounted) {
      ScaffoldMessenger.of(appNavigatorKey.currentContext ?? context)
          .showSnackBar(
        const SnackBar(
          content: Text('All data deleted successfully'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildInlineModelPicker() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showModelPicker = false),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () {}, // prevent dismiss when tapping inside
              child: LayoutBuilder(
                builder: (context, constraints) => ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: (constraints.maxHeight - 72)
                        .clamp(200.0, double.infinity),
                  ),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 60, 12, 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.secondary
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.smart_toy,
                                  color: Colors.white, size: 14),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Select AI Model',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _showModelPicker = false),
                              child: const Icon(Icons.close,
                                  size: 18, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        // Model list — flexible + scrollable so it never overflows
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children:
                                  AIModelConfig.selectableModels.map((model) {
                                final isSelected = _activeModelId == model.id;
                                final accent =
                                    AIModelConfig.badgeColor(model.badge);
                                return GestureDetector(
                                  onTap: () => _selectModel(model),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 9),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? accent.withOpacity(0.12)
                                          : Colors.white.withOpacity(0.04),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? accent.withOpacity(0.5)
                                            : Colors.white.withOpacity(0.07),
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Radio dot
                                        AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 150),
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected
                                                  ? accent
                                                  : AppColors.textSecondary,
                                              width: 2,
                                            ),
                                            color: isSelected
                                                ? accent
                                                : Colors.transparent,
                                          ),
                                          child: isSelected
                                              ? const Icon(Icons.check,
                                                  size: 11, color: Colors.white)
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
                                        // Name + desc
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                model.displayName,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: isSelected
                                                      ? accent
                                                      : AppColors.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                model.description,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Right side: badge + credit cost
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (model.badge.isNotEmpty)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color:
                                                      accent.withOpacity(0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  model.badge,
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: accent,
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(height: 3),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AIModelConfig
                                                        .creditColor(model
                                                            .creditsPerMessage)
                                                    .withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: AIModelConfig
                                                          .creditColor(model
                                                              .creditsPerMessage)
                                                      .withOpacity(0.3),
                                                ),
                                              ),
                                              child: Text(
                                                '${model.creditsPerMessage} credit${model.creditsPerMessage > 1 ? 's' : ''}',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w600,
                                                  color: AIModelConfig
                                                      .creditColor(model
                                                          .creditsPerMessage),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShowAIChip() {
    return GestureDetector(
      onTap: () {
        _setHidden(false);
      },
      onPanUpdate: (details) {
        final dx = details.delta.dx;
        final dy = details.delta.dy;
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        Future.microtask(() {
          if (!mounted) return;
          setState(() {
            _showAiX = (_showAiX + dx)
                .clamp(0.0, screenWidth - _kShowAiChipW)
                .toDouble();
            _showAiY = (_showAiY + dy)
                .clamp(0.0, screenHeight - _kShowAiChipH)
                .toDouble();
          });
        });
      },
      child: Container(
        width: _kShowAiChipW,
        height: _kShowAiChipH,
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(
            color: AppColors.primary.withOpacity(0.4),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.remove_red_eye_outlined,
              color: AppColors.primary.withOpacity(0.7),
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              'Show AI',
              style: TextStyle(
                color: AppColors.primary.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated "..." thinking indicator — three dots that fade in sequence.
class _ThinkingDots extends StatefulWidget {
  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(begin: 0, end: 3).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final step = _anim.value.floor(); // 0, 1, 2
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final active = i <= step;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(active ? 0.85 : 0.2),
              ),
            );
          }),
        );
      },
    );
  }
}
