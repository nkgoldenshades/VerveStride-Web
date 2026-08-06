import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'local_storage_service.dart';
import 'firebase_ai_service.dart';

/// Enhanced AI Chat Session Manager
/// Provides proper session management, context calibration, and conversation continuity
class AIChatSessionManager {
  static final AIChatSessionManager instance = AIChatSessionManager._internal();
  factory AIChatSessionManager() => instance;
  AIChatSessionManager._internal();

  String? _currentSessionId;
  List<Map<String, dynamic>> _sessionHistory = [];
  Map<String, dynamic> _sessionMetadata = {};
  DateTime? _sessionStartTime;
  int _messageCount = 0;

  /// Session configuration
  static const int maxSessionMessages = 30; // Max messages per session
  static const int maxContextMessages = 12; // Messages sent as context
  static const Duration sessionTimeout =
      Duration(hours: 2); // Auto-expire sessions
  static const int maxSessionsStored = 10; // Max stored sessions

  /// Start a new chat session
  Future<String> startNewSession({
    String? topic,
    String? persona,
    Map<String, dynamic>? initialContext,
  }) async {
    _currentSessionId = _generateSessionId();
    _sessionHistory = [];
    _sessionStartTime = DateTime.now();
    _messageCount = 0;

    _sessionMetadata = {
      'session_id': _currentSessionId,
      'start_time': _sessionStartTime!.toIso8601String(),
      'topic': topic,
      'persona': persona,
      'initial_context': initialContext,
      'message_count': 0,
      'last_activity': _sessionStartTime!.toIso8601String(),
    };

    debugPrint('🎯 Started new AI chat session: $_currentSessionId');
    await _saveSession();
    return _currentSessionId!;
  }

  /// Continue existing session or start new one
  Future<String> ensureActiveSession() async {
    if (_currentSessionId == null || _isSessionExpired()) {
      return await startNewSession();
    }
    return _currentSessionId!;
  }

  /// Send message in current session with proper context management - STREAMING VERSION
  Stream<String> sendMessageStream(
    String message, {
    String? persona,
    String? userStyle,
    bool useWebSearch = false,
    Uint8List? imageBytes, // Single image support
    List<Uint8List>? imageBytesList, // Multiple images support
    bool threadMemoryEnabled = true, // NEW: Control thread memory
    bool chatMemoryEnabled = true, // NEW: Control chat memory
  }) async* {
    debugPrint('🟡 SessionManager.sendMessageStream() called - STREAMING');
    debugPrint(
        '🧠 Thread Memory: $threadMemoryEnabled, Chat Memory: $chatMemoryEnabled');
    await ensureActiveSession();

    // Add user message to session
    final userMessage = {
      'role': 'user',
      'content': message,
      'timestamp': DateTime.now().toIso8601String(),
      'message_id': _generateMessageId(),
    };

    _sessionHistory.add(userMessage);
    _messageCount++;

    try {
      // Build optimized context for AI (respecting memory settings)
      final context = _buildOptimizedContext(
        threadMemoryEnabled: threadMemoryEnabled,
        chatMemoryEnabled: chatMemoryEnabled,
      );
      debugPrint(
          '🟡 Context built with ${context.length} messages, calling FirebaseAIService.chatWithAIStream...');

      String fullResponse = '';

      // Stream response from AI
      await for (final chunk in FirebaseAIService.instance.chatWithAIStream(
        message,
        context: context,
        persona: persona,
        userStyle: userStyle,
        useWebSearch: useWebSearch,
        imageBytes: imageBytes, // Pass single image
        imageBytesList: imageBytesList, // Pass multiple images
      )) {
        fullResponse += chunk;
        yield chunk; // Stream to UI
      }

      // Add complete AI response to session
      final aiMessage = {
        'role': 'assistant',
        'content': fullResponse,
        'timestamp': DateTime.now().toIso8601String(),
        'message_id': _generateMessageId(),
        'context_used': context.length,
        'persona': persona,
        'web_search': useWebSearch,
      };

      _sessionHistory.add(aiMessage);
      _messageCount++;

      // Update session metadata
      _sessionMetadata['message_count'] = _messageCount;
      _sessionMetadata['last_activity'] = DateTime.now().toIso8601String();

      // Auto-rotate session if it gets too long
      if (_messageCount >= maxSessionMessages) {
        await _rotateSession();
      }

      await _saveSession();
    } catch (e) {
      debugPrint('❌ Session streaming error: $e');
      // Remove the user message if AI failed
      if (_sessionHistory.isNotEmpty && _sessionHistory.last == userMessage) {
        _sessionHistory.removeLast();
        _messageCount--;
      }

      // Provide error message
      if (e.toString().contains('timeout') ||
          e.toString().contains('timed out')) {
        yield '\n\n❌ Request timed out. Please try a shorter message or check your internet connection.';
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        yield '\n\n❌ Network error. Please check your internet connection and try again.';
      } else if (e.toString().contains('unauthenticated')) {
        yield '\n\n❌ Authentication error. Please log in again.';
      } else if (e.toString().contains('credits')) {
        yield '\n\n❌ Insufficient credits. Please purchase more credits to continue.';
      } else {
        yield '\n\n❌ Error: ${e.toString()}';
      }

      rethrow;
    }
  }

