import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../services/js_stub.dart' if (dart.library.js) 'dart:js' as js;
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_theme.dart';
import '../../services/local_storage_service.dart';
import '../../services/pose_interpreter.dart';
import '../../services/streak_service.dart';
import 'web_pose_view.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/shooting_stars_background.dart';

enum WorkoutMode { cameraOnly, videoOnly, split }

class LivePoseScreen extends StatefulWidget {
  const LivePoseScreen({super.key});

  @override
  State<LivePoseScreen> createState() => _LivePoseScreenState();
}

class _LivePoseScreenState extends State<LivePoseScreen>
    with WidgetsBindingObserver {
  static const String _modelAssetPath =
      'assets/models/movenet_lightning.tflite';
  static const int _inputSize = 192;

  final LocalStorageService _storage = LocalStorageService.instance;

  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = const [];
  int _selectedCameraIndex = 0;
  PoseInterpreter? _interpreter;

  bool _isRunning = false;
  String? _cameraError;
  String? _mlError;
  bool _showSkeleton = true;
  bool _saving = false;
  String _webStatus = 'web: idle';
  bool _fullScreen = false;
  String _note = '';
  double? _editedCalories;
  bool _editingCalories = false;

  // Video playback state
  WorkoutMode _workoutMode = WorkoutMode.cameraOnly;
  VideoPlayerController? _videoController;
  bool _videoFullscreen = false;
  bool _cameraFullscreen = false;
  final ImagePicker _imagePicker = ImagePicker();

  List<dynamic> _todayActivities = const [];

  List<_Keypoint> _keypoints = const [];
  List<_Keypoint> _prevKeypoints = const [];

  final Map<int, double> _jointMovement = {};

  DateTime? _sessionStart;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  int _frameCounter = 0;
  int _processedFrames = 0;
  double? _weightKg;
  double? _age;
  String? _gender; // 'male', 'female', 'other'
  double? _heightCm;
  double _maxConf = 0.0;
  bool _debugMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    final cam = _cameraController;
    if (cam != null && cam.value.isInitialized) {
      try {
        cam.stopImageStream();
      } catch (e) {
        debugPrint('⚠️ stopImageStream during dispose failed: $e');
      }
    }
    _cameraController?.dispose();
    _videoController?.dispose();
    _interpreter?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadProfileWeight().then((_) {
        if (!mounted) return;
        setState(() {});
      });
    }
  }

  Future<void> _bootstrap() async {
    try {
      await _loadProfileWeight();
      await _initInterpreter();
      if (!kIsWeb) {
        await _initCamera();
      }
      await _loadTodayActivities();
    } catch (e, st) {
      debugPrint('❌ LivePose bootstrap failed: $e');
      debugPrint('Stack: $st');
      if (!mounted) return;
      setState(() {
        _cameraError = 'Initialization error: $e';
      });
    }
  }

  Future<void> _loadTodayActivities() async {
    try {
      final today = DateTime.now();
      final activities = await _storage.getActivitiesForDate(today);
      if (!mounted) return;
      setState(() {
        _todayActivities = activities;
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadProfileWeight() async {
    try {
      final json = await _storage.getUserProfile();

      // Load weight
      final rawWeight = json == null
          ? null
          : (json['weightKg'] ??
              json['weight_kg'] ??
              json['weight'] ??
              json['weightKG'] ??
              json['WeightKg']);

      if (rawWeight is num) {
        _weightKg = rawWeight.toDouble();
      } else if (rawWeight is String) {
        final normalized = rawWeight.replaceAll(RegExp(r'[^0-9.+-]'), '');
        _weightKg = double.tryParse(normalized);
      } else {
        _weightKg = null;
      }

      // If profile exists but weight is missing/invalid, fall back to a safe default
      // so the workout UI and calorie estimation don't show "Not set".
      if (_weightKg == null || _weightKg! <= 0) {
        _weightKg = 70.0;
      }

      // Load age
      final rawAge = json?['age'] ?? json?['Age'];
      if (rawAge is num) {
        _age = rawAge.toDouble();
      } else if (rawAge is String) {
        _age = double.tryParse(rawAge);
      }

      // Load gender
      _gender = json?['gender']?.toString().toLowerCase().trim();

      // Load height
      final rawHeight =
          json?['heightCm'] ?? json?['heightCm'] ?? json?['height'];
      if (rawHeight is num) {
        _heightCm = rawHeight.toDouble();
      } else if (rawHeight is String) {
        _heightCm = double.tryParse(rawHeight);
      }

      // If no profile exists, create a default one
      if (json == null) {
        debugPrint('🏋️ No profile found, creating default profile');
        _weightKg = 70.0; // Default weight
        _age = 30.0; // Default age
        _gender = 'male'; // Default gender
        _heightCm = 170.0; // Default height

        // Save default profile
        final defaultProfile = {
          'name': 'User',
          'age': 30,
          'gender': 'male',
          'heightCm': 170.0,
          'weightKg': 70.0,
          'activityLevel': 3,
          'goal': 'maintain',
          'targetWeightKg': 0.0,
        };
        await _storage.saveUserProfile(defaultProfile);
        debugPrint('🏋️ Default profile saved with weight: $_weightKg kg');
      }

      if (kDebugMode) {
        debugPrint('🏋️ Profile loaded:');
        debugPrint('  Weight: ${_weightKg ?? 0} kg');
        debugPrint('  Age: ${_age ?? 0} years');
        debugPrint('  Gender: $_gender');
        debugPrint('  Height: ${_heightCm ?? 0} cm');
      }
    } catch (e) {
      debugPrint('❌ Error loading profile weight: $e');
      _weightKg = 70.0; // Fallback to default weight
      _age = 30.0; // Fallback to default age
      _gender = 'male'; // Fallback to default gender
      _heightCm = 170.0; // Fallback to default height
    }
  }

  Future<void> _initInterpreter() async {
    if (kIsWeb) {
      if (!mounted) return;
      setState(() {
        _interpreter = null;
        _mlError = null;
      });
      return;
    }

    try {
      PoseInterpreter interpreter;
      try {
        debugPrint('🎯 Loading model from $_modelAssetPath');
        interpreter = await PoseInterpreter.create(assetPath: _modelAssetPath);
      } catch (e) {
        // Some platforms/packaging setups expect the asset key without the leading `assets/`.
        debugPrint(
            '⚠️ Primary load failed, trying fallback: models/movenet_lightning.tflite');
        interpreter = await PoseInterpreter.create(
            assetPath: 'models/movenet_lightning.tflite');
      }

      if (!mounted) return;

      // Log tensor information for debugging
      try {
        final inputTensors = interpreter.getInputTensors();
        final outputTensors = interpreter.getOutputTensors();
        debugPrint('📊 ML Model Ready:');
        for (var i = 0; i < inputTensors.length; i++) {
          debugPrint(
              '   Input $i: shape=${inputTensors[i].shape}, type=${inputTensors[i].type}');
        }
        for (var i = 0; i < outputTensors.length; i++) {
          debugPrint(
              '   Output $i: shape=${outputTensors[i].shape}, type=${outputTensors[i].type}');
        }
      } catch (e) {
        debugPrint('⚠️ Could not log tensor shapes: $e');
      }

      setState(() {
        _interpreter = interpreter;
        _mlError = null;
      });
    } catch (e, st) {
      debugPrint('❌ Pose model init failed: $e');
      debugPrint('$st');
      if (!mounted) return;

      // Check if it's a file not found or invalid model error
      final errorMessage = e.toString().toLowerCase();
      final isModelMissing = errorMessage.contains('file not found') ||
          errorMessage.contains('no such file') ||
          errorMessage.contains('invalid') ||
          errorMessage.contains('failed to load');

      setState(() {
        _interpreter = null;
        if (isModelMissing) {
          _mlError =
              'ML model not found/invalid. Path: $_modelAssetPath. Error: $e';
        } else {
          _mlError = 'ML features unavailable: $e';
        }
        debugPrint('⚠️ ML Error assigned: $_mlError');
      });
    }
  }

  Future<void> _initCamera() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        if (!mounted) return;
        setState(() => _cameraError = 'No camera found.');
        return;
      }

      final frontIndex = _availableCameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (frontIndex != -1) {
        _selectedCameraIndex = frontIndex;
      } else {
        _selectedCameraIndex = 0;
      }

      await _setCameraByIndex(_selectedCameraIndex);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = 'Camera init failed: $e';
      });
    }
  }

  Future<void> _setCameraByIndex(int index) async {
    if (kIsWeb) return;
    if (index < 0 || index >= _availableCameras.length) return;

    await _stop();

    final old = _cameraController;
    _cameraController = null;
    if (mounted) setState(() {});
    await old?.dispose();

    try {
      final controller = CameraController(
        _availableCameras[index],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();
      if (!mounted) return;

      setState(() {
        _cameraController = controller;
        _cameraError = null;
        _selectedCameraIndex = index;
      });

      await _start();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = 'Camera init failed: $e';
      });
    }
  }

  Future<void> _toggleCamera() async {
    if (kIsWeb) return;
    if (_availableCameras.length < 2) return;

    final current = _selectedCameraIndex;
    final currentLens = _availableCameras[current].lensDirection;

    int nextIndex = _availableCameras.indexWhere(
      (c) => c.lensDirection != currentLens,
    );
    if (nextIndex == -1) {
      nextIndex = (current + 1) % _availableCameras.length;
    }

    await _setCameraByIndex(nextIndex);
  }

  Future<void> _start() async {
    await _loadProfileWeight();
    if (kIsWeb) {
      setState(() {
        _isRunning = true;
        _cameraError = null;
        _sessionStart = DateTime.now();
        _elapsed = Duration.zero;
        _jointMovement.clear();
        _prevKeypoints = [];
        _editedCalories = null;
      });

      // Start the timer for web as well
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final start = _sessionStart;
        if (start == null) return;
        setState(() {
          _elapsed = DateTime.now().difference(start);
        });
      });

      return;
    }

    final cam = _cameraController;
    if (cam == null || !cam.value.isInitialized) return;

    if (_isRunning) return;

    _frameCounter = 0;
    _processedFrames = 0;
    _jointMovement.clear();
    _prevKeypoints = const [];

    setState(() {
      _isRunning = true;
      _cameraError = null;
      _sessionStart = DateTime.now();
      _elapsed = Duration.zero;
      _jointMovement.clear();
      _prevKeypoints = [];
      _editedCalories = null;
    });

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final start = _sessionStart;
      if (start == null) return;
      setState(() {
        _elapsed = DateTime.now().difference(start);
      });
    });

    try {
      if (!kIsWeb && _interpreter != null) {
        await cam.startImageStream(_onCameraImage);
        debugPrint('✅ Camera stream started successfully');
      }
    } catch (e) {
      debugPrint('❌ Failed to start camera stream: $e');
      if (!mounted) return;
      setState(() {
        _cameraError = 'Failed to start camera stream: $e';
        _isRunning = false;
      });
    }
  }

  Future<void> _stop() async {
    if (kIsWeb) {
      _ticker?.cancel();
      _ticker = null;
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
      return;
    }

    final cam = _cameraController;
    if (cam != null && cam.value.isInitialized) {
      try {
        await cam.stopImageStream();
      } catch (_) {
        // ignore
      }
    }

    _ticker?.cancel();
    _ticker = null;

    if (mounted) {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );

      if (video == null) return;

      await _initializeVideo(video.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _initializeVideo(String path) async {
    try {
      // Dispose old controller if exists
      await _videoController?.dispose();

      final controller = kIsWeb
          ? VideoPlayerController.networkUrl(Uri.parse(path))
          : VideoPlayerController.file(File(path));

      await controller.initialize();

      if (!mounted) return;

      setState(() {
        _videoController = controller;
        _workoutMode = WorkoutMode.videoOnly;
      });

      // Auto-play when video is loaded
      controller.play();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleVideoPlayback() {
    final controller = _videoController;
    if (controller == null) return;

    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  void _stopVideo() {
    final controller = _videoController;
    if (controller == null) return;

    controller.pause();
    controller.seekTo(Duration.zero);
    setState(() {});
  }

  void _switchWorkoutMode(WorkoutMode mode) {
    if (!mounted) return;
    setState(() {
      _workoutMode = mode;
      _videoFullscreen = false;
      _cameraFullscreen = false;
    });
  }

  IconData _getModeIcon() {
    switch (_workoutMode) {
      case WorkoutMode.cameraOnly:
        return Icons.camera_alt;
      case WorkoutMode.videoOnly:
        return Icons.video_library;
      case WorkoutMode.split:
        return Icons.view_column;
    }
  }

  void _onCameraImage(CameraImage image) {
    if (!_isRunning) return;
    if (_interpreter == null) return;

    _frameCounter++;

    // Throttle for performance
    if (_frameCounter % 3 != 0) return;

    if (_processedFrames > 0 && _processedFrames % 15 == 0) {
      if (!mounted) return;
      setState(() {});
    }

    _processedFrames++;

    final rot = _availableCameras[_selectedCameraIndex].sensorOrientation;
    final inputTensor = _interpreter!.getInputTensors().isNotEmpty
        ? _interpreter!.getInputTensors().first
        : null;
    final inputType = inputTensor?.type;
    final inputTypeStr = inputType?.toString().toLowerCase() ?? '';
    final expectsUint8 = inputTypeStr.contains('uint8') ||
        inputTypeStr.contains('ktfliteuint8') ||
        inputTypeStr.contains('tflitetype.uint8');

    final input = expectsUint8
        ? _yuv420ToRgbUint8(image, _inputSize, _inputSize, rot)
        : _yuv420ToRgbNormalized(image, _inputSize, _inputSize, rot);

    final output = List.generate(
      1,
      (_) => List.generate(
          1, (_) => List.generate(17, (_) => List.filled(3, 0.0))),
    );

    final sw = Stopwatch()..start();
    try {
      _interpreter!.run(input, output);
      sw.stop();
    } catch (e) {
      debugPrint('❌ Interpreter run failed: $e');
      return;
    }

    final isFront = _availableCameras[_selectedCameraIndex].lensDirection ==
        CameraLensDirection.front;

    final kp = <_Keypoint>[];
    double maxConf = 0.0;
    for (int i = 0; i < 17; i++) {
      final y = (output[0][0][i][0] as num).toDouble();
      final x = (output[0][0][i][1] as num).toDouble();
      final c = (output[0][0][i][2] as num).toDouble();
      if (c > maxConf) maxConf = c;

      // Flip x for front camera if mirrored
      final xFixed = isFront ? (1.0 - x) : x;

      kp.add(_Keypoint(index: i, x: xFixed, y: y, confidence: c));
    }

    if (_processedFrames % 30 == 0) {
      final inputMean = _calculateInputMean(input);
      debugPrint(
          '📊 ML Output: Max conf = ${maxConf.toStringAsFixed(3)} (IsFront: $isFront) Time: ${sw.elapsedMilliseconds}ms');
      debugPrint('🔍 Image Mean: ${inputMean.toStringAsFixed(3)}');
      debugPrint(
          '🔍 Raw Top 3 KP: ${kp.take(3).map((k) => '(${k.x.toStringAsFixed(2)}, ${k.y.toStringAsFixed(2)}) c:${k.confidence.toStringAsFixed(2)}').toList()}');
      if (maxConf < 0.1) {
        debugPrint('⚠️ Low confidence: Output[0][0][0] = ${output[0][0][0]}');
      }
    }

    _accumulateMovement(kp);

    if (!mounted) return;
    setState(() {
      _keypoints = kp;
      _maxConf = maxConf;
    });
  }

  void _accumulateMovement(List<_Keypoint> current) {
    // Allow partial detection - don't require all 17 points
    if (_prevKeypoints.isEmpty) {
      _prevKeypoints = current;
      // Initialize jointMovement with zeros so UI shows body parts immediately
      for (int i = 0; i < current.length && i < 17; i++) {
        _jointMovement[i] = 0.0;
      }
      debugPrint(
          '🔄 First frame: initialized ${_jointMovement.length} joint movements');
      return;
    }

    // Only require same number of points between frames
    if (current.length != _prevKeypoints.length) {
      _prevKeypoints = current;
      debugPrint(
          '⚠️ Keypoint count mismatch: ${current.length} vs ${_prevKeypoints.length}');
      return;
    }

    // Track movement for available points
    final pointCount = current.length < 17 ? current.length : 17;
    int movementsDetected = 0;
    for (int i = 0; i < pointCount; i++) {
      final a = _prevKeypoints[i];
      final b = current[i];
      // Lower confidence threshold to capture more movement
      if (a.confidence < 0.2 || b.confidence < 0.2) continue;

      final dx = (b.x - a.x).abs();
      final dy = (b.y - a.y).abs();
      final dist = math.sqrt(dx * dx + dy * dy);

      // Much lower threshold to capture subtle movements
      if (dist > 0.0005) {
        _jointMovement[i] = (_jointMovement[i] ?? 0) + dist;
        movementsDetected++;
      }
    }

    if (movementsDetected > 0) {
      debugPrint(
          '📊 Detected movement in $movementsDetected joints. Total entries: ${_jointMovement.length}');
    }

    _prevKeypoints = current;
  }

  double _estimatedCalories() {
    final weight = _weightKg ?? 70.0;
    final age = _age ?? 30.0;
    final gender = _gender ?? 'other';
    final height = _heightCm ?? 170.0;

    // Weighted movement calculation: Body joints (80%) + Face points (20%)
    double weightedMovement = 0.0;

    // Face points (indices 0-4): Lower weight (20% total)
    for (int i = 0; i < 5; i++) {
      weightedMovement +=
          (_jointMovement[i] ?? 0.0) * 0.2; // 20% weight for face
    }

    // Body joints (indices 5-16): Higher weight (80% total)
    for (int i = 5; i < 17; i++) {
      weightedMovement +=
          (_jointMovement[i] ?? 0.0) * 0.8; // 80% weight for body
    }

    // Time-based factors
    final seconds = _elapsed.inSeconds;
    final minutes = seconds / 60.0;
    if (seconds <= 0) return 0.0;

    // Movement intensity (0.0 to 1.0) - Adjusted threshold for weighted movement
    final movementPerSecond = weightedMovement / seconds;
    final intensity =
        (movementPerSecond / 0.016).clamp(0.0, 1.0); // Adjusted threshold

    // Base MET calculation for exercise
    double baseMet = 3.0 + (4.0 * intensity); // 3.0 to 7.0 MET range

    // Age factor: Metabolism decreases with age
    // Younger people burn more calories for same activity
    double ageFactor = 1.0;
    if (age < 25) {
      ageFactor = 1.1; // 10% more calories
    } else if (age >= 25 && age < 35) {
      ageFactor = 1.05; // 5% more calories
    } else if (age >= 35 && age < 45) {
      ageFactor = 1.0; // Baseline
    } else if (age >= 45 && age < 55) {
      ageFactor = 0.95; // 5% less calories
    } else {
      ageFactor = 0.9; // 10% less calories
    }

    // Gender factor: Men typically burn more calories
    double genderFactor = 1.0;
    if (gender == 'male') {
      genderFactor = 1.1; // 10% more calories
    } else if (gender == 'female') {
      genderFactor = 0.9; // 10% less calories
    } else {
      genderFactor = 1.0; // Baseline for other/unknown
    }

    // Height factor: Taller people burn more calories
    // Based on body surface area approximation
    final heightFactor = (height / 170.0).clamp(0.8, 1.2);

    // Apply all factors to MET value
    final adjustedMet = baseMet * ageFactor * genderFactor * heightFactor;

    // Advanced calorie calculation using Harris-Benedict principles
    // Formula: Calories = MET × 3.5 × weight(kg) / 200 × duration(minutes)
    final totalCals = (adjustedMet * 3.5 * weight / 200.0) * minutes;

    final finalCalories = totalCals.clamp(0.0, 9999.0);

    if (kDebugMode && seconds % 30 == 0) {
      // Log every 30 seconds
      // Calculate face vs body movement for debugging
      double faceMovement = 0.0;
      double bodyMovement = 0.0;
      for (int i = 0; i < 5; i++) {
        faceMovement += (_jointMovement[i] ?? 0.0);
      }
      for (int i = 5; i < 17; i++) {
        bodyMovement += (_jointMovement[i] ?? 0.0);
      }

      debugPrint('🔥 Calorie Calculation:');
      debugPrint(
          '  Face Movement: ${faceMovement.toStringAsFixed(4)} (20% weight)');
      debugPrint(
          '  Body Movement: ${bodyMovement.toStringAsFixed(4)} (80% weight)');
      debugPrint('  Weighted Total: ${weightedMovement.toStringAsFixed(4)}');
      debugPrint('  Movement/sec: ${movementPerSecond.toStringAsFixed(4)}');
      debugPrint('  Intensity: ${(intensity * 100).toStringAsFixed(1)}%');
      debugPrint('  Base MET: ${baseMet.toStringAsFixed(2)}');
      debugPrint(
          '  Age Factor: ${ageFactor.toStringAsFixed(2)} (age: ${age.toStringAsFixed(0)})');
      debugPrint(
          '  Gender Factor: ${genderFactor.toStringAsFixed(2)} (gender: $gender)');
      debugPrint(
          '  Height Factor: ${heightFactor.toStringAsFixed(2)} (height: ${height.toStringAsFixed(0)}cm)');
      debugPrint('  Adjusted MET: ${adjustedMet.toStringAsFixed(2)}');
      debugPrint('  Final Calories: ${finalCalories.toStringAsFixed(1)}');
    }

    return finalCalories;
  }

  double _displayCalories() {
    return _editedCalories ?? _estimatedCalories();
  }

  void _startEditingCalories() {
    if (!mounted) return;
    setState(() {
      _editingCalories = true;
    });
  }

  void _saveCalories(String value) {
    final v = double.tryParse(value);
    if (v != null && v >= 0 && mounted) {
      setState(() {
        _editedCalories = v;
        _editingCalories = false;
      });
    } else if (mounted) {
      setState(() {
        _editingCalories = false;
      });
    }
  }

  void _cancelEditingCalories() {
    if (!mounted) return;
    setState(() {
      _editingCalories = false;
    });
  }

  Widget _buildCaloriesBadge() {
    // Only allow editing when workout is stopped
    final canEdit = !_isRunning;
    final hasWeight = _weightKg != null && _weightKg! > 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _badge(
          text: hasWeight
              ? 'kcal: ${_displayCalories().toStringAsFixed(1)}'
              : 'kcal: ${_displayCalories().toStringAsFixed(1)} (set weight)',
        ),
        if (canEdit) ...[
          const SizedBox(width: 6),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Tooltip(
              message: 'Edit calories',
              child: GestureDetector(
                onTap: _startEditingCalories,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCaloriesEditor() {
    final controller = TextEditingController(
      text: _displayCalories().toStringAsFixed(1),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 70,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                suffixText: 'kcal',
                suffixStyle: const TextStyle(color: Colors.white, fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.24)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.24)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: AppColors.accent),
                ),
              ),
              onSubmitted: _saveCalories,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _saveCalories(controller.text),
            child: Icon(
              Icons.check,
              size: 16,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _cancelEditingCalories,
            child: const Icon(
              Icons.close,
              size: 16,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  List<MapEntry<int, double>> _topJoints() {
    final entries = _jointMovement.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(3).toList();
  }

  Future<void> _editActivity(dynamic a) async {
    final activityId = (a as dynamic).uuid?.toString();
    if (activityId == null || activityId.isEmpty) return;

    final initialMinutes = ((a as dynamic).durationMinutes as int?) ?? 0;
    final initialKcal = ((a as dynamic).caloriesBurned as int?) ?? 0;
    final initialActivityDate = (a as dynamic).activityDate as DateTime?;
    final initialCreatedAt = (a as dynamic).createdAt as DateTime?;

    String initialNote = '';
    String? existingMlStatus;
    try {
      final rawRoute = (a as dynamic).routeData?.toString();
      if (rawRoute != null && rawRoute.isNotEmpty) {
        final decoded = jsonDecode(rawRoute);
        if (decoded is Map) {
          final notes = decoded['notes']?.toString();
          if (notes != null) initialNote = notes;
          existingMlStatus = decoded['ml_status']?.toString();
        }
      }
    } catch (_) {
      // ignore
    }

    final noteCtrl = TextEditingController(text: initialNote);
    final minutesCtrl = TextEditingController(text: initialMinutes.toString());
    final kcalCtrl = TextEditingController(text: initialKcal.toString());

    final didSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit workout',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Note',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.12)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.12)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.24)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minutesCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Minutes',
                        labelStyle:
                            TextStyle(color: Colors.white.withOpacity(0.7)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.white.withOpacity(0.12)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.white.withOpacity(0.12)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.white.withOpacity(0.24)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: kcalCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Calories',
                        labelStyle:
                            TextStyle(color: Colors.white.withOpacity(0.7)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.white.withOpacity(0.12)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.white.withOpacity(0.12)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.white.withOpacity(0.24)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.15),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Update'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (didSave != true) return;

    final minutes = int.tryParse(minutesCtrl.text.trim()) ?? initialMinutes;
    final kcal = int.tryParse(kcalCtrl.text.trim()) ?? initialKcal;
    final note = noteCtrl.text.trim();

    final routeData = <String, dynamic>{
      'notes': note.isEmpty ? 'Live pose session' : note,
    };
    if (existingMlStatus != null && existingMlStatus.isNotEmpty) {
      routeData['ml_status'] = existingMlStatus;
    }

    final payload = {
      'id': activityId,
      'activity_type': (a as dynamic).activityType?.toString() ?? 'workout',
      'activity_date':
          (initialActivityDate ?? DateTime.now()).toIso8601String(),
      'distance_km': ((a as dynamic).distanceKm as num?)?.toDouble() ?? 0.0,
      'duration_minutes': minutes.clamp(0, 9999),
      'calories_burned': kcal.clamp(0, 999999),
      'route_data': jsonEncode(routeData),
      'created_at': (initialCreatedAt ?? DateTime.now()).toIso8601String(),
    };

    try {
      await _storage.updateActivity(activityId, payload);
      await _loadTodayActivities();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Workout updated'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _mlStatusText() {
    if (kIsWeb) {
      // Provide more helpful feedback for web users
      if (_webStatus.contains('loading_model')) {
        return 'ML: Loading model... (~30s)';
      } else if (_webStatus.contains('requesting_camera')) {
        return 'ML: Requesting camera...';
      } else if (_webStatus.contains('init')) {
        return 'ML: Initializing...';
      } else if (_webStatus.contains('error')) {
        return 'ML: Error - Check permissions';
      } else if (_webStatus.contains('running')) {
        return _webStatus; // Show FPS when running
      }
      return _webStatus;
    }
    if (_interpreter == null) return 'ML: model missing';
    if (_isRunning) return 'ML: running';
    return 'ML: ready';
  }

  Future<void> _saveTodayWorkout() async {
    if (_saving) return;
    setState(() {
      _saving = true;
    });

    try {
      final now = DateTime.now();
      final id = now.microsecondsSinceEpoch.toString();

      final payload = {
        'id': id,
        'activity_type': 'workout',
        'activity_date': now.toIso8601String(),
        'distance_km': 0.0,
        'duration_minutes': (_elapsed.inSeconds / 60).round().clamp(0, 9999),
        'calories_burned': _displayCalories().round().clamp(0, 999999),
        'route_data': jsonEncode({
          'notes': _note.isEmpty ? 'Live pose session' : _note,
          'ml_status': _mlStatusText(),
        }),
        'created_at': now.toIso8601String(),
      };

      await _storage.addActivity(payload);
      await StreakService.markActiveToday();
      await _loadTodayActivities();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Saved to today\'s activities'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _onWebKeypoints(List<Map<String, dynamic>> keypoints) {
    debugPrint(
        '🔍 _onWebKeypoints called: ${keypoints.length} keypoints, _isRunning=$_isRunning');

    if (!_isRunning || !mounted) {
      debugPrint(
          '⚠️ Skipping keypoints: _isRunning=$_isRunning, mounted=$mounted');
      return;
    }

    try {
      // Convert web keypoints to _Keypoint format
      final kp = <_Keypoint>[];
      for (final k in keypoints) {
        final index = k['index'] as int? ?? 0;
        final x = k['x'] as double? ?? 0.0;
        final y = k['y'] as double? ?? 0.0;
        final confidence = k['confidence'] as double? ?? 0.0;

        kp.add(_Keypoint(
          index: index,
          x: x,
          y: y,
          confidence: confidence,
        ));
      }

      // Process through existing movement tracking
      if (kp.length == 17) {
        _accumulateMovement(kp);

        // Calculate max confidence from web keypoints so the overlay updates
        double maxConf = 0.0;
        for (final k in kp) {
          if (k.confidence > maxConf) maxConf = k.confidence;
        }

        debugPrint(
            '✅ Movement accumulated. _jointMovement entries: ${_jointMovement.length}');

        // Update keypoints for display (though web draws its own skeleton)
        if (!mounted) return;
        setState(() {
          _keypoints = kp;
          _maxConf = maxConf;
        });
      } else {
        debugPrint('⚠️ Wrong keypoint count: ${kp.length}, expected 17');
      }
    } catch (e) {
      debugPrint('❌ Error processing web keypoints: $e');
    }
  }

  Future<void> _requestCameraPermission() async {
    if (!kIsWeb) return;

    try {
      // Direct JavaScript call to request camera permission
      final result = await js.context.callMethod('eval', <Object?>[
        '''
        (async function() {
          try {
            const stream = await navigator.mediaDevices.getUserMedia({
              video: { facingMode: 'user' },
              audio: false,
            });
            stream.getTracks().forEach(track => track.stop());
            return { success: true, message: 'Camera permission granted' };
          } catch (error) {
            if (error.name === 'NotAllowedError') {
              return { success: false, message: 'Camera permission denied' };
            } else if (error.name === 'NotFoundError') {
              return { success: false, message: 'No camera found' };
            } else {
              return { success: false, message: error.message };
            }
          }
        })()
        '''
      ]);

      if (result is js.JsObject) {
        final success = result['success'];
        if (success == true && mounted) {
          setState(() {
            _webStatus = 'web: permission granted - retrying...';
          });

          // Retry initialization after a short delay
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted) {
              setState(() {
                _webStatus = 'web: idle';
              });
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error requesting camera permission: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cam = _cameraController;

    return ShootingStarsAmbientBackground(
      child: GradientScaffold(
        appBar: AppBar(
          title: const Text('Workouts'),
          actions: [
            // Mode selector dropdown
            PopupMenuButton<WorkoutMode>(
              icon: Icon(_getModeIcon()),
              tooltip: 'Workout Mode',
              onSelected: _switchWorkoutMode,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: WorkoutMode.cameraOnly,
                  child: Row(
                    children: [
                      Icon(Icons.camera_alt),
                      SizedBox(width: 8),
                      Text('Camera Only'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: WorkoutMode.videoOnly,
                  child: Row(
                    children: [
                      Icon(Icons.video_library),
                      SizedBox(width: 8),
                      Text('Video Only'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: WorkoutMode.split,
                  child: Row(
                    children: [
                      Icon(Icons.view_column),
                      SizedBox(width: 8),
                      Text('Split Screen'),
                    ],
                  ),
                ),
              ],
            ),
            // Camera switch button (front/back)
            if (!kIsWeb && _availableCameras.length > 1)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: IconButton(
                  icon: const Icon(Icons.cameraswitch),
                  tooltip: 'Switch Camera',
                  onPressed: _toggleCamera,
                ),
              ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: IconButton(
                icon: Icon(
                    _fullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
                tooltip: _fullScreen ? 'Exit Fullscreen' : 'Fullscreen',
                onPressed: () {
                  setState(() {
                    _fullScreen = !_fullScreen;
                  });
                },
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: IconButton(
                icon: Icon(
                    _showSkeleton ? Icons.visibility : Icons.visibility_off),
                tooltip: 'Toggle Skeleton Overlay',
                onPressed: () {
                  setState(() {
                    _showSkeleton = !_showSkeleton;
                  });
                },
              ),
            ),
            MouseRegion(
              cursor:
                  _saving ? SystemMouseCursors.basic : SystemMouseCursors.click,
              child: IconButton(
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                tooltip: 'Save Workout',
                onPressed: _saving
                    ? null
                    : () async {
                        final note = await _pickNote(context, initial: _note);
                        if (note == null) return;
                        if (!mounted) return;
                        setState(() {
                          _note = note;
                        });
                        await _saveTodayWorkout();
                      },
              ),
            ),
            MouseRegion(
              cursor: _cameraError != null
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              child: IconButton(
                icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
                tooltip: _isRunning ? 'Stop Workout' : 'Start Workout',
                onPressed: _cameraError != null
                    ? null
                    : () {
                        if (_isRunning) {
                          _stop();
                        } else {
                          _start();
                        }
                      },
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(child: _buildWorkoutView(cam)),
                if (!_fullScreen && !_videoFullscreen && !_cameraFullscreen)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        _buildStatsPanel(), // Most moved stats panel (2nd)
                        const SizedBox(height: 12),
                        _buildTodayActivitiesPanel(), // Today's activities (3rd)
                      ],
                    ),
                  ),
              ],
            ),
            // Removed draggable bottom sheet - stats now shown at top
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutView(CameraController? cam) {
    switch (_workoutMode) {
      case WorkoutMode.cameraOnly:
        return _buildCameraPanel(cam);
      case WorkoutMode.videoOnly:
        return _buildVideoPanel();
      case WorkoutMode.split:
        return _buildSplitView(cam);
    }
  }

  Widget _buildSplitView(CameraController? cam) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    if (isPortrait) {
      // Stack vertically in portrait
      return Column(
        children: [
          Expanded(child: _buildCameraPanel(cam)),
          Expanded(child: _buildVideoPanel()),
        ],
      );
    } else {
      // Stack horizontally in landscape
      return Row(
        children: [
          Expanded(child: _buildCameraPanel(cam)),
          Expanded(child: _buildVideoPanel()),
        ],
      );
    }
  }

  Widget _buildVideoPanel() {
    final controller = _videoController;
    final margin = (_fullScreen || _videoFullscreen)
        ? EdgeInsets.zero
        : const EdgeInsets.all(16);
    final radius = (_fullScreen || _videoFullscreen) ? 0.0 : 18.0;

    if (controller == null || !controller.value.isInitialized) {
      return Container(
        margin: margin,
        decoration: BoxDecoration(
          color: AppColors.card.withOpacity(0.5),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.video_library,
                size: 64,
                color: Colors.white.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              const Text(
                'No video selected',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.video_library),
                label: const Text('Pick Video'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.5),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
            // Video controls overlay
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildVideoControls(controller),
            ),
            // Fullscreen toggle
            if (_workoutMode == WorkoutMode.split)
              Positioned(
                top: 12,
                right: 12,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _videoFullscreen = !_videoFullscreen;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _videoFullscreen
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoControls(VideoPlayerController controller) {
    final position = controller.value.position;
    final duration = controller.value.duration;
    final isPlaying = controller.value.isPlaying;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            colors: VideoProgressColors(
              playedColor: AppColors.accent,
              bufferedColor: Colors.white.withOpacity(0.3),
              backgroundColor: Colors.white.withOpacity(0.1),
            ),
          ),
          const SizedBox(height: 8),
          // Control buttons
          Row(
            children: [
              // Play/Pause
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: _toggleVideoPlayback,
                ),
              ),
              // Stop
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: IconButton(
                  icon: const Icon(Icons.stop, color: Colors.white),
                  onPressed: _stopVideo,
                ),
              ),
              const SizedBox(width: 8),
              // Time display
              Text(
                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildCameraPanel(CameraController? cam) {
    final margin = _fullScreen ? EdgeInsets.zero : const EdgeInsets.all(16);
    final radius = _fullScreen ? 0.0 : 18.0;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.5),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            Positioned.fill(
              child: kIsWeb
                  ? WebPoseView(
                      overlayEnabled: _showSkeleton,
                      onStatus: (s) {
                        if (!mounted) return;
                        if (s == _webStatus) return;
                        setState(() {
                          _webStatus = s;
                        });
                      },
                      onKeypoints: _onWebKeypoints,
                    )
                  : (cam != null && cam.value.isInitialized)
                      ? CameraPreview(cam)
                      : _centerText('Initializing camera...'),
            ),
            if (!kIsWeb && _showSkeleton)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _PosePainter(
                      keypoints: _keypoints,
                      jointMovement: _jointMovement,
                      debugMode: _debugMode,
                    ),
                  ),
                ),
              ),
            // ML Confidence Overlay
            if (_isRunning)
              Positioned(
                bottom: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _debugMode = !_debugMode;
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _maxConf > 0.20 ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Confidence: ${(_maxConf * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_cameraError != null)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _cameraError!,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            Positioned(
              left: 12,
              top: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (_isRunning ? Colors.green : Colors.grey)
                      .withOpacity(0.8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isRunning ? Icons.fiber_manual_record : Icons.pause,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Time: ${_elapsed.inMinutes.toString().padLeft(2, '0')}:${(_elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: _editingCalories
                  ? _buildCaloriesEditor()
                  : _buildCaloriesBadge(),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _badge(text: _mlStatusText()),
                  _badge(text: 'Points: ${_keypoints.length}/17'),
                  if (kIsWeb && _webStatus.contains('permission')) ...[
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _requestCameraPermission,
                      icon: const Icon(Icons.camera_alt, size: 16),
                      label: const Text('Allow Camera'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                  if (_isRunning && !kIsWeb) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'RECORDING',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Fullscreen toggle for camera in split mode
            if (_workoutMode == WorkoutMode.split)
              Positioned(
                top: 12,
                left: 12,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _cameraFullscreen = !_cameraFullscreen;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _cameraFullscreen
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<String?> _pickNote(BuildContext context,
      {required String initial}) async {
    final controller = TextEditingController(text: initial);
    const presets = <String>[
      'Pushups',
      'Squats',
      'Yoga',
      'Cardio',
      'Stretching',
      'Other',
    ];

    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Note',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets
                    .map(
                      (p) => OutlinedButton(
                        onPressed: () {
                          controller.text = p == 'Other' ? '' : p;
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.15),
                          ),
                        ),
                        child: Text(p),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Type a note (optional)',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.12)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.12)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.24)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(null),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.15),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.of(ctx).pop(controller.text.trim()),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTodayActivitiesPanel() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Today's Activities",
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadTodayActivities,
                icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_todayActivities.isEmpty)
            const Text(
              'No activities recorded today',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            )
          else
            ..._todayActivities.take(4).map((a) {
              // Works for both IO ActivityIsar and web ActivityIsar shim.
              final type = (a as dynamic).activityType?.toString() ?? 'unknown';
              final minutes = ((a as dynamic).durationMinutes as int?) ?? 0;
              final kcal = ((a as dynamic).caloriesBurned as int?) ?? 0;
              final canEdit = type == 'workout';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        type,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${minutes}m  ${kcal}kcal',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (canEdit) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: () => _editActivity(a),
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: AppColors.textPrimary,
                        ),
                        tooltip: 'Edit workout',
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ],
                ),
              );
            }),
          if (_todayActivities.length > 4)
            Text(
              '+${_todayActivities.length - 4} more…',
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          const SizedBox(height: 6),
          if (_mlError != null)
            Text(
              _mlError!,
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsPanel() {
    final allJoints = _jointMovement.entries.toList();
    allJoints.sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Most moved',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (!_isRunning)
                  const Text(
                    'Press play to start tracking.',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  )
                else if (_keypoints.isEmpty)
                  const Text(
                    'Detecting body...',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  )
                else if (allJoints.isEmpty)
                  Text(
                    'Move around to track... (${_keypoints.length} points detected)',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  )
                else
                  // Scrollable list showing ALL body parts
                  SizedBox(
                    height: 120, // Fixed height for scrollable area
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: allJoints.map((e) {
                          // Calculate intensity level for visual feedback
                          final percentage = (e.value * 100);
                          final intensity =
                              (percentage / allJoints.first.value * 100)
                                  .clamp(0.0, 100.0);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                // Movement bar indicator
                                Container(
                                  width: 3,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: intensity > 70
                                        ? Colors.green
                                        : intensity > 40
                                            ? Colors.orange
                                            : Colors.blue,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _jointName(e.key),
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${percentage.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                // Show detection status
                if (_keypoints.isNotEmpty && _keypoints.length < 17)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${_keypoints.length}/17 points detected',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 52,
            color: Colors.white.withOpacity(0.08),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Weight',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _weightKg == null
                    ? 'Not set'
                    : '${_weightKg!.toStringAsFixed(1)} kg',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableStatsSheet() {
    final allJoints = _jointMovement.entries.toList();
    allJoints.sort((a, b) => b.value.compareTo(a.value));

    return DraggableScrollableSheet(
      initialChildSize: 0.15,
      minChildSize: 0.15,
      maxChildSize: 0.6,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Most moved',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (_weightKg != null)
                          Text(
                            'Weight: ${_weightKg!.toStringAsFixed(1)} kg',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!_isRunning)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Press play to start tracking.',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else if (_keypoints.isEmpty || _keypoints.length < 17)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Detecting body... ${_keypoints.length}/17 points',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else if (allJoints.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Move around to track joints...',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...allJoints.map((e) => Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 12),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: AppColors.background.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _jointName(e.key),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  (e.value * 100).toStringAsFixed(1),
                                  style: TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _badge({required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _centerText(String text) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }

  String _jointName(int i) {
    switch (i) {
      case 0:
        return 'Nose';
      case 1:
        return 'L Eye';
      case 2:
        return 'R Eye';
      case 3:
        return 'L Ear';
      case 4:
        return 'R Ear';
      case 5:
        return 'L Shoulder';
      case 6:
        return 'R Shoulder';
      case 7:
        return 'L Elbow';
      case 8:
        return 'R Elbow';
      case 9:
        return 'L Wrist';
      case 10:
        return 'R Wrist';
      case 11:
        return 'L Hip';
      case 12:
        return 'R Hip';
      case 13:
        return 'L Knee';
      case 14:
        return 'R Knee';
      case 15:
        return 'L Ankle';
      case 16:
        return 'R Ankle';
      default:
        return 'Point $i';
    }
  }

  // Returns input tensor [1, size, size, 3] float32 normalized 0..1
  List _yuv420ToRgbNormalized(
      CameraImage image, int outW, int outH, int rotation) {
    final width = image.width;
    final height = image.height;

    final yPlane = image.planes[0].bytes;
    final uPlane = image.planes[1].bytes;
    final vPlane = image.planes[2].bytes;

    final yRowStride = image.planes[0].bytesPerRow;
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    final floatData = Float32List(outW * outH * 3);

    for (int y = 0; y < outH; y++) {
      for (int x = 0; x < outW; x++) {
        // Calculate source coordinates based on rotation
        int srcX, srcY;
        if (rotation == 90) {
          srcX = (y * width) ~/ outH;
          srcY = ((outW - x - 1) * height) ~/ outW;
        } else if (rotation == 270) {
          srcX = ((outH - y - 1) * width) ~/ outH;
          srcY = (x * height) ~/ outW;
        } else if (rotation == 180) {
          srcX = ((outW - x - 1) * width) ~/ outW;
          srcY = ((outH - y - 1) * height) ~/ outH;
        } else {
          srcX = (x * width) ~/ outW;
          srcY = (y * height) ~/ outH;
        }

        // Clamp to ensure we don't go out of bounds
        srcX = srcX.clamp(0, width - 1);
        srcY = srcY.clamp(0, height - 1);

        final yIndex = srcY * yRowStride + srcX;

        final uvX = (srcX / 2).floor();
        final uvY = (srcY / 2).floor();
        final uvIndex = uvY * uvRowStride + uvX * uvPixelStride;

        final yValue = yPlane[yIndex];
        final uValue = uPlane[uvIndex];
        final vValue = vPlane[uvIndex];

        final yf = yValue.toDouble();
        final uf = uValue.toDouble() - 128.0;
        final vf = vValue.toDouble() - 128.0;

        var r = yf + 1.402 * vf;
        var g = yf - 0.344136 * uf - 0.714136 * vf;
        var b = yf + 1.772 * uf;

        r = r.clamp(0.0, 255.0);
        g = g.clamp(0.0, 255.0);
        b = b.clamp(0.0, 255.0);

        final idx = (y * outW + x) * 3;
        floatData[idx] = r / 255.0;
        floatData[idx + 1] = g / 255.0;
        floatData[idx + 2] = b / 255.0;
      }
    }

    // MoveNet Lightning expects [1, 192, 192, 3] input.
    // Instead of deep nesting with List.generate (slow), we use a simpler nested list structure
    // which tflite_flutter can handle more efficiently.
    final out = List.generate(1, (_) {
      return List.generate(outH, (y) {
        return List.generate(outW, (x) {
          final idx = (y * outW + x) * 3;
          return <double>[
            floatData[idx],
            floatData[idx + 1],
            floatData[idx + 2],
          ];
        });
      });
    });

    return out;
  }

  dynamic _yuv420ToRgbUint8(
      CameraImage image, int outW, int outH, int rotation) {
    final width = image.width;
    final height = image.height;

    final yPlane = image.planes[0].bytes;
    final uPlane = image.planes[1].bytes;
    final vPlane = image.planes[2].bytes;

    final yRowStride = image.planes[0].bytesPerRow;
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

    final byteData = Uint8List(1 * outH * outW * 3);

    for (int y = 0; y < outH; y++) {
      for (int x = 0; x < outW; x++) {
        int srcX, srcY;
        if (rotation == 90) {
          srcX = (y * width) ~/ outH;
          srcY = ((outW - x - 1) * height) ~/ outW;
        } else if (rotation == 270) {
          srcX = ((outH - y - 1) * width) ~/ outH;
          srcY = (x * height) ~/ outW;
        } else if (rotation == 180) {
          srcX = ((outW - x - 1) * width) ~/ outW;
          srcY = ((outH - y - 1) * height) ~/ outH;
        } else {
          srcX = (x * width) ~/ outW;
          srcY = (y * height) ~/ outH;
        }

        srcX = srcX.clamp(0, width - 1);
        srcY = srcY.clamp(0, height - 1);

        final yIndex = srcY * yRowStride + srcX;
        final uvX = srcX >> 1;
        final uvY = srcY >> 1;
        final uvIndex = uvY * uvRowStride + uvX * uvPixelStride;

        final yValue = yPlane[yIndex];
        final uValue = uPlane[uvIndex];
        final vValue = vPlane[uvIndex];

        final yf = yValue.toDouble();
        final uf = uValue.toDouble() - 128.0;
        final vf = vValue.toDouble() - 128.0;

        var r = (yf + 1.402 * vf).clamp(0.0, 255.0);
        var g = (yf - 0.344136 * uf - 0.714136 * vf).clamp(0.0, 255.0);
        var b = (yf + 1.772 * uf).clamp(0.0, 255.0);

        final idx = (y * outW + x) * 3;
        byteData[idx] = r.round();
        byteData[idx + 1] = g.round();
        byteData[idx + 2] = b.round();
      }
    }

    return [
      List.generate(outH, (y) {
        return List.generate(outW, (x) {
          final i = (y * outW + x) * 3;
          return [byteData[i], byteData[i + 1], byteData[i + 2]];
        });
      })
    ];
  }

  double _calculateInputMean(List input) {
    try {
      double sum = 0;
      int count = 0;
      for (var y = 0; y < 192; y++) {
        for (var x = 0; x < 192; x++) {
          final p = input[0][y][x] as List;
          sum += (p[0] as num) + (p[1] as num) + (p[2] as num);
          count += 3;
        }
      }
      return sum / count;
    } catch (_) {
      return -1;
    }
  }
}

class _Keypoint {
  const _Keypoint({
    required this.index,
    required this.x,
    required this.y,
    required this.confidence,
  });

  final int index;
  final double x;
  final double y;
  final double confidence;
}

class _PosePainter extends CustomPainter {
  const _PosePainter({
    required this.keypoints,
    required this.jointMovement,
    this.debugMode = false,
  });

  final List<_Keypoint> keypoints;
  final Map<int, double> jointMovement;
  final bool debugMode;

  static const _edges = <List<int>>[
    [5, 7],
    [7, 9],
    [6, 8],
    [8, 10],
    [5, 6],
    [5, 11],
    [6, 12],
    [11, 12],
    [11, 13],
    [13, 15],
    [12, 14],
    [14, 16],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (keypoints.length != 17) return;

    final pLine = Paint()
      ..color = AppColors.secondary.withOpacity(0.9)
      ..strokeWidth = 4 // Increased from 3 for better visibility
      ..style = PaintingStyle.stroke;

    Offset toOffset(_Keypoint k) {
      return Offset(k.x * size.width, k.y * size.height);
    }

    // Draw skeleton lines
    for (final e in _edges) {
      final a = keypoints[e[0]];
      final b = keypoints[e[1]];
      if (a.confidence < 0.1 || b.confidence < 0.1) continue;
      canvas.drawLine(toOffset(a), toOffset(b), pLine);
    }

    // Draw keypoints (no movement text)
    for (final k in keypoints) {
      if (k.confidence < 0.1) continue;

      final movement = jointMovement[k.index] ?? 0.0;
      final offset = toOffset(k);

      // Single color for all keypoints
      final movementPaint = Paint()
        ..color = AppColors.accent.withOpacity(0.9)
        ..style = PaintingStyle.fill;

      // Draw larger circle for high movement (visual indicator without text)
      final radius = movement > 20 ? 8.0 : 6.0;
      canvas.drawCircle(offset, radius, movementPaint);
    }

    if (debugMode) {
      // Draw a fixed center marker to verify the painter is working
      final debugPaint = Paint()..color = Colors.red;
      canvas.drawCircle(
          Offset(size.width / 2, size.height / 2), 10, debugPaint);

      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'RENDERER ACTIVE',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(size.width / 2 - 50, size.height / 2 + 15));
    }
  }

  @override
  bool shouldRepaint(covariant _PosePainter oldDelegate) {
    return oldDelegate.keypoints != keypoints ||
        oldDelegate.jointMovement != jointMovement;
  }
}
