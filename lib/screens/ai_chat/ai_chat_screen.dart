import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/app_theme.dart';
import '../../core/routes.dart';
import '../../models/conversation_thread.dart';
import '../../models/ai_model_config.dart';
import '../../models/ai_feature_costs.dart';
import '../../services/unified_ai_chat_service.dart';
import '../../services/firebase_ai_service.dart';
import '../../services/credits_service.dart';
import '../../services/local_storage_service.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/ai_message_content.dart';

class PickedMediaItem {
  final Uint8List bytes;
  final String name;
  final bool isVideo;

  PickedMediaItem({
    required this.bytes,
    required this.name,
    this.isVideo = false,
  });
}

class AIChatScreen extends StatefulWidget {
  final String threadId;
  const AIChatScreen({super.key, required this.threadId});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final UnifiedAIChatService _chatService = UnifiedAIChatService.instance;
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final ImagePicker _picker = ImagePicker();
  late stt.SpeechToText _speech;

  ConversationThread? _thread;
  List<ConversationThread> _threads = []; // All threads for sidebar
  bool _showSidebar = false; // Toggle sidebar
  bool _isLoading = true;
  bool _isSending = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  bool _webSearch = false;
  bool _showModelPicker = false;
  String? _activeModelId;
  List<PickedMediaItem> _pickedMediaList = [];
  Timer? _loadingTimer;

  // NEW: Continuous voice mode
  bool _continuousVoice = false;
  Timer? _continuousVoiceWatchdog;

  // NEW: Memory controls
  bool _threadMemoryEnabled = true;
  bool _chatMemoryEnabled = true;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
    _loadModel();
    _loadCredits(); // Force reload credits when chat opens
    _loadMemorySettings(); // NEW: Load memory settings

