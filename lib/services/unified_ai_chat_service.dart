import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'local_storage_service.dart';
import 'ai_chat_session_manager.dart';
import '../models/conversation_thread.dart';

/// Unified AI Chat Service
/// Connects floating AI assistant and settings chat to share the same conversation history
class UnifiedAIChatService {
  static final UnifiedAIChatService instance = UnifiedAIChatService._internal();
  factory UnifiedAIChatService() => instance;
  UnifiedAIChatService._internal();

  final AIChatSessionManager _sessionManager = AIChatSessionManager.instance;

  // Current active conversation
  ConversationThread? _activeThread;
  List<ConversationThread> _allThreads = [];

  // Shared processing state (so both Floating AI and Settings show same loading state)
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  // Listeners for UI updates
  final List<VoidCallback> _listeners = [];

  /// Initialize the unified chat service
  Future<void> initialize() async {
    await _loadThreads();
    await _migrateOldChatHistory();
  }

  /// Add listener for chat updates
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Remove listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners of changes
  void _notifyListeners() {
    for (final listener in _listeners) {
      try {
        listener();
      } catch (e) {
        debugPrint('Error in chat listener: $e');
      }
    }
  }

  /// Get or create active thread
  Future<ConversationThread> getActiveThread() async {
    if (_activeThread == null) {
      await _createNewThread();
    }
    return _activeThread!;
  }

  /// Create a new conversation thread
  Future<ConversationThread> _createNewThread() async {
    final thread = ConversationThread(
      id: 'thread_${DateTime.now().millisecondsSinceEpoch}',
      title: 'New Conversation',
      createdAt: DateTime.now(),
      lastMessageAt: DateTime.now(),
      messages: [],
    );

    _activeThread = thread;
    _allThreads.insert(0, thread);

    await _saveThreads();
    _notifyListeners();

    debugPrint('🧵 Created new unified thread: ${thread.id}');
    return thread;
  }

  /// Create a new conversation thread (public method for UI)
  Future<ConversationThread> createNewThread() async {
    debugPrint('🧵 PUBLIC createNewThread() called');
    final result = await _createNewThread();
    debugPrint(
      '🧵 PUBLIC createNewThread() completed, returning thread: ${result.id}',
    );
    return result;
  }