  /// Send message in current session with proper context management
  Future<String> sendMessage(
    String message, {
    String? persona,
    String? userStyle,
    bool useWebSearch = false,
    bool threadMemoryEnabled = true, // NEW: Control thread memory
    bool chatMemoryEnabled = true, // NEW: Control chat memory
  }) async {
    debugPrint('🟡 SessionManager.sendMessage() called');
    debugPrint(
        '🧠 Thread Memory: $threadMemoryEnabled, Chat Memory: $chatMemoryEnabled');
    await ensureActiveSession();
    debugPrint('🟡 Session ensured, building context...');

    // Add user message to session
    final userMessage = {
      'role': 'user',
      'content': message,
      'timestamp': DateTime.now().toIso8601String(),
      'message_id': _generateMessageId(),
    };

    _sessionHistory.add(userMessage);
    _messageCount++;

    try {
      // Build optimized context for AI (respecting memory settings)
      final context = _buildOptimizedContext(
        threadMemoryEnabled: threadMemoryEnabled,
        chatMemoryEnabled: chatMemoryEnabled,
      );
      debugPrint(
          '🟡 Context built with ${context.length} messages, calling FirebaseAIService.chatWithAI...');

      // Send to AI with session context
      final response = await FirebaseAIService.instance.chatWithAI(
        message,
        context: context,
        persona: persona,
        userStyle: userStyle,
        useWebSearch: useWebSearch,
      );

      // Add AI response to session
      final aiMessage = {
        'role': 'assistant',
        'content': response,
        'timestamp': DateTime.now().toIso8601String(),
        'message_id': _generateMessageId(),
        'context_used': context.length,
        'persona': persona,
        'web_search': useWebSearch,
      };

      _sessionHistory.add(aiMessage);
      _messageCount++;

      // Update session metadata
      _sessionMetadata['message_count'] = _messageCount;
      _sessionMetadata['last_activity'] = DateTime.now().toIso8601String();

      // Auto-rotate session if it gets too long
      if (_messageCount >= maxSessionMessages) {
        await _rotateSession();
      }

      await _saveSession();
      return response;
    } catch (e) {
      debugPrint('❌ Session message error: $e');
      // Remove the user message if AI failed
      if (_sessionHistory.isNotEmpty && _sessionHistory.last == userMessage) {
        _sessionHistory.removeLast();
        _messageCount--;
      }

      // Provide more specific error messages
      if (e.toString().contains('timeout') ||
          e.toString().contains('timed out')) {
        throw Exception(
            'Request timed out. Please try a shorter message or check your internet connection.');
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        throw Exception(
            'Network error. Please check your internet connection and try again.');
      } else if (e.toString().contains('unauthenticated')) {
        throw Exception('Authentication error. Please log in again.');
      } else if (e.toString().contains('credits')) {
        throw Exception(
            'Insufficient credits. Please purchase more credits to continue.');
      }

      rethrow;
    }
  }