    // Initialize unified chat service
    _chatService.initialize().then((_) {
      _chatService.addListener(_onUpdated);
      _load();
    });
  }

  Future<void> _loadCredits() async {
    // Force reload credits from Firestore to show actual balance
    await CreditsService.instance.load(force: true);
  }

  @override
  void dispose() {
    _chatService.removeListener(_onUpdated);
    _input.dispose();
    _scroll.dispose();
    _speech.stop();
    _loadingTimer?.cancel();
    _continuousVoice = false; // NEW: Stop continuous voice
    _stopContinuousVoiceWatchdog(); // NEW: Stop watchdog
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadModel() async {
    final settings = await LocalStorageService.instance.getAISettings();
    final id = settings['selected_general_model'] as String? ??
        AIModelConfig.defaultGeneral.id;
    if (mounted) setState(() => _activeModelId = id);
  }

  String get _modelLabel {
    final cfg = AIModelConfig.getById(
        _activeModelId ?? AIModelConfig.defaultGeneral.id);
    return cfg?.displayName ?? 'VerveStride AI';
  }

  // NEW: Load memory settings
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

  // NEW: Save memory settings
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

  // NEW: Get memory status icon
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

  void _onUpdated() {
    if (!mounted) return;
    final allThreads = _chatService.getAllThreads();
    final updated =
        allThreads.where((t) => t.id == widget.threadId).firstOrNull;
    if (updated != null) {
      setState(() {
        _thread = updated;
        _threads = allThreads;
      });
      // During streaming, jump instantly to bottom; otherwise animate smoothly
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        final isNearBottom =
            _scroll.position.maxScrollExtent - _scroll.offset < 120;
        if (isNearBottom) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  Future<void> _load() async {
    await _chatService.switchToThread(widget.threadId);
    final allThreads = _chatService.getAllThreads();
    final thread = allThreads.where((t) => t.id == widget.threadId).firstOrNull;
    if (!mounted) return;
    setState(() {
      _thread = thread;
      _threads = allThreads; // Load all threads for sidebar
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  // ── Voice ──────────────────────────────────────────────────────────────────

  Future<void> _toggleVoice() async {
    // If listening, stop and optionally send
    if (_isListening) {
      await _speech.stop();
      if (mounted) {
        setState(() {
          _isListening = false;
          _continuousVoice = false; // Stop continuous mode
        });
        _stopContinuousVoiceWatchdog();
      }
      if (_input.text.trim().isNotEmpty) _send();
      return;
    }

    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Voice not available on this browser. Try Chrome.')));
      return;
    }

    // Start continuous voice mode
    setState(() {
      _isListening = true;
      _continuousVoice = true; // Enable continuous mode
    });
    _startContinuousVoiceWatchdog(); // Start watchdog
    _input.clear();

    await _startVoiceInput();
  }

  // NEW: Start voice input (for continuous mode)
  Future<void> _startVoiceInput() async {
    if (!_speechAvailable || _isListening && !_continuousVoice) return;

    setState(() => _isListening = true);

    try {
      await _speech.listen(
        onResult: (r) {
          if (!mounted) return;

          // Optimize text updates to reduce lag - only update if text changed
          final text = r.recognizedWords;
          if (text != _input.text) {
            _input.value = TextEditingValue(
              text: text,
              selection: TextSelection.collapsed(offset: text.length),
            );
          }

          // Auto-send when speech is finalized
          if (r.finalResult && text.trim().isNotEmpty) {
            _speech.stop();
            setState(() => _isListening = false);
            Future.delayed(const Duration(milliseconds: 50), _send);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(
            seconds: 5), // Wait 5 seconds of silence before stopping
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.confirmation,
      );
    } catch (e) {
      debugPrint('❌ Speech listen error: $e');
      if (mounted) {
        setState(() => _isListening = false);
        // Don't stop continuous mode on error - watchdog will restart
      }
    }
  }

  // NEW: Watchdog to keep continuous voice alive
  void _startContinuousVoiceWatchdog() {
    _continuousVoiceWatchdog?.cancel();
    _continuousVoiceWatchdog =
        Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || !_continuousVoice) {
        timer.cancel();
        return;
      }

      // If continuous voice is on but not listening and not sending, restart
      if (_continuousVoice && !_isListening && !_isSending) {
        debugPrint('🎤 Watchdog: Restarting voice input');
        _startVoiceInput().catchError((e) {
          debugPrint('⚠️ Watchdog restart failed: $e');
        });
      }
    });
  }

  // NEW: Stop watchdog
  void _stopContinuousVoiceWatchdog() {
    _continuousVoiceWatchdog?.cancel();
    _continuousVoiceWatchdog = null;
  }

  // ── Attachments ────────────────────────────────────────────────────────────

  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true, // Allow scrolling for smaller screens
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.photo_library_outlined,
                      color: AppColors.primary),
                  title: const Text('Photos & Videos',
                      style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: const Text(
                      'Pick multiple photos or videos from gallery',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickMedia();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.description_outlined,
                      color: Colors.orangeAccent),
                  title: const Text('Document / File',
                      style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: const Text('Pick PDF, DOCX, TXT, or other files',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickDocument();
                  },
                ),
                if (!kIsWeb)
                  ListTile(
                    leading: Icon(Icons.camera_alt_outlined,
                        color: AppColors.primary),
                    title: const Text('Take a Photo',
                        style: TextStyle(color: AppColors.textPrimary)),
                    onTap: () {
                      Navigator.pop(context);
                      _pickCameraPhoto();
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.videocam_outlined,
                      color: Colors.redAccent),
                  title: const Text('Live Video Session',
                      style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: const Text('Real-time AI analysis via camera',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, Routes.liveVideoSession);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.auto_awesome,
                      color: Colors.purpleAccent),
                  title: const Text('Generate Image',
                      style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: const Text('Create AI-generated images',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(context);
                    _promptImageGeneration();
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.video_library, color: Colors.pinkAccent),
                  title: const Text('Generate Video',
                      style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: const Text('Create AI-generated videos',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(context);
                    _promptVideoGeneration();
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.music_note, color: Colors.orangeAccent),
                  title: const Text('Generate Audio/Music',
                      style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: const Text('Create AI-generated music or sounds',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(context);
                    _promptAudioGeneration();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // NEW: Prompt image generation
  void _promptImageGeneration() {
    setState(() {
      _input.text = 'Create an image of ';
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
    });
  }

  // NEW: Prompt video generation
  void _promptVideoGeneration() {
    setState(() {
      _input.text = 'Create a video of ';
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
    });
  }

  // NEW: Prompt audio generation
  void _promptAudioGeneration() {
    setState(() {
      _input.text = 'Create music for ';
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
    });
  }

  Future<void> _pickMedia() async {
    try {
      final List<XFile> files = await _picker.pickMultipleMedia(
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (files.isEmpty || !mounted) return;

      for (final file in files) {
        final bytes = await file.readAsBytes();
        final name = file.name.toLowerCase();
        final isVideo = name.endsWith('.mp4') ||
            name.endsWith('.mov') ||
            name.endsWith('.avi') ||
            name.endsWith('.mkv') ||
            name.endsWith('.3gp') ||
            name.endsWith('.webm');
        setState(() {
          _pickedMediaList.add(PickedMediaItem(
            bytes: bytes,
            name: file.name,
            isVideo: isVideo,
          ));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not pick media: $e'),
              backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> _pickCameraPhoto() async {
    try {
      final x = await _picker.pickImage(
          source: ImageSource.camera, maxWidth: 1920, imageQuality: 85);
      if (x == null || !mounted) return;
      final bytes = await x.readAsBytes();
      setState(() {
        _pickedMediaList.add(PickedMediaItem(
          bytes: bytes,
          name: x.name,
          isVideo: false,
        ));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not capture image: $e'),
              backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'csv', 'xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty || !mounted) return;

      final file = result.files.first;
      final fileName = file.name;
      final fileSize = file.size;
      final fileExtension = file.extension ?? '';

      // Check file size (max 10MB)
      if (fileSize > 10 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File too large. Maximum size is 10MB.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Send message about the document
      final message =
          '📄 I\'ve attached a document: $fileName (${(fileSize / 1024).toStringAsFixed(1)} KB)\n\n'
          'Please analyze this $fileExtension file and tell me what you find.';

      _input.text = message;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document attached: $fileName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick document: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _analyzeMealImage() async {
    if (_pickedMediaList.isEmpty || _isSending) return;

    // Get first image from media list
    final firstImage = _pickedMediaList.firstWhere(
      (item) => !item.isVideo,
      orElse: () => _pickedMediaList.first,
    );

    setState(() {
      _isSending = true;
    });
    try {
      final result =
          await FirebaseAIService.instance.analyzeMealBytes(firstImage.bytes);
      final text = result == null
          ? '📷 Could not analyze this photo. Please try again.'
          : '📷 Meal analysis: ${result.name} (${result.mealType})\n'
              'Calories: ${result.calories} kcal · Protein: ${result.protein}g · '
              'Carbs: ${result.carbs}g · Fat: ${result.fat}g';
      await _chatService.sendMessage(text);

      // Clear media after analysis
      setState(() {
        _pickedMediaList.clear();
      });
    } catch (e) {
      await _chatService.sendMessage('📷 Meal analysis failed: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Download Chat ──────────────────────────────────────────────────────────

  Future<void> _downloadChat() async {
    if (_thread == null || _thread!.messages.isEmpty) return;

    try {
      final buffer = StringBuffer();
      buffer.writeln('VerveStride AI Chat Export');
      buffer.writeln('Thread: ${_thread!.title}');
      buffer.writeln('Date: ${DateTime.now().toString()}');
      buffer.writeln('=' * 50);
      buffer.writeln();

      for (final msg in _thread!.messages) {
        buffer.writeln(
            '${msg.isUser ? "You" : "AI"} (${msg.timestamp.toString().split('.')[0]}):');
        buffer.writeln(msg.content);
        buffer.writeln();
      }

      if (kIsWeb) {
        // Web: show snackbar — dart:html not available cross-platform
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Copy the chat text or use browser print to save.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Mobile/Desktop: save to app documents folder
        final dir = await getApplicationDocumentsDirectory();
        final path =
            '${dir.path}/vervestride_chat_${DateTime.now().millisecondsSinceEpoch}.txt';
        await XFile.fromData(
          Uint8List.fromList(buffer.toString().codeUnits),
          mimeType: 'text/plain',
        ).saveTo(path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Chat saved to documents folder.'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Chat downloaded!'),
              duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Download failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Send ───────────────────────────────────────────────────────────────────

  Future<void> _send() async {
    debugPrint('🔵 _send() called');
    final text = _input.text.trim();
    debugPrint('🔵 Message text: "$text"');
    debugPrint('🔵 _isSending: $_isSending');

    final hasMedia = _pickedMediaList.isNotEmpty;
    if (text.isEmpty && !hasMedia) {
      debugPrint('⚠️ Message and media are empty, not sending');
      return;
    }

    if (_isSending) {
      debugPrint('⚠️ Already sending, skipping');
      return;
    }

    // NEW: Check for "stop listening" command
    final lowerText = text.toLowerCase();
    if (lowerText.contains('stop listening') ||
        lowerText.contains('stop voice') ||
        lowerText == 'stop' && _continuousVoice) {
      debugPrint('🎤 Stop listening command detected');
      setState(() {
        _continuousVoice = false;
        _isListening = false;
      });
      _stopContinuousVoiceWatchdog();
      _input.clear();

      // Add confirmation message
      if (_thread != null) {
        final confirmMessage = ChatMessage(
          role: 'assistant',
          content: '✅ Voice mode stopped. Tap the mic button to start again.',
          timestamp: DateTime.now(),
        );
        setState(() {
          final mutableMessages = List<ChatMessage>.from(_thread!.messages);
          mutableMessages.add(confirmMessage);
          _thread = ConversationThread(
            id: _thread!.id,
            title: _thread!.title,
            createdAt: _thread!.createdAt,
            lastMessageAt: DateTime.now(),
            messages: mutableMessages,
            persona: _thread!.persona,
            userStyle: _thread!.userStyle,
          );
        });
      }
      return;
    }

    // NEW: Detect image generation request (flexible matching)
    if ((lowerText.contains('create') ||
            lowerText.contains('generate') ||
            lowerText.contains('make') ||
            lowerText.contains('draw')) &&
        (lowerText.contains('image') ||
            lowerText.contains('picture') ||
            lowerText.contains('photo') ||
            lowerText.contains('illustration') ||
            lowerText.contains('design') ||
            lowerText.contains('poster') ||
            lowerText.contains('logo') ||
            lowerText.contains('art'))) {
      await _handleImageGeneration(text);
      return;
    }

    // Check if user is responding to a pending action
    final lastMessage = _thread?.messages.lastOrNull;
    if (lastMessage != null && lastMessage.hasPendingAction) {
      final lowerReply = text.toLowerCase().trim();
      const yesWords = {
        'yes',
        'sure',
        'ok',
        'okay',
        'go',
        'go ahead',
        'continue',
        'proceed',
        'yep',
        'yeah',
        'yea'
      };
      const noWords = {
        'no',
        'nope',
        'cancel',
        'nevermind',
        'never mind',
        'stop',
        'dont',
        "don't",
        'nah'
      };

      if (yesWords.contains(lowerReply) || noWords.contains(lowerReply)) {
        _input.clear();

        // Add user reply message manually - no AI call
        final userReply = ChatMessage(
          role: 'user',
          content: text,
          timestamp: DateTime.now(),
        );

        setState(() {
          final mutableMessages = List<ChatMessage>.from(_thread!.messages)
            ..add(userReply);
          _thread = ConversationThread(
            id: _thread!.id,
            title: _thread!.title,
            createdAt: _thread!.createdAt,
            lastMessageAt: DateTime.now(),
            messages: mutableMessages,
            persona: _thread!.persona,
            userStyle: _thread!.userStyle,
          );
        });

        if (yesWords.contains(lowerReply)) {
          // User confirmed - execute the action
          debugPrint('✅ User confirmed: ${lastMessage.pendingAction}');
          switch (lastMessage.pendingAction) {
            case 'generate_image':
              await _executeImageGeneration(
                  lastMessage.pendingData!['prompt'] as String);
              break;
            case 'generate_video':
              await _executeVideoGeneration(
                lastMessage.pendingData!['prompt'] as String,
                lastMessage.pendingData!['duration'] as int? ?? 10,
              );
              break;
            case 'generate_audio':
              await _executeAudioGeneration(
                lastMessage.pendingData!['prompt'] as String,
                lastMessage.pendingData!['duration'] as int? ?? 30,
              );
              break;
          }
        } else {
          // User cancelled - add acknowledgment manually
          debugPrint('❌ User cancelled');
          final ack = ChatMessage(
            role: 'assistant',
            content: 'No problem! Let me know if you need anything else.',
            timestamp: DateTime.now(),
          );
          setState(() {
            final mutableMessages = List<ChatMessage>.from(_thread!.messages)
              ..add(ack);
            _thread = ConversationThread(
              id: _thread!.id,
              title: _thread!.title,
              createdAt: _thread!.createdAt,
              lastMessageAt: DateTime.now(),
              messages: mutableMessages,
              persona: _thread!.persona,
              userStyle: _thread!.userStyle,
            );
          });
          await _chatService.initialize();
        }
        return;
      }
    }

    // NEW: Detect video generation request
    if (lowerText.contains('create a video') ||
        lowerText.contains('generate a video') ||
        lowerText.contains('make a video')) {
      await _handleVideoGeneration(text);
      return;
    }

    // NEW: Detect audio generation request
    if (lowerText.contains('create music') ||
        lowerText.contains('generate music') ||
        lowerText.contains('make music') ||
        lowerText.contains('create audio') ||
        lowerText.contains('generate audio')) {
      await _handleAudioGeneration(text);
      return;
    }

    final mediaBytes = _pickedMediaList.map((m) => m.bytes).toList();
    final textToSend =
        (text.isEmpty && mediaBytes.isNotEmpty) ? 'Attached media files' : text;

    _input.clear();
    setState(() {
      _isSending = true;
      _pickedMediaList = [];
    });
    debugPrint('🔵 Set _isSending = true, starting streaming...');

    try {
      // Use streaming for typewriter effect
      await for (final chunk in _chatService.sendMessageStream(
        textToSend,
        useWebSearch: _webSearch,
        imageBytesList: mediaBytes.isNotEmpty ? mediaBytes : null,
      )) {
        // Each chunk updates the UI automatically through _onUpdated listener
        debugPrint('📝 Received chunk: ${chunk.length} chars');
      }
      debugPrint('✅ Streaming complete');

      // NEW: Restart voice for continuous mode
      if (_continuousVoice && mounted) {
        debugPrint('🎤 Continuous voice: waiting then restarting mic');
        // Speak response first
        if (_thread != null && _thread!.messages.isNotEmpty) {
          final lastMessage = _thread!.messages.last;
          if (lastMessage.isAssistant) {
            try {
              await FirebaseAIService.instance
                  .speakResponse(lastMessage.content);
            } catch (e) {
              debugPrint('⚠️ TTS error: $e');
            }
          }
        }

        // Then restart listening
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted && _continuousVoice && !_isListening) {
          await _startVoiceInput();
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error sending message: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing input: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Details',
              textColor: Colors.white,
              onPressed: () {
                debugPrint('Full error: $e\n$stackTrace');
              },
            ),
          ),
        );
      }

      // NEW: Keep continuous mode alive after error
      if (_continuousVoice && mounted) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted && _continuousVoice && !_isListening) {
          await _startVoiceInput();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        debugPrint('🔵 Set _isSending = false');
      }
    }
  }

  // NEW: Handle image generation with inline confirmation
  Future<void> _handleImageGeneration(String prompt) async {
    debugPrint('🎨 [AI Chat] Image generation requested: $prompt');
    _input.clear();
    if (_thread == null) return;

    // Build messages manually - NO AI call yet
    final creditsNeeded = AIFeatureCosts.imageGeneration;
    final userMessage = ChatMessage(
      role: 'user',
      content: prompt,
      timestamp: DateTime.now(),
    );
    final confirmMessage = ChatMessage(
      role: 'assistant',
      content:
          '⚠️ **Credit Cost Warning**\n\nGenerating this image will cost **$creditsNeeded credits**.\n\nIs it okay to proceed?',
      timestamp: DateTime.now(),
      pendingAction: 'generate_image',
      pendingData: {'prompt': prompt},
    );

    setState(() {
      final mutableMessages = List<ChatMessage>.from(_thread!.messages)
        ..add(userMessage)
        ..add(confirmMessage);
      _thread = ConversationThread(
        id: _thread!.id,
        title: _thread!.title,
        createdAt: _thread!.createdAt,
        lastMessageAt: DateTime.now(),
        messages: mutableMessages,
        persona: _thread!.persona,
        userStyle: _thread!.userStyle,
      );
    });

    // Persist only - no model call
    await _chatService.initialize();
  }

  // Execute image generation after confirmation
  Future<void> _executeImageGeneration(String prompt) async {
    debugPrint('🎨 [AI Chat] Executing image generation...');
    setState(() => _isSending = true);

    try {
      // Check credits
      final creditsNeeded = AIFeatureCosts.imageGeneration;
      if (!CreditsService.instance.hasCredits ||
          CreditsService.instance.availableCredits < creditsNeeded) {
        await _chatService.sendMessage(
            '❌ Insufficient credits. You need $creditsNeeded credits to generate an image.\n\n'
            'Tap the credits display in the top right to purchase more credits.');
        return;
      }

      // Deduct credits
      final success = await CreditsService.instance
          .useCredits(creditsNeeded, description: 'Image generation');

      if (!success) {
        await _chatService
            .sendMessage('❌ Failed to deduct credits. Please try again.');
        return;
      }

      debugPrint('🎨 [AI Chat] Calling FirebaseAIService.generateImage...');
      final imageBytes = await FirebaseAIService.instance.generateImage(prompt);
      debugPrint(
          '🎨 [AI Chat] Image generation result: ${imageBytes != null ? "${imageBytes.length} bytes" : "null"}');

      if (imageBytes != null) {
        final imageBase64 = base64Encode(imageBytes);
        debugPrint('🎨 [AI Chat] Base64 encoded: ${imageBase64.length} chars');

        final imageMessage = ChatMessage(
          role: 'assistant',
          content: '✨ Here\'s your generated image!',
          timestamp: DateTime.now(),
          imageBase64: imageBase64,
          creditsUsed: AIFeatureCosts.imageGeneration,
          preciseCredits: AIFeatureCosts.imageGeneration.toDouble(),
        );

        if (_thread != null) {
          _thread!.messages.add(imageMessage);
          _thread!.lastMessageAt = DateTime.now();
          setState(() {});

          // Save to persistent storage
          await _chatService.initialize();
        }
      } else {
        // Refund credits on failure
        await CreditsService.instance.refundCredits(creditsNeeded);
        debugPrint('❌ [AI Chat] Image generation returned null');
        await _chatService.sendMessage(
            '❌ Failed to generate image. Your credits have been refunded. Please try again.');
      }
    } catch (e) {
      // Refund credits on error
      await CreditsService.instance
          .refundCredits(AIFeatureCosts.imageGeneration);
      debugPrint('❌ [AI Chat] Image generation error: $e');
      await _chatService.sendMessage(
          '❌ Image generation error: $e\n\nYour credits have been refunded.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // NEW: Handle video generation with inline confirmation
  Future<void> _handleVideoGeneration(String prompt) async {
    debugPrint('🎬 [AI Chat] Video generation requested: $prompt');
    _input.clear();
    if (_thread == null) return;

    // Build messages manually - NO AI call yet
    final creditsNeeded = AIFeatureCosts.videoGeneration;
    final userMessage = ChatMessage(
      role: 'user',
      content: prompt,
      timestamp: DateTime.now(),
    );
    final confirmMessage = ChatMessage(
      role: 'assistant',
      content:
          '⚠️ **Credit Cost Warning**\n\nGenerating this video will cost **$creditsNeeded credits**.\n\nIs it okay to proceed?',
      timestamp: DateTime.now(),
      pendingAction: 'generate_video',
      pendingData: {'prompt': prompt, 'duration': 10},
    );

    setState(() {
      final mutableMessages = List<ChatMessage>.from(_thread!.messages)
        ..add(userMessage)
        ..add(confirmMessage);
      _thread = ConversationThread(
        id: _thread!.id,
        title: _thread!.title,
        createdAt: _thread!.createdAt,
        lastMessageAt: DateTime.now(),
        messages: mutableMessages,
        persona: _thread!.persona,
        userStyle: _thread!.userStyle,
      );
    });

    // Persist only - no model call
    await _chatService.initialize();
  }

  // Execute video generation after confirmation
  Future<void> _executeVideoGeneration(
      String prompt, int durationSeconds) async {
    debugPrint('🎬 [AI Chat] Executing video generation...');
    setState(() => _isSending = true);

    try {
      // Check credits
      final creditsNeeded = AIFeatureCosts.videoGeneration;
      if (!CreditsService.instance.hasCredits ||
          CreditsService.instance.availableCredits < creditsNeeded) {
        // Add error message manually
        final errorMsg = ChatMessage(
          role: 'assistant',
          content:
              '❌ Insufficient credits. You need $creditsNeeded credits to generate a video.\n\nTap the credits display in the top right to purchase more credits.',
          timestamp: DateTime.now(),
        );
        setState(() {
          final mutableMessages = List<ChatMessage>.from(_thread!.messages)
            ..add(errorMsg);
          _thread = ConversationThread(
            id: _thread!.id,
            title: _thread!.title,
            createdAt: _thread!.createdAt,
            lastMessageAt: DateTime.now(),
            messages: mutableMessages,
            persona: _thread!.persona,
            userStyle: _thread!.userStyle,
          );
        });
        await _chatService.initialize();
        return;
      }

      // Deduct credits
      final success = await CreditsService.instance
          .useCredits(creditsNeeded, description: 'Video generation');

      if (!success) {
        final errorMsg = ChatMessage(
          role: 'assistant',
          content: '❌ Failed to deduct credits. Please try again.',
          timestamp: DateTime.now(),
        );
        setState(() {
          final mutableMessages = List<ChatMessage>.from(_thread!.messages)
            ..add(errorMsg);
          _thread = ConversationThread(
            id: _thread!.id,
            title: _thread!.title,
            createdAt: _thread!.createdAt,
            lastMessageAt: DateTime.now(),
            messages: mutableMessages,
            persona: _thread!.persona,
            userStyle: _thread!.userStyle,
          );
        });
        await _chatService.initialize();
        return;
      }

      final videoUrl = await FirebaseAIService.instance.generateVideo(
        prompt,
        durationSeconds: durationSeconds,
      );

      if (videoUrl != null) {
        final videoMessage = ChatMessage(
          role: 'assistant',
          content: '✨ Here\'s your generated video!',
          timestamp: DateTime.now(),
          videoUrl: videoUrl,
          creditsUsed: AIFeatureCosts.videoGeneration,
          preciseCredits: AIFeatureCosts.videoGeneration.toDouble(),
        );

        if (_thread != null) {
          _thread!.messages.add(videoMessage);
          _thread!.lastMessageAt = DateTime.now();
          setState(() {});
          await _chatService.initialize();
        }
      } else {
        // Refund credits on failure
        await CreditsService.instance.refundCredits(creditsNeeded);
        final errorMsg = ChatMessage(
          role: 'assistant',
          content:
              '❌ Failed to generate video. Your credits have been refunded. Please try again.',
          timestamp: DateTime.now(),
        );
        setState(() {
          final mutableMessages = List<ChatMessage>.from(_thread!.messages)
            ..add(errorMsg);
          _thread = ConversationThread(
            id: _thread!.id,
            title: _thread!.title,
            createdAt: _thread!.createdAt,
            lastMessageAt: DateTime.now(),
            messages: mutableMessages,
            persona: _thread!.persona,
            userStyle: _thread!.userStyle,
          );
        });
        await _chatService.initialize();
      }
    } catch (e) {
      // Refund credits on error
      await CreditsService.instance
          .refundCredits(AIFeatureCosts.videoGeneration);
      debugPrint('❌ [AI Chat] Video generation error: $e');
      final errorMsg = ChatMessage(
        role: 'assistant',
        content:
            '❌ Video generation error: $e\n\nYour credits have been refunded.',
        timestamp: DateTime.now(),
      );
      setState(() {
        final mutableMessages = List<ChatMessage>.from(_thread!.messages)
          ..add(errorMsg);
        _thread = ConversationThread(
          id: _thread!.id,
          title: _thread!.title,
          createdAt: _thread!.createdAt,
          lastMessageAt: DateTime.now(),
          messages: mutableMessages,
          persona: _thread!.persona,
          userStyle: _thread!.userStyle,
        );
      });
      await _chatService.initialize();
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // NEW: Handle audio generation with inline confirmation
  Future<void> _handleAudioGeneration(String prompt) async {
    debugPrint('🎵 [AI Chat] Audio generation requested: $prompt');
    _input.clear();
    if (_thread == null) return;

    // Build messages manually - NO AI call yet
    final creditsNeeded = AIFeatureCosts.audioGeneration;
    final userMessage = ChatMessage(
      role: 'user',
      content: prompt,
      timestamp: DateTime.now(),
    );
    final confirmMessage = ChatMessage(
      role: 'assistant',
      content:
          '⚠️ **Credit Cost Warning**\n\nGenerating this audio will cost **$creditsNeeded credits**.\n\nIs it okay to proceed?',
      timestamp: DateTime.now(),
      pendingAction: 'generate_audio',
      pendingData: {'prompt': prompt, 'duration': 30},
    );

    setState(() {
      final mutableMessages = List<ChatMessage>.from(_thread!.messages)
        ..add(userMessage)
        ..add(confirmMessage);
      _thread = ConversationThread(
        id: _thread!.id,
        title: _thread!.title,
        createdAt: _thread!.createdAt,
        lastMessageAt: DateTime.now(),
        messages: mutableMessages,
        persona: _thread!.persona,
        userStyle: _thread!.userStyle,
      );
    });

    // Persist only - no model call
    await _chatService.initialize();
  }

  // Execute audio generation after confirmation
  Future<void> _executeAudioGeneration(
      String prompt, int durationSeconds) async {
    debugPrint('🎵 [AI Chat] Executing audio generation...');
    setState(() => _isSending = true);

    try {
      // Check credits
      final creditsNeeded = AIFeatureCosts.audioGeneration;
      if (!CreditsService.instance.hasCredits ||
          CreditsService.instance.availableCredits < creditsNeeded) {
        final errorMsg = ChatMessage(
          role: 'assistant',
          content:
              '❌ Insufficient credits. You need $creditsNeeded credits to generate audio.\n\nTap the credits display in the top right to purchase more credits.',
          timestamp: DateTime.now(),
        );
        setState(() {
          final mutableMessages = List<ChatMessage>.from(_thread!.messages)
            ..add(errorMsg);
          _thread = ConversationThread(
            id: _thread!.id,
            title: _thread!.title,
            createdAt: _thread!.createdAt,
            lastMessageAt: DateTime.now(),
            messages: mutableMessages,
            persona: _thread!.persona,
            userStyle: _thread!.userStyle,
          );
        });
        await _chatService.initialize();
        return;
      }

      // Deduct credits
      final success = await CreditsService.instance
          .useCredits(creditsNeeded, description: 'Audio generation');

      if (!success) {
        final errorMsg = ChatMessage(
          role: 'assistant',
          content: '❌ Failed to deduct credits. Please try again.',
          timestamp: DateTime.now(),
        );
        setState(() {
          final mutableMessages = List<ChatMessage>.from(_thread!.messages)
            ..add(errorMsg);
          _thread = ConversationThread(
            id: _thread!.id,
            title: _thread!.title,
            createdAt: _thread!.createdAt,
            lastMessageAt: DateTime.now(),
            messages: mutableMessages,
            persona: _thread!.persona,
            userStyle: _thread!.userStyle,
          );
        });
        await _chatService.initialize();
        return;
      }

      final audioUrl = await FirebaseAIService.instance.generateAudio(
        prompt,
        durationSeconds: durationSeconds,
      );

      if (audioUrl != null) {
        final audioMessage = ChatMessage(
          role: 'assistant',
          content: '✨ Here\'s your generated audio!',
          timestamp: DateTime.now(),
          audioUrl: audioUrl,
          creditsUsed: AIFeatureCosts.audioGeneration,
          preciseCredits: AIFeatureCosts.audioGeneration.toDouble(),
        );

        if (_thread != null) {
          _thread!.messages.add(audioMessage);
          _thread!.lastMessageAt = DateTime.now();
          setState(() {});
          await _chatService.initialize();
        }
      } else {
        // Refund credits on failure
        await CreditsService.instance.refundCredits(creditsNeeded);
        final errorMsg = ChatMessage(
          role: 'assistant',
          content:
              '❌ Failed to generate audio. Your credits have been refunded. Please try again.',
          timestamp: DateTime.now(),
        );
        setState(() {
          final mutableMessages = List<ChatMessage>.from(_thread!.messages)
            ..add(errorMsg);
          _thread = ConversationThread(
            id: _thread!.id,
            title: _thread!.title,
            createdAt: _thread!.createdAt,
            lastMessageAt: DateTime.now(),
            messages: mutableMessages,
            persona: _thread!.persona,
            userStyle: _thread!.userStyle,
          );
        });
        await _chatService.initialize();
      }
    } catch (e) {
      // Refund credits on error
      await CreditsService.instance
          .refundCredits(AIFeatureCosts.audioGeneration);
      debugPrint('❌ [AI Chat] Audio generation error: $e');
      final errorMsg = ChatMessage(
        role: 'assistant',
        content:
            '❌ Audio generation error: $e\n\nYour credits have been refunded.',
        timestamp: DateTime.now(),
      );
      setState(() {
        final mutableMessages = List<ChatMessage>.from(_thread!.messages)
          ..add(errorMsg);
        _thread = ConversationThread(
          id: _thread!.id,
          title: _thread!.title,
          createdAt: _thread!.createdAt,
          lastMessageAt: DateTime.now(),
          messages: mutableMessages,
          persona: _thread!.persona,
          userStyle: _thread!.userStyle,
        );
      });
      await _chatService.initialize();
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Conversations',
          onPressed: () => setState(() => _showSidebar = !_showSidebar),
        ),
        title: Text(_thread?.title ?? 'AI Chat',
            style: const TextStyle(fontSize: 16),
            overflow: TextOverflow.ellipsis),
        actions: [
          // Download chat button
          if (_thread != null && _thread!.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download_outlined, size: 20),
              tooltip: 'Download chat',
              onPressed: _downloadChat,
            ),
          // Credits chip
          ListenableBuilder(
            listenable: CreditsService.instance,
            builder: (_, __) {
              final c = CreditsService.instance.availableCredits;
              return Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Text(
                  '$c cr',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Model + web search toolbar
              _buildToolbar(),
              // Messages
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _thread == null || _thread!.messages.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            itemCount: _thread!.messages.length +
                                (_isSending &&
                                        (_thread!.messages.isEmpty ||
                                            _thread!.messages.last.isUser)
                                    ? 1
                                    : 0),
                            itemBuilder: (_, i) {
                              if (i == _thread!.messages.length) {
                                return const _ThinkingBubble();
                              }
                              return _Bubble(
                                message: _thread!.messages[i],
                              );
                            },
                          ),
              ),
              _buildInput(),
            ],
          ),
          // Sidebar overlay
          if (_showSidebar) _buildSidebar(),
          // Model picker overlay
          if (_showModelPicker) _buildModelPicker(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.smart_toy,
              size: 64, color: AppColors.primary.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('VerveStride AI',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Just start talking — I\'ll adapt to you',
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border:
            Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          // Model selector
          GestureDetector(
            onTap: () => setState(() => _showModelPicker = !_showModelPicker),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(_modelLabel,
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 2),
                  Icon(_showModelPicker ? Icons.expand_less : Icons.expand_more,
                      size: 14, color: AppColors.primary),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // NEW: Memory controls
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Memory Controls'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile(
                        title: const Text('Thread Memory',
                            style: TextStyle(fontSize: 14)),
                        subtitle: const Text('Remember this conversation',
                            style: TextStyle(fontSize: 11)),
                        value: _threadMemoryEnabled,
                        onChanged: (v) {
                          setState(() => _threadMemoryEnabled = v);
                          _saveMemorySettings();
                          Navigator.pop(context);
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Chat Memory',
                            style: TextStyle(fontSize: 14)),
                        subtitle: const Text('Remember across all chats',
                            style: TextStyle(fontSize: 11)),
                        value: _chatMemoryEnabled,
                        onChanged: (v) {
                          setState(() => _chatMemoryEnabled = v);
                          _saveMemorySettings();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_getMemoryStatusIcon(),
                      style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 2),
                  Icon(Icons.expand_more,
                      size: 12, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Web search toggle
          GestureDetector(
            onTap: () => setState(() => _webSearch = !_webSearch),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _webSearch
                    ? AppColors.secondary.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _webSearch
                      ? AppColors.secondary.withOpacity(0.4)
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.language,
                      size: 14,
                      color: _webSearch
                          ? AppColors.secondary
                          : AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text('Web',
                      style: TextStyle(
                          color: _webSearch
                              ? AppColors.secondary
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Positioned(
      top: 0,
      bottom: 0,
      left: 0,
      child: GestureDetector(
        onTap: () => setState(() => _showSidebar = false),
        child: Container(
          color: Colors.black54,
          child: GestureDetector(
            onTap: () {}, // Prevent closing when tapping sidebar
            child: Container(
              width: 280,
              color: AppColors.surface,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      border:
                          Border(bottom: BorderSide(color: AppColors.divider)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text('Conversations',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        Spacer(),
                        IconButton(
                          icon: const Icon(Icons.add, size: 20),
                          color: AppColors.primary,
                          tooltip: 'New conversation',
                          onPressed: () async {
                            // Create new thread using the service
                            final newThread =
                                await _chatService.createNewThread();
                            if (mounted) {
                              setState(() => _showSidebar = false);
                              Navigator.pushReplacementNamed(
                                context,
                                Routes.aiChat,
                                arguments: newThread.id,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  // Thread list
                  Expanded(
                    child: _threads.isEmpty
                        ? const Center(
                            child: Text('No conversations yet',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                          )
                        : ListView.builder(
                            itemCount: _threads.length,
                            itemBuilder: (_, i) {
                              final thread = _threads[i];
                              final isActive = thread.id == widget.threadId;
                              return ListTile(
                                dense: true,
                                selected: isActive,
                                selectedTileColor:
                                    AppColors.primary.withOpacity(0.1),
                                leading: Icon(
                                  Icons.chat_bubble_outline,
                                  size: 18,
                                  color: isActive
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                                title: Text(
                                  thread.title,
                                  style: TextStyle(
                                    color: isActive
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: thread.messages.isNotEmpty
                                    ? Text(
                                        thread.messages.last.content,
                                        style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : null,
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 16),
                                  color: AppColors.textSecondary,
                                  tooltip: 'Delete',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title:
                                            const Text('Delete conversation?'),
                                        content: const Text(
                                            'This will permanently delete this conversation.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Delete',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _chatService
                                          .deleteThread(thread.id);
                                      if (isActive && mounted) {
                                        // If deleting current thread, create new one
                                        final newThread = await _chatService
                                            .createNewThread();
                                        if (!mounted) return;
                                        Navigator.pushReplacementNamed(
                                          context,
                                          Routes.aiChat,
                                          arguments: newThread.id,
                                        );
                                      }
                                    }
                                  },
                                ),
                                onTap: () {
                                  if (!isActive) {
                                    setState(() => _showSidebar = false);
                                    Navigator.pushReplacementNamed(
                                      context,
                                      Routes.aiChat,
                                      arguments: thread.id,
                                    );
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModelPicker() {
    final models = AIModelConfig.allModels;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: () => setState(() => _showModelPicker = false),
        child: Container(
          color: Colors.black54,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Model',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  const SizedBox(height: 8),
                  ...models.map((m) => ListTile(
                        dense: true,
                        leading: Icon(
                          _activeModelId == m.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: _activeModelId == m.id
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: 18,
                        ),
                        title: Text(m.displayName,
                            style: TextStyle(
                                color: _activeModelId == m.id
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        subtitle: m.description.isNotEmpty
                            ? Text(m.description,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11))
                            : null,
                        onTap: () async {
                          setState(() {
                            _activeModelId = m.id;
                            _showModelPicker = false;
                          });
                          final settings = await LocalStorageService.instance
                              .getAISettings();
                          settings['selected_general_model'] = m.id;
                          await LocalStorageService.instance
                              .saveAISettings(settings);
                          FirebaseAIService.instance.resetModels();
                        },
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Media preview grid (multiple photos/videos)
          if (_pickedMediaList.isNotEmpty)
            Container(
              padding: const EdgeInsets.only(bottom: 8),
              constraints: const BoxConstraints(maxHeight: 120),
              child: Row(
                children: [
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _pickedMediaList.length,
                      itemBuilder: (context, index) {
                        final media = _pickedMediaList[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  media.bytes,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              if (media.isVideo)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.play_circle_outline,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _pickedMediaList.removeAt(index);
                                  }),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Add more button
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    color: AppColors.primary,
                    tooltip: 'Add more',
                    onPressed: _showAttachMenu,
                  ),
                ],
              ),
            ),
          Row(
            children: [
              // + Attach
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: AppColors.primary,
                tooltip: 'Attach',
                onPressed: _showAttachMenu,
              ),
              // Text field
              Expanded(
                child: TextField(
                  controller: _input,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 4),
              // Voice
              if (_speechAvailable)
                IconButton(
                  icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                  color: (_isListening || _continuousVoice)
                      ? Colors.redAccent
                      : AppColors.textSecondary,
                  tooltip: _isListening
                      ? (_continuousVoice ? 'Stop continuous voice' : 'Stop')
                      : 'Voice input',
                  onPressed: _toggleVoice,
                ),
              const SizedBox(width: 4),
              // Send
              Container(
                decoration: BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                child: IconButton(
                  onPressed: _isSending ? null : _send,
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Message bubble ─────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final ChatMessage message;

  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: message.content));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Copied'),
                        duration: Duration(seconds: 1)));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isUser ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                      border:
                          isUser ? null : Border.all(color: AppColors.divider),
                    ),
                    child: AIMessageContent(
                      content: message.content,
                      isUser: isUser,
                      message: message,
                    ),
                  ),
                ),
                // Credit label
                if (!isUser && message.preciseCredits != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 4),
                    child: Text(message.preciseCreditLabel,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 10)),
                  ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.accent,
              child: const Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Thinking indicator ─────────────────────────────────────────────────────────

class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();
  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _anim = Tween<double>(begin: 0, end: 3).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: AppColors.divider),
            ),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) {
                final step = _anim.value.floor();
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                      3,
                      (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary
                                  .withOpacity(i <= step ? 0.85 : 0.2),
                            ),
                          )),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
