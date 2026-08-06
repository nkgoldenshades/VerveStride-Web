import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_theme.dart';
import '../../services/pose_interpreter.dart';

class WorkoutPiPScreen extends StatefulWidget {
  const WorkoutPiPScreen({super.key});

  @override
  State<WorkoutPiPScreen> createState() => _WorkoutPiPScreenState();
}

class _WorkoutPiPScreenState extends State<WorkoutPiPScreen> {
  CameraController? _cameraController;
  VideoPlayerController? _videoController;
  List<CameraDescription> _availableCameras = [];
  int _selectedCameraIndex = 0;
  
  // ML Tracking
  PoseInterpreter? _interpreter;
  bool _mlTracking = false;
  int _detectedPoses = 0;

  bool _cameraIsMain = false;

  Offset? _pipOffset;
  final Size _pipSize = const Size(150, 210);
  bool _pipInitialized = false;

  DateTime? _sessionStart;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initMLModel();

    _sessionStart = DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final start = _sessionStart;
      if (start == null) return;
      setState(() {
        _elapsed = DateTime.now().difference(start);
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _cameraController?.dispose();
    _videoController?.dispose();
    _interpreter?.close();
    super.dispose();
  }

  Future<void> _initMLModel() async {
    if (kIsWeb) {
      // ML tracking on web uses WebPoseView (different implementation)
      return;
    }

    try {
      final interpreter = await PoseInterpreter.create(
        assetPath: 'assets/models/movenet_lightning.tflite',
      );
      
      if (!mounted) return;
      
      setState(() {
        _interpreter = interpreter;
        _mlTracking = true;
      });
      
      debugPrint('✅ ML Model loaded for background tracking');
    } catch (e) {
      debugPrint('⚠️ ML Model failed to load: $e');
      // Continue without ML tracking
    }
  }

  Future<void> _initCamera() async {
    if (kIsWeb) {
      // Camera on web requires additional setup; keep UI working without it.
      return;
    }

    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) return;

      // Try to find front camera first
      final frontIndex = _availableCameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      _selectedCameraIndex = frontIndex != -1 ? frontIndex : 0;

      await _setCameraByIndex(_selectedCameraIndex);
    } catch (_) {
      // If camera fails, we still allow video-only experience.
    }
  }

  Future<void> _setCameraByIndex(int index) async {
    if (index < 0 || index >= _availableCameras.length) return;

    final old = _cameraController;
    _cameraController = null;
    if (mounted) setState(() {});
    await old?.dispose();

    try {
      final controller = CameraController(
        _availableCameras[index],
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();
      if (!mounted) return;

      setState(() {
        _cameraController = controller;
        _selectedCameraIndex = index;
      });
      
      // Start ML tracking if interpreter is available
      if (_interpreter != null && !kIsWeb) {
        _startMLTracking();
      }
    } catch (_) {
      // Camera initialization failed
    }
  }

  void _startMLTracking() {
    final cam = _cameraController;
    if (cam == null || !cam.value.isInitialized || _interpreter == null) return;
    
    try {
      cam.startImageStream((image) {
        // Process every 3rd frame for performance
        if (_detectedPoses % 3 != 0) {
          _detectedPoses++;
          return;
        }
        
        _detectedPoses++;
        
        // Process image with ML interpreter for pose detection
        // This runs in background even when video is playing
        try {
          // Note: Full pose processing implementation would go here
          // For now, we're just tracking that ML is running
          // You can add full pose detection logic similar to live_pose_screen.dart
          
          // Example: Convert camera image to tensor, run inference, get keypoints
          // final keypoints = _interpreter!.run(processedImage);
          // Then use keypoints for calorie calculation, form analysis, etc.
        } catch (e) {
          debugPrint('⚠️ ML processing error: $e');
        }
      });
      
      debugPrint('✅ ML tracking started in background');
    } catch (e) {
      debugPrint('⚠️ Failed to start ML tracking: $e');
    }
  }

  // ignore: unused_element
  void _stopMLTracking() {
    final cam = _cameraController;
    if (cam == null || !cam.value.isInitialized) return;
    
    try {
      cam.stopImageStream();
      debugPrint('🛑 ML tracking stopped');
    } catch (e) {
      debugPrint('⚠️ Failed to stop ML tracking: $e');
    }
  }

  Future<void> _toggleCamera() async {
    if (kIsWeb || _availableCameras.length < 2) return;

    final current = _selectedCameraIndex;
    final currentLens = _availableCameras[current].lensDirection;

    // Find camera with different lens direction
    int nextIndex = _availableCameras.indexWhere(
      (c) => c.lensDirection != currentLens,
    );
    
    if (nextIndex == -1) {
      // If no different lens found, just cycle to next camera
      nextIndex = (current + 1) % _availableCameras.length;
    }

    await _setCameraByIndex(nextIndex);
  }

  void _toggleSwap() {
    setState(() {
      _cameraIsMain = !_cameraIsMain;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (!_pipInitialized) {
      _pipInitialized = true;
      _pipOffset = Offset(
        size.width - _pipSize.width - 16,
        size.height - _pipSize.height - 120,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildMainView()),
            Positioned(
              left: 12,
              right: 12,
              top: 10,
              child: _buildTopOverlay(),
            ),
            if (_buildPipView() != null && _pipOffset != null)
              Positioned(
                left: _pipOffset!.dx,
                top: _pipOffset!.dy,
                child: _buildDraggablePip(
                  screenSize: size,
                  child: _buildPipView()!,
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: _buildBottomControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopOverlay() {
    String two(int v) => v.toString().padLeft(2, '0');

    final mm = two(_elapsed.inMinutes.remainder(60));
    final ss = two(_elapsed.inSeconds.remainder(60));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _roundIconButton(
          icon: Icons.close,
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Close',
        ),
        const Spacer(),
        Column(
          children: [
            const Text(
              'Workout',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$mm:$ss',
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_mlTracking && _interpreter != null) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'ML Tracking',
                    style: TextStyle(
                      color: Colors.green.withOpacity(0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        const Spacer(),
        if (!kIsWeb && _availableCameras.length > 1)
          _roundIconButton(
            icon: Icons.cameraswitch,
            onPressed: _toggleCamera,
            tooltip: 'Switch Camera',
          ),
      ],
    );
  }

  Widget _buildBottomControls() {
    Widget btn({
      required IconData icon,
      required VoidCallback onTap,
      Color? bg,
      Color? fg,
    }) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (bg ?? Colors.white).withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: fg ?? Colors.white),
          ),
        ),
      );
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            btn(icon: Icons.more_horiz, onTap: () {}),
            const SizedBox(width: 10),
            btn(icon: Icons.volume_up, onTap: () {}),
            const SizedBox(width: 10),
            btn(icon: Icons.mic_off, onTap: () {}),
            const SizedBox(width: 10),
            btn(
              icon: Icons.call_end,
              onTap: () => Navigator.of(context).maybePop(),
              bg: Colors.red,
              fg: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required VoidCallback? onPressed,
    String? tooltip,
  }) {
    final isDisabled = onPressed == null;
    
    final button = MouseRegion(
      cursor: isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(
            icon,
            color: isDisabled
                ? Colors.white.withOpacity(0.3)
                : Colors.white,
          ),
          tooltip: tooltip,
        ),
      ),
    );
    
    return button;
  }

  Widget _buildMainView() {
    if (_cameraIsMain) {
      final cam = _cameraController;
      if (cam == null || !cam.value.isInitialized) {
        return _emptyState(
          title: 'Camera not ready',
          subtitle: kIsWeb
              ? 'Camera preview on web is disabled in this demo.'
              : 'Check permissions and try again.',
        );
      }
      return GestureDetector(
        onDoubleTap: _toggleSwap,
        child: CameraPreview(cam),
      );
    }

    final vid = _videoController;
    if (vid == null || !vid.value.isInitialized) {
      return _emptyState(
        title: 'No video selected',
        subtitle: 'Tap the gallery icon to choose a workout video.',
      );
    }

    return GestureDetector(
      onDoubleTap: _toggleSwap,
      child: Center(
        child: AspectRatio(
          aspectRatio: vid.value.aspectRatio,
          child: VideoPlayer(vid),
        ),
      ),
    );
  }

  Widget? _buildPipView() {
    if (_cameraIsMain) {
      final vid = _videoController;
      if (vid == null || !vid.value.isInitialized) return null;

      return _pipFrame(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: VideoPlayer(vid),
        ),
      );
    }

    final cam = _cameraController;
    if (cam == null || !cam.value.isInitialized) return null;

    return _pipFrame(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CameraPreview(cam),
      ),
    );
  }

  Widget _pipFrame({required Widget child}) {
    return Material(
      color: Colors.transparent,
      elevation: 10,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: _pipSize.width,
        height: _pipSize.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(child: child),
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: IconButton(
                  onPressed: _toggleSwap,
                  icon: const Icon(Icons.cached, color: Colors.white, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggablePip({
    required Size screenSize,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: _toggleSwap,
      onPanUpdate: (details) {
        final current = _pipOffset ?? const Offset(16, 110);
        final next = current + details.delta;

        final maxX = screenSize.width - _pipSize.width - 16;
        final maxY = screenSize.height - _pipSize.height - 96;

        setState(() {
          _pipOffset = Offset(
            next.dx.clamp(16, maxX),
            next.dy.clamp(16, maxY),
          );
        });
      },
      onPanEnd: (_) {
        final current = _pipOffset ?? const Offset(16, 110);

        final maxX = screenSize.width - _pipSize.width - 16;
        final maxY = screenSize.height - _pipSize.height - 96;

        final snapLeft = 16.0;
        final snapRight = maxX;
        final snapTop = 16.0;
        final snapBottom = maxY;

        final targetX = (current.dx - snapLeft) < (snapRight - current.dx)
            ? snapLeft
            : snapRight;
        final targetY = (current.dy - snapTop) < (snapBottom - current.dy)
            ? snapTop
            : snapBottom;

        setState(() {
          _pipOffset = Offset(targetX, targetY);
        });
      },
      child: child,
    );
  }

  Widget _emptyState({required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.card.withOpacity(0.6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_outline,
                  size: 56, color: AppColors.secondary),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}