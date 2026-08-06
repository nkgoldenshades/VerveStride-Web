import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Service for voice-activated AI assistant
/// Listens for "VerveStride AI" wake word in background
class VoiceActivationService extends ChangeNotifier {
  VoiceActivationService._();
  static final VoiceActivationService instance = VoiceActivationService._();

  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isEnabled = false;
  bool _speechAvailable = false;

  bool get isEnabled => _isEnabled;
  bool get isListening => _isListening;

  /// Initialize speech recognition
  Future<void> initialize() async {
    _speech = stt.SpeechToText();
    try {
      _speechAvailable = await _speech.initialize(
        onError: (error) {
          debugPrint('Voice activation error: ${error.errorMsg}');
          _isListening = false;
          notifyListeners();
        },
        onStatus: (status) {
          debugPrint('Voice activation status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            notifyListeners();
            // Restart listening if enabled
            if (_isEnabled && _speechAvailable) {
              Future.delayed(const Duration(seconds: 1), () {
                if (_isEnabled) startListening();
              });
            }
          }
        },
      );
      debugPrint('Voice activation available: $_speechAvailable');
    } catch (e) {
      debugPrint('Voice activation init error: $e');
      _speechAvailable = false;
    }
  }

  /// Start listening for wake word
  Future<void> startListening() async {
    if (!_speechAvailable || _isListening || !_isEnabled) return;

    try {
      _isListening = true;
      notifyListeners();

      await _speech.listen(
        onResult: (result) {
          final text = result.recognizedWords.toLowerCase();
          
          // Check for wake word
          if (text.contains('verve stride') || 
              text.contains('vervestride') ||
              text.contains('verve stride ai') ||
              text.contains('vervestride ai')) {
            debugPrint('✓ Wake word detected: $text');
            // Notify listeners that wake word was detected
            _onWakeWordDetected();
          }
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
      );
    } catch (e) {
      debugPrint('Voice activation listen error: $e');
      _isListening = false;
      notifyListeners();
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
      notifyListeners();
    }
  }

  /// Enable voice activation
  Future<void> enable() async {
    _isEnabled = true;
    notifyListeners();
    if (_speechAvailable) {
      await startListening();
    }
  }

  /// Disable voice activation
  Future<void> disable() async {
    _isEnabled = false;
    await stopListening();
    notifyListeners();
  }

  void _onWakeWordDetected() {
    // This will be handled by the widget listening to this service
    notifyListeners();
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }
}
