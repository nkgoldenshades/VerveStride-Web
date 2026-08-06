/// Model for conversation threads in AI chat
class ConversationThread {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime lastMessageAt;
  final List<ChatMessage> messages;
  String? persona;
  String? userStyle;

  ConversationThread({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastMessageAt,
    required this.messages,
    this.persona,
    this.userStyle,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'lastMessageAt': lastMessageAt.toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
        if (persona != null) 'persona': persona,
        if (userStyle != null) 'userStyle': userStyle,
      };

  factory ConversationThread.fromJson(Map<String, dynamic> json) {
    return ConversationThread(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastMessageAt: DateTime.parse(json['lastMessageAt'] as String),
      messages: List<ChatMessage>.from((json['messages'] as List)
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))),
      persona: json['persona'] as String?,
      userStyle: json['userStyle'] as String?,
    );
  }

  static String generateTitle(String firstMessage) {
    // Generate a concise title from the first message
    String cleaned = firstMessage.trim();

    // Remove question marks and exclamation marks
    cleaned = cleaned.replaceAll(RegExp(r'[?!]+$'), '');

    // Remove common question prefixes (case insensitive)
    cleaned = cleaned.replaceAll(
        RegExp(
            r'^(can you|could you|would you|will you|please|how do i|how to|what is|what are|whats|tell me about|tell me|show me|explain|help me with|help me|i want to|i need to|id like to)\s+',
            caseSensitive: false),
        '');

    // Capitalize first letter
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }

    // Truncate if too long
    if (cleaned.length <= 40) return cleaned;

    // Try to break at a word boundary
    final words = cleaned.split(' ');
    String title = '';
    for (final word in words) {
      if ((title + word).length > 37) break;
      title += (title.isEmpty ? '' : ' ') + word;
    }

    return title.isEmpty ? '${cleaned.substring(0, 37)}...' : '$title...';
  }
}

/// Individual chat message
class ChatMessage {
  final String role;
  String content; // Non-final to allow streaming updates
  final DateTime timestamp;
  final int? creditsUsed; // kept for backward compat
  final String? creditLabel;
  final int? elapsedMs;
  double?
      preciseCredits; // Non-final to allow attaching cost after stream completes
  final String? imageBase64; // Base64-encoded image for generated images
  final String? videoUrl; // URL for generated videos
  final String? audioUrl; // URL for generated audio
  final String?
      pendingAction; // NEW: Action awaiting user confirmation (e.g., 'generate_image')
  final Map<String, dynamic>? pendingData; // NEW: Data for pending action
  final List<String>? attachedImages; // NEW: Base64 images attached by user
  final List<String>? attachedVideos; // NEW: Base64 videos attached by user

  // Token tracking for transparency
  final int? inputTokens; // Tokens in user's message
  final int? outputTokens; // Tokens in AI's response

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.creditsUsed,
    this.creditLabel,
    this.elapsedMs,
    this.preciseCredits,
    this.imageBase64,
    this.videoUrl,
    this.audioUrl,
    this.pendingAction,
    this.pendingData,
    this.attachedImages,
    this.attachedVideos,
    this.inputTokens,
    this.outputTokens,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get hasPendingAction => pendingAction != null;

  String? get elapsedLabel {
    if (elapsedMs == null) return null;
    final secs = (elapsedMs! / 1000).round();
    return '${secs}s';
  }

  /// Precise credit label - ALWAYS show actual amount, never "< 0.001"
  String get preciseCreditLabel {
    final c = preciseCredits ?? (creditsUsed?.toDouble() ?? 0.0);
    if (c == 0) return '0 credits';
    if (c < 0.00001)
      return '${c.toStringAsFixed(6)} credits'; // Show actual tiny amounts
    if (c < 0.0001) return '${c.toStringAsFixed(5)} credits';
    if (c < 0.001) return '${c.toStringAsFixed(4)} credits';
    if (c < 1) return '${c.toStringAsFixed(3)} credits';
    return '${c.toStringAsFixed(2)} credits';
  }

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        if (creditsUsed != null) 'creditsUsed': creditsUsed,
        if (creditLabel != null) 'creditLabel': creditLabel,
        if (elapsedMs != null) 'elapsedMs': elapsedMs,
        if (preciseCredits != null) 'preciseCredits': preciseCredits,
        if (imageBase64 != null) 'imageBase64': imageBase64,
        if (videoUrl != null) 'videoUrl': videoUrl,
        if (audioUrl != null) 'audioUrl': audioUrl,
        if (pendingAction != null) 'pendingAction': pendingAction,
        if (pendingData != null) 'pendingData': pendingData,
        if (attachedImages != null) 'attachedImages': attachedImages,
        if (attachedVideos != null) 'attachedVideos': attachedVideos,
        if (inputTokens != null) 'inputTokens': inputTokens,
        if (outputTokens != null) 'outputTokens': outputTokens,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String,
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      creditsUsed: json['creditsUsed'] as int?,
      creditLabel: json['creditLabel'] as String?,
      elapsedMs: json['elapsedMs'] as int?,
      preciseCredits: (json['preciseCredits'] as num?)?.toDouble(),
      imageBase64: json['imageBase64'] as String?,
      videoUrl: json['videoUrl'] as String?,
      audioUrl: json['audioUrl'] as String?,
      pendingAction: json['pendingAction'] as String?,
      pendingData: json['pendingData'] as Map<String, dynamic>?,
      attachedImages: (json['attachedImages'] as List?)?.cast<String>(),
      attachedVideos: (json['attachedVideos'] as List?)?.cast<String>(),
      inputTokens: json['inputTokens'] as int?,
      outputTokens: json['outputTokens'] as int?,
    );
  }
}