  /// Send message in active thread - STREAMING VERSION (typewriter effect)
  Stream<String> sendMessageStream(
    String message, {
    String? persona,
    String? userStyle,
    bool useWebSearch = false,
    Uint8List? imageBytes, // Single image support
    List<Uint8List>? imageBytesList, // Multiple images support
  }) async* {
    debugPrint(
      '🟢 UnifiedAIChatService.sendMessageStream() called - STREAMING',
    );

    // Set processing state so both UIs show loading
    _isProcessing = true;
    _notifyListeners();

    final thread = await getActiveThread();

    // Check if this is the first message
    final isFirstMessage = thread.messages.isEmpty;

    // Add user message to thread
    // Convert attached images to base64 for storage
    List<String>? attachedImagesBase64;
    if (imageBytesList != null && imageBytesList.isNotEmpty) {
      attachedImagesBase64 = imageBytesList
          .map((bytes) => base64Encode(bytes))
          .toList();
    } else if (imageBytes != null) {
      attachedImagesBase64 = [base64Encode(imageBytes)];
    }

    final userMessage = ChatMessage(
      role: 'user',
      content: message,
      timestamp: DateTime.now(),
      attachedImages: attachedImagesBase64,
    );

    thread.messages.add(userMessage);
    thread.lastMessageAt = DateTime.now();

    // Set temporary title immediately for UI
    if (isFirstMessage) {
      thread.title = _generateThreadTitle(message);
      _notifyListeners();
    }

    // Add empty AI message that will be filled as we stream
    final aiMessage = ChatMessage(
      role: 'assistant',
      content: '',
      timestamp: DateTime.now(),
    );
    thread.messages.add(aiMessage);

    // Notify UI that messages were added
    _notifyListeners();

    try {
      String fullResponse = '';

      // Stream response from session manager (with memory settings)
      final settings = await LocalStorageService.instance.getAISettings();
      final threadMemoryEnabled =
          settings['thread_memory_enabled'] as bool? ?? true;
      final chatMemoryEnabled =
          settings['chat_memory_enabled'] as bool? ?? true;
      debugPrint(
        '🧠 Memory settings: Thread=$threadMemoryEnabled, Chat=$chatMemoryEnabled',
      );

      await for (final chunk in _sessionManager.sendMessageStream(
        message,
        persona: persona,
        userStyle: userStyle,
        useWebSearch: useWebSearch,
        imageBytes: imageBytes, // Pass single image
        imageBytesList: imageBytesList, // Pass multiple images
        threadMemoryEnabled: threadMemoryEnabled, // Pass memory settings
        chatMemoryEnabled: chatMemoryEnabled, // Pass memory settings
      )) {
        fullResponse += chunk;

        // Update the AI message content in real-time
        aiMessage.content = fullResponse;
        thread.lastMessageAt = DateTime.now();

        // Notify UI to update (typewriter effect!)
        _notifyListeners();

        yield chunk; // Also yield for any direct listeners
      }

      // Generate smart AI title in background if first message
      if (isFirstMessage && fullResponse.isNotEmpty) {
        _generateSmartTitle(thread, message, fullResponse);
      }

      // Note: Credit cost tracking moved to FirebaseAIService
      // Credits are deducted automatically during AI calls

      // Final save
      await _saveThreads();

      // Clear processing state
      _isProcessing = false;
      _notifyListeners();
    } catch (e) {
      debugPrint('❌ Error in sendMessageStream: $e');
      // Remove user message if AI failed
      if (thread.messages.length >= 2) {
        thread.messages.removeLast(); // Remove AI message
        thread.messages.removeLast(); // Remove user message
      }

      // Add error message to thread
      final errorMessage = ChatMessage(
        role: 'assistant',
        content:
            '❌ Error processing your message: ${e.toString()}\n\nPlease try again or check your internet connection.',
        timestamp: DateTime.now(),
      );
      thread.messages.add(errorMessage);
      thread.lastMessageAt = DateTime.now();

      await _saveThreads();

      // Clear processing state even on error
      _isProcessing = false;
      _notifyListeners();

      rethrow;
    }
  }

  /// Send message in active thread
  Future<String> sendMessage(
    String message, {
    String? persona,
    String? userStyle,
    bool useWebSearch = false,
  }) async {
    debugPrint('🟢 UnifiedAIChatService.sendMessage() called');
    debugPrint('🟢 Message: "$message"');
    debugPrint('🟢 useWebSearch: $useWebSearch');

    // Set processing state so both UIs show loading
    _isProcessing = true;
    _notifyListeners();

    final thread = await getActiveThread();
    debugPrint('🟢 Active thread: ${thread.id}');

    // Check if this is the first message
    final isFirstMessage = thread.messages.isEmpty;

    // Add user message to thread
    final userMessage = ChatMessage(
      role: 'user',
      content: message,
      timestamp: DateTime.now(),
    );

    thread.messages.add(userMessage);
    thread.lastMessageAt = DateTime.now();

    // Set temporary title immediately for UI
    if (isFirstMessage) {
      thread.title = _generateThreadTitle(message);
      debugPrint('🟢 Set temporary thread title: ${thread.title}');
      _notifyListeners();
    }

    debugPrint('🟢 Calling session manager...');

    try {
      // Load memory settings
      final settings = await LocalStorageService.instance.getAISettings();
      final threadMemoryEnabled =
          settings['thread_memory_enabled'] as bool? ?? true;
      final chatMemoryEnabled =
          settings['chat_memory_enabled'] as bool? ?? true;
      debugPrint(
        '🧠 Memory settings: Thread=$threadMemoryEnabled, Chat=$chatMemoryEnabled',
      );

      // Use session manager for AI response (with memory settings)
      final response = await _sessionManager.sendMessage(
        message,
        persona: persona,
        userStyle: userStyle,
        useWebSearch: useWebSearch,
        threadMemoryEnabled: threadMemoryEnabled, // Pass memory settings
        chatMemoryEnabled: chatMemoryEnabled, // Pass memory settings
      );

      debugPrint('✅ Got response from session manager');

      // Add AI response to thread
      final aiMessage = ChatMessage(
        role: 'assistant',
        content: response,
        timestamp: DateTime.now(),
      );

      thread.messages.add(aiMessage);
      thread.lastMessageAt = DateTime.now();

      // Generate smart AI title in background if first message
      if (isFirstMessage) {
        _generateSmartTitle(thread, message, response);
      }

      // Save and notify
      await _saveThreads();

      // Clear processing state
      _isProcessing = false;
      _notifyListeners();

      debugPrint('✅ Message processing complete');
      return response;
    } catch (e) {
      debugPrint('❌ Error in sendMessage: $e');
      // Remove user message if AI failed
      if (thread.messages.isNotEmpty && thread.messages.last == userMessage) {
        thread.messages.removeLast();
      }

      // Add error message to thread for user visibility
      final errorMessage = ChatMessage(
        role: 'assistant',
        content:
            '❌ Error processing your message: ${e.toString()}\n\nPlease try again or check your internet connection.',
        timestamp: DateTime.now(),
      );
      thread.messages.add(errorMessage);
      thread.lastMessageAt = DateTime.now();

      await _saveThreads();

      // Clear processing state even on error
      _isProcessing = false;
      _notifyListeners();

      rethrow;
    }
  }

