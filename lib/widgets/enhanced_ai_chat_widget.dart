import 'package:flutter/material.dart';
import 'package:vervestride/core/app_theme.dart';
import 'package:vervestride/services/ai_chat_session_manager.dart';

/// Enhanced AI Chat Widget with proper session management
class EnhancedAIChatWidget extends StatefulWidget {
  final String? initialTopic;
  final String? persona;
  final bool showSessionControls;
  final Function(String)? onMessageSent;
  final Function(String)? onResponseReceived;

  const EnhancedAIChatWidget({
    super.key,
    this.initialTopic,
    this.persona,
    this.showSessionControls = true,
    this.onMessageSent,
    this.onResponseReceived,
  });

  @override
  State<EnhancedAIChatWidget> createState() => _EnhancedAIChatWidgetState();
}

class _EnhancedAIChatWidgetState extends State<EnhancedAIChatWidget> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AIChatSessionManager _sessionManager = AIChatSessionManager.instance;

  bool _isLoading = false;
  bool _useWebSearch = false;
  List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic> _sessionMetadata = {};
  String? _currentSessionId;

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeSession() async {
    try {
      _currentSessionId = await _sessionManager.startNewSession(
        topic: widget.initialTopic,
        persona: widget.persona,
      );
      
      if (mounted) {
        setState(() {
          _messages = _sessionManager.getSessionHistory();
          _sessionMetadata = _sessionManager.getSessionMetadata();
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to initialize AI chat session: $e');
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true;
      _messageController.clear();
    });

    try {
      widget.onMessageSent?.call(message);

      final response = await _sessionManager.sendMessage(
        message,
        persona: widget.persona,
        useWebSearch: _useWebSearch,
      );

      widget.onResponseReceived?.call(response);

      if (mounted) {
        setState(() {
          _messages = _sessionManager.getSessionHistory();
          _sessionMetadata = _sessionManager.getSessionMetadata();
        });
        
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _startNewSession() async {
    try {
      _currentSessionId = await _sessionManager.startNewSession(
        topic: 'New conversation',
        persona: widget.persona,
      );
      
      if (mounted) {
        setState(() {
          _messages = _sessionManager.getSessionHistory();
          _sessionMetadata = _sessionManager.getSessionMetadata();
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to start new session: $e');
    }
  }

  Future<void> _loadSession(String sessionId) async {
    try {
      final loaded = await _sessionManager.loadSession(sessionId);
      if (loaded && mounted) {
        setState(() {
          _currentSessionId = sessionId;
          _messages = _sessionManager.getSessionHistory();
          _sessionMetadata = _sessionManager.getSessionMetadata();
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('❌ Failed to load session: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showSessionSelector() async {
    final sessions = await _sessionManager.getAvailableSessions();
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: AppColors.primary),
                const SizedBox(width: 12),
                const Text(
                  'Chat Sessions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _startNewSession();
                  },
                  icon: Icon(Icons.add, color: AppColors.primary),
                  tooltip: 'New Session',
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (sessions.isEmpty)
              const Center(
                child: Text(
                  'No previous sessions',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              ...sessions.take(10).map((session) {
                final sessionId = session['session_id'] as String;
                final topic = session['topic'] as String? ?? 'Untitled';
                final messageCount = session['message_count'] as int? ?? 0;
                final lastActivity = DateTime.parse(session['last_activity'] as String);
                final isActive = sessionId == _currentSessionId;
                
                return ListTile(
                  leading: Icon(
                    isActive ? Icons.chat_bubble : Icons.chat_bubble_outline,
                    color: isActive ? AppColors.primary : AppColors.textSecondary,
                  ),
                  title: Text(
                    topic,
                    style: TextStyle(
                      color: isActive ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    '$messageCount messages • ${_formatTime(lastActivity)}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  trailing: isActive 
                      ? Icon(Icons.check_circle, color: AppColors.primary)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    if (!isActive) {
                      _loadSession(sessionId);
                    }
                  },
                );
              }),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return '${time.day}/${time.month}/${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Session controls
        if (widget.showSessionControls) _buildSessionControls(),
        
        // Messages list
        Expanded(
          child: _messages.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return _buildMessageBubble(message);
                  },
                ),
        ),
        
        // Input area
        _buildInputArea(),
      ],
    );
  }

  Widget _buildSessionControls() {
    final messageCount = _sessionMetadata['message_count'] as int? ?? 0;
    final topic = _sessionMetadata['topic'] as String? ?? 'Chat';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$topic • $messageCount messages',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          IconButton(
            onPressed: _showSessionSelector,
            icon: const Icon(Icons.history, size: 20),
            color: AppColors.textSecondary,
            tooltip: 'Session History',
          ),
          IconButton(
            onPressed: _startNewSession,
            icon: const Icon(Icons.add, size: 20),
            color: AppColors.textSecondary,
            tooltip: 'New Session',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Start a conversation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask me anything about wellbeing, productivity, or life!',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isUser = message['role'] == 'user';
    final content = message['content'] as String;
    final timestamp = DateTime.parse(message['timestamp'] as String);
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.primary.withOpacity(0.15)
              : AppColors.card.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUser
                ? AppColors.primary.withOpacity(0.3)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content,
              style: const TextStyle(
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(timestamp),
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        children: [
          // Web search toggle
          Row(
            children: [
              Icon(
                Icons.public,
                size: 16,
                color: _useWebSearch ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Web Search',
                style: TextStyle(
                  fontSize: 13,
                  color: _useWebSearch ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: _useWebSearch,
                onChanged: (value) => setState(() => _useWebSearch = value),
                activeThumbColor: AppColors.primary,
              ),
              const Spacer(),
              if (_isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Message input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Ask VerveStride AI...',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                    ),
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _isLoading ? null : _sendMessage(),
                  enabled: !_isLoading,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendMessage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
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