  /// Build optimized context for AI requests
  /// Respects user memory settings:
  /// - threadMemoryEnabled: Include conversation history from current thread
  /// - chatMemoryEnabled: Include cross-session chat history
  List<Map<String, dynamic>> _buildOptimizedContext({
    bool threadMemoryEnabled = true,
    bool chatMemoryEnabled = true,
  }) {
    final context = <Map<String, dynamic>>[];

    // If no memory enabled, return empty context (fresh conversation)
    if (!threadMemoryEnabled && !chatMemoryEnabled) {
      debugPrint('🧠 Memory OFF - No context included (fresh conversation)');
      return context;
    }

    // Include session topic as initial context if available
    final topic = _sessionMetadata['topic'] as String?;
    if (topic != null && topic.isNotEmpty) {
      context.add({
        'role': 'user',
        'content': 'Session topic: $topic',
      });
    }

    // Get recent messages for context (exclude system messages)
    final recentMessages = _sessionHistory
        .where((msg) => msg['role'] == 'user' || msg['role'] == 'assistant')
        .toList();

    // Determine how much context to include based on memory settings
    int contextLimit = maxContextMessages;
    if (threadMemoryEnabled && !chatMemoryEnabled) {
      // Thread memory only - limit to current thread (already filtered)
      debugPrint(
          '🧵 Thread Memory ONLY - Including ${recentMessages.length} thread messages');
    } else if (!threadMemoryEnabled && chatMemoryEnabled) {
      // Chat memory only - include cross-session history (not implemented yet, uses current session)
      debugPrint('💬 Chat Memory ONLY - Including recent chat history');
      contextLimit = 5; // Reduced context for chat memory mode
    } else {
      // Both enabled - full memory
      debugPrint(
          '🧠 FULL Memory - Including up to $maxContextMessages messages');
    }

    // Take last N messages, but ensure we don't exceed context limit
    final contextMessages = recentMessages.length <= contextLimit
        ? recentMessages
        : recentMessages.sublist(recentMessages.length - contextLimit);

    // Convert to AI-compatible format
    for (final msg in contextMessages) {
      final role = msg['role'] as String;
      final content = msg['content'] as String;

      if (role == 'assistant') {
        context.add({'role': 'model', 'content': content});
      } else {
        context.add({'role': role, 'content': content});
      }
    }

    debugPrint('🧠 Built context with ${context.length} messages');
    return context;
  }

  /// Rotate session when it gets too long
  Future<void> _rotateSession() async {
    debugPrint('🔄 Rotating AI chat session (${_messageCount} messages)');

    // Save current session to history
    await _archiveCurrentSession();

    // Start new session with summary of previous
    final summary = _generateSessionSummary();
    await startNewSession(
      topic: 'Continued conversation',
      initialContext: {'previous_session_summary': summary},
    );
  }

  /// Generate summary of current session
  String _generateSessionSummary() {
    if (_sessionHistory.isEmpty) return 'Empty session';

    final userMessages = _sessionHistory
        .where((msg) => msg['role'] == 'user')
        .map((msg) => msg['content'] as String)
        .toList();

    final topics = <String>[];
    for (final message in userMessages.take(5)) {
      if (message.length > 10) {
        topics.add(message.substring(0, math.min(50, message.length)));
      }
    }

    return 'Previous topics discussed: ${topics.join(', ')}';
  }

  /// Archive current session to storage
  Future<void> _archiveCurrentSession() async {
    if (_currentSessionId == null || _sessionHistory.isEmpty) return;

    try {
      final sessions = await _getStoredSessions();

      final sessionData = {
        ..._sessionMetadata,
        'end_time': DateTime.now().toIso8601String(),
        'messages': _sessionHistory,
        'archived': true,
      };

      sessions[_currentSessionId!] = sessionData;

      // Keep only recent sessions
      if (sessions.length > maxSessionsStored) {
        final sortedSessions = sessions.entries.toList()
          ..sort((a, b) {
            final aTime = DateTime.parse(a.value['last_activity'] as String);
            final bTime = DateTime.parse(b.value['last_activity'] as String);
            return bTime.compareTo(aTime);
          });

        final recentSessions = Map<String, dynamic>.fromEntries(
          sortedSessions.take(maxSessionsStored),
        );

        await LocalStorageService.instance.saveAIChatSessions(recentSessions);
      } else {
        await LocalStorageService.instance.saveAIChatSessions(sessions);
      }

      debugPrint(
          '📁 Archived session $_currentSessionId with ${_sessionHistory.length} messages');
    } catch (e) {
      debugPrint('⚠️ Failed to archive session: $e');
    }
  }