  /// Switch to a specific thread
  Future<void> switchToThread(String threadId) async {
    final thread = _allThreads.firstWhere(
      (t) => t.id == threadId,
      orElse: () => throw Exception('Thread not found: $threadId'),
    );

    _activeThread = thread;
    await _sessionManager.clearCurrentSession();
    _notifyListeners();
    debugPrint('🔄 Switched to thread: $threadId');
  }

  /// Get all conversation threads
  List<ConversationThread> getAllThreads() {
    return List.from(_allThreads);
  }

  /// Get active thread (nullable)
  ConversationThread? get activeThread => _activeThread;

  /// Delete a thread
  Future<void> deleteThread(String threadId) async {
    _allThreads.removeWhere((t) => t.id == threadId);

    if (_activeThread?.id == threadId) {
      _activeThread = null;
      await _sessionManager.clearCurrentSession();
    }

    await _saveThreads();
    _notifyListeners();
    debugPrint('🗑️ Deleted thread: $threadId');
  }

  /// Clear all chat history
  Future<void> clearAllHistory() async {
    _allThreads.clear();
    _activeThread = null;
    await _sessionManager.clearCurrentSession();
    await _saveThreads();

    // Also clear legacy chat history
    await LocalStorageService.instance.clearAIChatData();

    _notifyListeners();
    debugPrint('🗑️ Cleared all chat history');
  }

  /// Get messages for current thread (compatible with old format)
  List<Map<String, dynamic>> getCurrentMessages() {
    if (_activeThread == null) return [];
    return _activeThread!.messages
        .map(
          (msg) => {
            'role': msg.role,
            'content': msg.content,
            'timestamp': msg.timestamp.toIso8601String(),
          },
        )
        .toList();
  }

  /// Build context for AI (compatible with old format)
  List<Map<String, dynamic>> buildChatContext({int maxMessages = 10}) {
    final messages = getCurrentMessages();
    if (messages.isEmpty) return [];

    // Take recent messages for context
    final recentMessages = messages.length <= maxMessages
        ? messages
        : messages.sublist(messages.length - maxMessages);

    // Convert to AI-compatible format
    final context = <Map<String, dynamic>>[];
    for (final msg in recentMessages) {
      final role = msg['role'] as String;
      final content = msg['content'] as String;

      if (role == 'assistant') {
        context.add({'role': 'model', 'content': content});
      } else {
        context.add({'role': role, 'content': content});
      }
    }

    return context;
  }

