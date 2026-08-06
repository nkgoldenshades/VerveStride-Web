import 'dart:async';
import 'package:camera/camera.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:vervestride/core/app_theme.dart';
import 'package:vervestride/models/ai_feature_costs.dart';
import 'package:vervestride/services/credits_service.dart';
import 'package:vervestride/services/tts_service.dart';
import 'package:vervestride/widgets/ai_credit_confirm_dialog.dart';

/// Live Video + Voice Session
/// AI watches camera + listens to mic → speaks back in real-time
class LiveVideoSessionScreen extends StatefulWidget {
  const LiveVideoSessionScreen({super.key});

  @override
  State<LiveVideoSessionScreen> createState() => _LiveVideoSessionScreenState();
}

class _LiveVideoSessionScreenState extends State<LiveVideoSessionScreen>
    with SingleTickerProviderStateMixin {
  // Camera
  CameraController? _cameraController;
  bool _isCameraReady = false;

  // Live AI session
  LiveSession? _liveSession;
  bool _isSessionActive = false;
  bool _isConnecting = false;

  // Voice input
  late stt.SpeechToText _speech;
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _micEnabled = true;

  // UI state
  String _aiResponse = '';
  String _statusText = 'Tap 🎥 to start';
  final List<String> _transcript = [];
  Timer? _frameTimer;

  // Pulse animation for mic
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _initCamera();
    _initSpeech();
  }

  @override
  void dispose() {
    _stopSession();
    _cameraController?.dispose();
    _speech.stop();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Camera ────────────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    if (kIsWeb) {
      setState(() => _statusText = 'Camera not supported on web');
      return;
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _statusText = 'No camera found');
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        camera, ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('❌ Camera: $e');
      setState(() => _statusText = 'Camera unavailable');
    }
  }

  // ── Speech ────────────────────────────────────────────────────────────────

  Future<void> _initSpeech() async {
    _speech = stt.SpeechToText();
    try {
      _speechAvailable = await _speech.initialize(
        onError: (e) => debugPrint('🎤 Speech error: ${e.errorMsg}'),
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') {
            if (mounted) setState(() => _isListening = false);
            // Auto-restart mic if session active
            if (_isSessionActive && _micEnabled) {
              Future.delayed(const Duration(milliseconds: 300), _startListening);
            }
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Speech init: $e');
    }
  }

  Future<void> _startListening() async {
    if (!_speechAvailable || _isListening || !_micEnabled || !_isSessionActive) return;
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) async {
        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          final text = result.recognizedWords.trim();
          debugPrint('🎤 User said: $text');
          setState(() => _statusText = 'You: $text');
          await _sendTextToAI(text);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5), // Wait 5 seconds of silence before stopping
      partialResults: false,
      cancelOnError: false,
      listenMode: stt.ListenMode.dictation,
    );
  }

  Future<void> _sendTextToAI(String text) async {
    if (_liveSession == null) return;
    try {
      await _liveSession!.send(
        input: Content.text(text),
        turnComplete: true,
      );
    } catch (e) {
      debugPrint('❌ Send text error: $e');
    }
  }

  // ── Session ───────────────────────────────────────────────────────────────

  Future<void> _startSession() async {
    final confirmed = await showCreditConfirmDialog(
      context,
      featureName: '🎯 Live AI Session',
      creditCost: AIFeatureCosts.liveCoachingSession,
      description: 'AI watches your camera + listens to you in real-time',
      showMaxCount: true,
    );
    if (!confirmed) return;

    setState(() {
      _isConnecting = true;
      _statusText = 'Connecting...';
    });

    try {
      final liveModel = FirebaseAI.vertexAI().liveGenerativeModel(
        model: 'gemini-2.5-flash',
        liveGenerationConfig: LiveGenerationConfig(
          speechConfig: SpeechConfig(voiceName: 'Aoede'),
        ),
        systemInstruction: Content.system(
          'You are VerveStride AI in live mode. '
          'You can see the user through their camera and hear them speak. '
          'Be their real-time personal coach and wellness assistant. '
          'For workouts: check form, count reps, give instant cues. '
          'For meals: identify food, estimate nutrition. '
          'For questions: answer naturally like a conversation. '
          'Keep responses short — max 2 sentences. Be encouraging.',
        ),
      );

      _liveSession = await liveModel.connect();

      setState(() {
        _isSessionActive = true;
        _isConnecting = false;
        _statusText = 'Listening... speak to me!';
      });

      // Listen for AI responses
      _listenToResponses();

      // Send camera frames every 3 seconds
      _frameTimer = Timer.periodic(const Duration(seconds: 3), (_) => _sendFrame());

      // Start mic
      if (_micEnabled) await _startListening();

      // Deduct credits
      await CreditsService.instance.useCredits(
        AIFeatureCosts.liveCoachingSession,
        description: 'Live AI Session',
      );

      // Greet the user
      await _sendTextToAI('Hello! I just started. What would you like help with?');
    } catch (e) {
      debugPrint('❌ Session start error: $e');
      setState(() {
        _isConnecting = false;
        _statusText = 'Connection failed. Try again.';
      });
    }
  }

  void _listenToResponses() async {
    if (_liveSession == null) return;
    try {
      await for (final response in _liveSession!.receive()) {
        if (!mounted) break;
        final msg = response.message;
        if (msg is LiveServerContent) {
          final parts = msg.modelTurn?.parts ?? [];
          String text = '';
          for (final part in parts) {
            if (part is TextPart) text += part.text;
          }
          if (text.isNotEmpty && msg.turnComplete == true) {
            setState(() {
              _aiResponse = text;
              _transcript.add('AI: $text');
              _statusText = 'Listening...';
            });
            // Speak the response
            TTSService.instance.speak(text);
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Response stream: $e');
      if (mounted && _isSessionActive) {
        setState(() => _statusText = 'Connection lost. Tap stop.');
      }
    }
  }

  Future<void> _sendFrame() async {
    if (_liveSession == null || !_isSessionActive) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      await _liveSession!.sendVideoRealtime(InlineDataPart('image/jpeg', bytes));
    } catch (e) {
      debugPrint('⚠️ Frame error: $e');
    }
  }

  Future<void> _stopSession() async {
    _frameTimer?.cancel();
    _frameTimer = null;
    _speech.stop();
    await _liveSession?.close();
    _liveSession = null;
    TTSService.instance.stop();
    if (mounted) {
      setState(() {
        _isSessionActive = false;
        _isListening = false;
        _statusText = 'Session ended';
      });
    }
  }

  void _toggleMic() {
    setState(() => _micEnabled = !_micEnabled);
    if (_micEnabled && _isSessionActive) {
      _startListening();
    } else {
      _speech.stop();
      setState(() => _isListening = false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_isCameraReady && _cameraController != null)
            CameraPreview(_cameraController!)
          else
            Container(
              color: Colors.black,
              child: const Center(
                child: Icon(Icons.videocam_off, color: Colors.white38, size: 72),
              ),
            ),

          // Bottom controls overlay
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.92)],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // AI response bubble
                  if (_aiResponse.isNotEmpty)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12)],
                      ),
                      child: Text(
                        _aiResponse,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Status text
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isListening)
                        AnimatedBuilder(
                          animation: _pulseAnim,
                          builder: (_, __) => Transform.scale(
                            scale: _pulseAnim.value,
                            child: const Icon(Icons.mic, color: Colors.red, size: 16),
                          ),
                        ),
                      if (_isListening) const SizedBox(width: 6),
                      Text(
                        _statusText,
                        style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Controls row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Close
                      _circleBtn(
                        icon: Icons.close,
                        color: Colors.white24,
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          await _stopSession();
                          if (!mounted) return;
                          navigator.pop();
                        },
                      ),
                      const SizedBox(width: 24),

                      // Main start/stop
                      GestureDetector(
                        onTap: _isConnecting ? null : (_isSessionActive ? _stopSession : _startSession),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            color: _isSessionActive ? Colors.red : AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(
                              color: (_isSessionActive ? Colors.red : AppColors.primary).withOpacity(0.5),
                              blurRadius: 24, spreadRadius: 4,
                            )],
                          ),
                          child: _isConnecting
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              : Icon(
                                  _isSessionActive ? Icons.stop_rounded : Icons.videocam_rounded,
                                  color: Colors.white, size: 34,
                                ),
                        ),
                      ),
                      const SizedBox(width: 24),

                      // Mic toggle
                      _circleBtn(
                        icon: _micEnabled ? Icons.mic : Icons.mic_off,
                        color: _isListening
                            ? Colors.red.withOpacity(0.4)
                            : (_micEnabled ? Colors.white24 : Colors.white12),
                        iconColor: _isListening ? Colors.red : Colors.white,
                        onTap: _isSessionActive ? _toggleMic : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Top bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Live indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              color: _isSessionActive ? Colors.red : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isSessionActive ? 'LIVE' : 'VerveStride AI',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    // Credits
                    ListenableBuilder(
                      listenable: CreditsService.instance,
                      builder: (_, __) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.stars_rounded, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${CreditsService.instance.availableCredits}',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn({
    required IconData icon,
    required Color color,
    Color iconColor = Colors.white,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: onTap == null ? Colors.white38 : iconColor, size: 24),
      ),
    );
  }
}