  /// Save current session
  Future<void> _saveSession() async {
    if (_currentSessionId == null) return;

    try {
      final sessions = await _getStoredSessions();

      final sessionData = {
        ..._sessionMetadata,
        'messages': _sessionHistory,
        'archived': false,
      };

      sessions[_currentSessionId!] = sessionData;
      await LocalStorageService.instance.saveAIChatSessions(sessions);
    } catch (e) {
      debugPrint('⚠️ Failed to save session: $e');
    }
  }

  /// Get stored sessions
  Future<Map<String, dynamic>> _getStoredSessions() async {
    try {
      return await LocalStorageService.instance.getAIChatSessions();
    } catch (e) {
      debugPrint('⚠️ Failed to load sessions: $e');
      return {};
    }
  }

  /// Load existing session
  Future<bool> loadSession(String sessionId) async {
    try {
      final sessions = await _getStoredSessions();
      final sessionData = sessions[sessionId] as Map<String, dynamic>?;

      if (sessionData == null) return false;

      _currentSessionId = sessionId;
      _sessionMetadata = Map<String, dynamic>.from(sessionData);
      _sessionHistory =
          List<Map<String, dynamic>>.from(sessionData['messages'] ?? []);
      _messageCount = _sessionHistory.length;
      _sessionStartTime = DateTime.parse(sessionData['start_time'] as String);

      debugPrint(
          '📂 Loaded session $sessionId with ${_sessionHistory.length} messages');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to load session $sessionId: $e');
      return false;
    }
  }

  /// Get session history for UI display
  List<Map<String, dynamic>> getSessionHistory() {
    return List<Map<String, dynamic>>.from(_sessionHistory);
  }

  /// Get session metadata
  Map<String, dynamic> getSessionMetadata() {
    return Map<String, dynamic>.from(_sessionMetadata);
  }

  /// Clear current session
  Future<void> clearCurrentSession() async {
    if (_currentSessionId != null) {
      await _archiveCurrentSession();
    }

    _currentSessionId = null;
    _sessionHistory = [];
    _sessionMetadata = {};
    _sessionStartTime = null;
    _messageCount = 0;

    debugPrint('🗑️ Cleared current AI chat session');
  }

  /// Get list of available sessions
  Future<List<Map<String, dynamic>>> getAvailableSessions() async {
    try {
      final sessions = await _getStoredSessions();

      return sessions.entries
          .map((entry) => {
                'session_id': entry.key,
                ...entry.value as Map<String, dynamic>,
              })
          .toList()
        ..sort((a, b) {
          final aTime = DateTime.parse(a['last_activity'] as String);
          final bTime = DateTime.parse(b['last_activity'] as String);
          return bTime.compareTo(aTime);
        });
    } catch (e) {
      debugPrint('❌ Failed to get available sessions: $e');
      return [];
    }
  }

  /// Delete a session
  Future<void> deleteSession(String sessionId) async {
    try {
      final sessions = await _getStoredSessions();
      sessions.remove(sessionId);
      await LocalStorageService.instance.saveAIChatSessions(sessions);

      if (_currentSessionId == sessionId) {
        _currentSessionId = null;
        _sessionHistory = [];
        _sessionMetadata = {};
        _sessionStartTime = null;
        _messageCount = 0;
      }

      debugPrint('🗑️ Deleted session $sessionId');
    } catch (e) {
      debugPrint('❌ Failed to delete session $sessionId: $e');
    }
  }

  /// Check if current session is expired
  bool _isSessionExpired() {
    if (_sessionStartTime == null) return true;

    final now = DateTime.now();
    final lastActivity = DateTime.parse(
        _sessionMetadata['last_activity'] as String? ??
            _sessionStartTime!.toIso8601String());

    return now.difference(lastActivity) > sessionTimeout;
  }

  /// Generate unique session ID
  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'session_${timestamp}_$random';
  }

  /// Generate unique message ID
  String _generateMessageId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 1000).toString().padLeft(3, '0');
    return 'msg_${timestamp}_$random';
  }

  /// Get current session ID
  String? get currentSessionId => _currentSessionId;

  /// Get message count in current session
  int get messageCount => _messageCount;

  /// Check if session is active
  bool get hasActiveSession =>
      _currentSessionId != null && !_isSessionExpired();
}
