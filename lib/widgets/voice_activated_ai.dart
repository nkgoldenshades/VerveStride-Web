import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:vervestride/core/app_theme.dart';
import 'package:vervestride/services/firebase_ai_service.dart';

/// Voice-Activated AI Assistant
/// Only shows when user says "VerveStride AI"
/// Can be hidden by saying "hide" or "turn off"
class VoiceActivatedAI extends StatefulWidget {
  const VoiceActivatedAI({super.key});

  @override
  State<VoiceActivatedAI> createState() => _VoiceActivatedAIState();
}

class _VoiceActivatedAIState extends State<VoiceActivatedAI> {
  bool _isVisible = false;
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isWakeWordListening = false;
  String _currentMessage = '';
  String _aiResponse = '';
  final TextEditingController _textController = TextEditingController();
  late stt.SpeechToText _speech;
  bool _speechAvailable = false;
  bool _voiceEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadVoiceEnabled();
    _initSpeech();
  }

  Future<void> _loadVoiceEnabled() async {
    try {
      // Voice is always enabled (free feature using device STT)
      if (!mounted) return;
      setState(() => _voiceEnabled = true);
    } catch (_) {}
  }

  Future<void> _initSpeech() async {
    _speech = stt.SpeechToText();
    try {
      _speechAvailable = await _speech.initialize();
      debugPrint('Speech available: $_speechAvailable');
      
      // Start wake word listening if user has subscription
      if (_speechAvailable && _hasAIAccess() && _voiceEnabled) {
        _startWakeWordListening();
      }
    } catch (e) {
      debugPrint('Speech init error: $e');
      _speechAvailable = false;
    }
  }

  bool _hasAIAccess() {
    return true; // AI available to all users with credits
  }

  Future<void> _startWakeWordListening() async {
    if (!_voiceEnabled) return;
    if (!_speechAvailable || _isListening || _isWakeWordListening || _isVisible) {
      return;
    }

    try {
      setState(() => _isWakeWordListening = true);
      
      await _speech.listen(
        onResult: (result) {
          final text = result.recognizedWords.toLowerCase();
          
          // Check for wake word to show
          if (text.contains('verve stride') || 
              text.contains('vervestride')) {
            debugPrint('✓ Wake word detected - showing AI');
            _speech.stop();
            setState(() {
              _isVisible = true;
              _isWakeWordListening = false;
            });
          }
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
      );
    } catch (e) {
      debugPrint('Wake word error: $e');
      setState(() => _isWakeWordListening = false);
      // Retry after delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && !_isVisible) _startWakeWordListening();
      });
    }
  }

  Future<void> _startVoiceInput() async {
    if (!_voiceEnabled) return;
    if (!_speechAvailable || _isListening) return;

    setState(() {
      _isListening = true;
      _textController.clear();
    });

    try {
      await _speech.listen(
        onResult: (result) {
          final text = result.recognizedWords.toLowerCase();
          
          // Check for hide commands
          if (text.contains('hide') || text.contains('turn off') || text.contains('close')) {
            debugPrint('✓ Hide command detected');
            _speech.stop();
            setState(() {
              _isVisible = false;
              _isListening = false;
            });
            // Restart wake word listening
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted && !_isVisible) _startWakeWordListening();
            });
            return;
          }
          
          // Optimize: only update if text changed to reduce lag
          if (mounted && result.recognizedWords != _textController.text) {
            setState(() {
              _textController.text = result.recognizedWords;
            });
          }
          
          if (result.finalResult) {
            _stopVoiceInput();
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5), // Wait 5 seconds of silence before stopping
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.confirmation, // Better for natural speech
      );
    } catch (e) {
      debugPrint('Voice input error: $e');
      if (e.toString().contains("type 'Null' is not a subtype of type 'bool'")) {
        _speechAvailable = false;
      }
      setState(() => _isListening = false);
    }
  }

  Future<void> _stopVoiceInput() async {
    if (!_isListening) return;

    await _speech.stop();
    setState(() => _isListening = false);

    if (_textController.text.trim().isNotEmpty) {
      await _sendMessage();
    }
  }

  Future<void> _sendMessage() async {
    final message = _textController.text.trim();
    if (message.isEmpty || _isProcessing) return;

    setState(() {
      _currentMessage = message;
      _aiResponse = '';
      _isProcessing = true;
    });

    _textController.clear();

    try {
      final response = await FirebaseAIService.instance.chatWithAI(message);
      if (mounted) {
        setState(() {
          _aiResponse = response;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiResponse = 'Sorry, I encountered an error. Please try again.';
          _isProcessing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only show if user has AI access
    if (!_hasAIAccess()) return const SizedBox.shrink();
    if (!_voiceEnabled) return const SizedBox.shrink();

    // Only show if visible (activated by voice)
    if (!_isVisible) return const SizedBox.shrink();

    return Positioned(
      right: 16,
      bottom: 100,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(20),
        color: AppColors.surface,
        child: Container(
          width: MediaQuery.of(context).size.width - 32,
          constraints: const BoxConstraints(maxHeight: 400),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                    ),
                    child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'VerveStride AI',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.textSecondary,
                    onPressed: () {
                      setState(() => _isVisible = false);
                      // Restart wake word listening
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (mounted && !_isVisible) _startWakeWordListening();
                      });
                    },
                  ),
                ],
              ),
              const Divider(height: 16),

              // Messages
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (_currentMessage.isEmpty && _aiResponse.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'Say something or type...',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      if (_currentMessage.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(_currentMessage),
                          ),
                        ),
                      if (_aiResponse.isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(_aiResponse),
                          ),
                        ),
                      if (_isProcessing)
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 16),

              // Input
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.red : AppColors.primary,
                    ),
                    onPressed: _isListening ? _stopVoiceInput : _startVoiceInput,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: const InputDecoration(
                        hintText: 'Type or say "hide" to close...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    color: AppColors.primary,
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