  /// Save threads to storage
  Future<void> _saveThreads() async {
    debugPrint(
      '💾 _saveThreads() called - attempting to save ${_allThreads.length} threads',
    );
    try {
      final threadsJson = _allThreads.map((t) => t.toJson()).toList();
      debugPrint('💾 Converted ${threadsJson.length} threads to JSON');

      final settings =
          await LocalStorageService.instance.getAppSettings() ?? {};
      debugPrint('💾 Got app settings, adding threads...');

      settings['unified_ai_threads'] = threadsJson;

      debugPrint('💾 Calling saveAppSettings...');
      await LocalStorageService.instance.saveAppSettings(settings);

      debugPrint(
        '💾 ✅ Saved ${_allThreads.length} unified threads successfully',
      );
    } catch (e) {
      debugPrint('❌ Failed to save threads: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  /// Load threads from storage
  Future<void> _loadThreads() async {
    debugPrint(
      '📂 _loadThreads() called - attempting to load threads from storage',
    );
    try {
      final settings = await LocalStorageService.instance.getAppSettings();
      debugPrint('📂 Got app settings: ${settings?.keys.toList()}');

      final threadsJson = settings?['unified_ai_threads'] as List?;
      debugPrint('📂 Found threads JSON: ${threadsJson?.length ?? 0} threads');

      if (threadsJson != null && threadsJson.isNotEmpty) {
        _allThreads = threadsJson
            .map(
              (json) =>
                  ConversationThread.fromJson(json as Map<String, dynamic>),
            )
            .toList();

        debugPrint('📂 Parsed ${_allThreads.length} threads');

        // Sort by last message time
        _allThreads.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

        // Set most recent as active
        if (_allThreads.isNotEmpty) {
          _activeThread = _allThreads.first;
          debugPrint(
            '📂 Set active thread: ${_activeThread!.id} (${_activeThread!.messages.length} messages)',
          );
        }

        debugPrint(
          '📂 ✅ Loaded ${_allThreads.length} unified threads successfully',
        );
      } else {
        debugPrint('📂 No threads found in storage');
      }
    } catch (e) {
      debugPrint('❌ Failed to load threads: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  /// Migrate old chat history to new unified system
  Future<void> _migrateOldChatHistory() async {
    try {
      // Check if we already migrated
      final settings = await LocalStorageService.instance.getAppSettings();
      if (settings?['chat_migrated'] == true) return;

      // Migrate from AI settings chat history
      final oldHistory = await LocalStorageService.instance.getAIChatHistory();
      if (oldHistory.isNotEmpty) {
        debugPrint('🔄 Migrating ${oldHistory.length} old chat messages');

        // Convert old format to ChatMessage objects
        final migratedMessages = oldHistory
            .map(
              (msg) => ChatMessage(
                role: msg['role'] as String? ?? 'user',
                content: msg['content'] as String? ?? '',
                timestamp:
                    DateTime.tryParse(msg['created_at'] as String? ?? '') ??
                    DateTime.now(),
              ),
            )
            .toList();

        final migratedThread = ConversationThread(
          id: 'migrated_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Previous Conversations',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          lastMessageAt: DateTime.now().subtract(const Duration(hours: 1)),
          messages: migratedMessages,
        );

        _allThreads.add(migratedThread);
        await _saveThreads();

        debugPrint('✅ Migrated old chat history to unified system');
      }

      // Migrate from floating AI threads
      final floatingThreads = settings?['ai_conversation_threads'] as List?;
      if (floatingThreads != null && floatingThreads.isNotEmpty) {
        debugPrint(
          '🔄 Migrating ${floatingThreads.length} floating AI threads',
        );

        for (final threadJson in floatingThreads) {
          try {
            final thread = ConversationThread.fromJson(
              threadJson as Map<String, dynamic>,
            );
            // Avoid duplicates
            if (!_allThreads.any((t) => t.id == thread.id)) {
              _allThreads.add(thread);
            }
          } catch (e) {
            debugPrint('⚠️ Failed to migrate thread: $e');
          }
        }

        await _saveThreads();
        debugPrint('✅ Migrated floating AI threads to unified system');
      }

      // Mark as migrated
      final newSettings =
          await LocalStorageService.instance.getAppSettings() ?? {};
      newSettings['chat_migrated'] = true;
      await LocalStorageService.instance.saveAppSettings(newSettings);
    } catch (e) {
      debugPrint('❌ Migration failed: $e');
    }
  }

  /// Generate thread title from first message (temporary, until AI generates better one)
  String _generateThreadTitle(String message) {
    // Clean and truncate message for title
    final cleaned = message.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.length <= 30) return cleaned;

    // Find a good break point
    final words = cleaned.split(' ');
    String title = '';
    for (final word in words) {
      if ((title + word).length > 27) break;
      title += (title.isEmpty ? '' : ' ') + word;
    }

    return title.isEmpty ? '${cleaned.substring(0, 27)}...' : '$title...';
  }

  /// Generate smart AI title in background (like ChatGPT)
  void _generateSmartTitle(
    ConversationThread thread,
    String userMessage,
    String aiResponse,
  ) async {
    try {
      debugPrint('🏷️ Generating smart AI title for thread ${thread.id}...');

      // Create a focused prompt for title generation
      final titlePrompt =
          '''Generate a short, descriptive title (3-5 words max) for this conversation:

User: ${userMessage.length > 100 ? userMessage.substring(0, 100) : userMessage}
Assistant: ${aiResponse.length > 150 ? aiResponse.substring(0, 150) : aiResponse}

Reply with ONLY the title, nothing else. No quotes, no punctuation at the end.''';

      // Use a separate AI call for title (runs in background)
      final generatedTitle = await _sessionManager.sendMessage(
        titlePrompt,
        persona: null,
        userStyle: null,
        useWebSearch: false,
      );

      // Clean up the generated title
      String cleanTitle = generatedTitle
          .trim()
          .replaceAll(RegExp(r'^["\x27]+|["\x27]+$'), '') // Remove quotes
          .replaceAll(RegExp(r'[.!?]+$'), '') // Remove ending punctuation
          .replaceAll(RegExp(r'\n.*'), '') // Take only first line
          .trim();

      // Capitalize first letter
      if (cleanTitle.isNotEmpty) {
        cleanTitle = cleanTitle[0].toUpperCase() + cleanTitle.substring(1);
      }

      // Limit length
      if (cleanTitle.length > 40) {
        cleanTitle = '${cleanTitle.substring(0, 37)}...';
      }

      // Update thread title if valid
      if (cleanTitle.isNotEmpty &&
          cleanTitle.length > 3 &&
          cleanTitle.split(' ').length <= 8) {
        thread.title = cleanTitle;
        debugPrint('🏷️ ✅ Generated smart title: "$cleanTitle"');
        await _saveThreads();
        _notifyListeners();
      } else {
        debugPrint('⚠️ Generated title invalid, keeping temporary title');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to generate smart title: $e');
      // Keep the temporary title if AI generation fails
    }
  }

  /// Export all chat data
  Future<Map<String, dynamic>> exportAllData() async {
    return {
      'unified_threads': _allThreads.map((t) => t.toJson()).toList(),
      'active_thread_id': _activeThread?.id,
      'export_timestamp': DateTime.now().toIso8601String(),
      'version': '1.0',
    };
  }

  /// Import chat data
  Future<void> importData(Map<String, dynamic> data) async {
    try {
      final threadsData = data['unified_threads'] as List?;
      if (threadsData != null) {
        _allThreads = threadsData
            .map(
              (json) =>
                  ConversationThread.fromJson(json as Map<String, dynamic>),
            )
            .toList();

        final activeThreadId = data['active_thread_id'] as String?;
        if (activeThreadId != null) {
          try {
            _activeThread = _allThreads.firstWhere(
              (t) => t.id == activeThreadId,
            );
          } catch (e) {
            _activeThread = _allThreads.isNotEmpty ? _allThreads.first : null;
          }
        } else {
          _activeThread = _allThreads.isNotEmpty ? _allThreads.first : null;
        }

        // Create new thread if none exists
        if (_activeThread == null && _allThreads.isEmpty) {
          await _createNewThread();
        }

        await _saveThreads();
        _notifyListeners();
        debugPrint('📥 Imported ${_allThreads.length} chat threads');
      }
    } catch (e) {
      debugPrint('❌ Import failed: $e');
      rethrow;
    }
  }
}
