import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

/// Voice input service with auto-send capability
/// Similar to ChatGPT's voice interaction
class VoiceInputService extends ChangeNotifier {
  VoiceInputService._();
  static final VoiceInputService instance = VoiceInputService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _currentText = '';
  String _lastError = '';
  
  // Callback when speech ends and should auto-send
  void Function(String text)? onSpeechComplete;
  
  // Callback for real-time text updates
  void Function(String text)? onTextUpdate;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  String get currentText => _currentText;
  String get lastError => _lastError;
  bool get isAvailable => _speech.isAvailable;

  /// Initialize speech recognition
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _lastError = 'Microphone permission denied';
        debugPrint('❌ Microphone permission denied');
        return false;
      }

      // Initialize speech recognition
      _isInitialized = await _speech.initialize(
        onError: (error) {
          debugPrint('❌ Speech error: ${error.errorMsg}');
          _lastError = error.errorMsg;
          _isListening = false;
          notifyListeners();
        },
        onStatus: (status) {
          debugPrint('🎤 Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            _handleSpeechEnd();
          }
        },
      );

      if (_isInitialized) {
        debugPrint('✅ Voice input initialized');
      } else {
        _lastError = 'Speech recognition not available';
        debugPrint('❌ Speech recognition not available');
      }

      return _isInitialized;
    } catch (e) {
      _lastError = 'Failed to initialize: $e';
      debugPrint('❌ Voice input init error: $e');
      return false;
    }
  }

  /// Start listening for voice input
  Future<void> startListening({
    String locale = 'en_US',
    bool autoSend = true,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return;
    }

    if (_isListening) {
      debugPrint('⚠️ Already listening');
      return;
    }

    try {
      _currentText = '';
      _lastError = '';
      
      await _speech.listen(
        onResult: (result) {
          final text = result.recognizedWords;
          
          // Optimize: only update if text changed to reduce lag
          if (text != _currentText) {
            _currentText = text;
            onTextUpdate?.call(_currentText);
            notifyListeners();
          }
          
          debugPrint('🎤 Recognized: $_currentText (final: ${result.finalResult})');
          
          // Auto-send when speech is finalized
          if (autoSend && result.finalResult && _currentText.trim().isNotEmpty) {
            _handleSpeechEnd();
          }
        },
        localeId: locale,
        listenMode: stt.ListenMode.confirmation, // Stops after pause
        pauseFor: const Duration(seconds: 5), // Wait 5 seconds of silence before stopping
        listenFor: const Duration(seconds: 30), // Max 30 seconds
        cancelOnError: true,
        partialResults: true, // Enable partial results for real-time feedback
      );

      _isListening = true;
      notifyListeners();
      debugPrint('🎤 Started listening...');
    } catch (e) {
      _lastError = 'Failed to start listening: $e';
      debugPrint('❌ Start listening error: $e');
      _isListening = false;
      notifyListeners();
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _speech.stop();
      _isListening = false;
      notifyListeners();
      debugPrint('🎤 Stopped listening');
    } catch (e) {
      debugPrint('❌ Stop listening error: $e');
    }
  }

  /// Cancel listening without sending
  Future<void> cancelListening() async {
    if (!_isListening) return;

    try {
      await _speech.cancel();
      _currentText = '';
      _isListening = false;
      notifyListeners();
      debugPrint('🎤 Cancelled listening');
    } catch (e) {
      debugPrint('❌ Cancel listening error: $e');
    }
  }

  /// Handle speech end - auto-send
  void _handleSpeechEnd() {
    if (_currentText.trim().isEmpty) {
      debugPrint('⚠️ No text to send');
      _isListening = false;
      notifyListeners();
      return;
    }

    final textToSend = _currentText.trim();
    debugPrint('✅ Speech complete, auto-sending: $textToSend');
    
    _isListening = false;
    notifyListeners();
    
    // Trigger callback to send message
    onSpeechComplete?.call(textToSend);
    
    // Clear text after sending
    _currentText = '';
  }

  /// Get available locales
  Future<List<stt.LocaleName>> getAvailableLocales() async {
    if (!_isInitialized) {
      await initialize();
    }
    return _speech.locales();
  }

  /// Check if locale is supported
  Future<bool> isLocaleSupported(String locale) async {
    final locales = await getAvailableLocales();
    return locales.any((l) => l.localeId == locale);
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }
}
