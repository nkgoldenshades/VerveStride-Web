import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/ui_constants.dart';
import '../../core/routes.dart';
import 'package:vervestride/models/user_profile.dart';
import '../../services/local_storage_service.dart';
import '../../services/streak_service.dart';
import '../../services/haptic_service.dart';
import '../../widgets/floating_quick_add.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/share_template.dart';
import '../../widgets/shooting_star_button.dart';
import '../../widgets/shooting_stars_background.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  // Static reference to the active instance for persistent access
  static _HomeScreenState? _activeInstance;

  static Future<void> globalRefresh() async {
    await _activeInstance?.refreshData();
  }

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocalStorageService _storage = LocalStorageService.instance;
  DateTime selectedDate = DateTime.now();

  // Data state
  int _burnedCaloriesToday = 0;
  int _targetBurnCalories = 400;
  int _waterDrunkMl = 0;
  int _waterGoalMl = 3000;
  int _streakDays = 0;

  // Visual state
  bool _showCompletionPulse = false;
  bool _completionCelebrated = false;
  bool _showStreakFlame = false;
  bool _isInitializing = true;

  // Central today status
  bool _isAllDone(int completed, int total) {
    return completed >= total;
  }

  // Cache expensive calculations
  late final Map<String, double> _progressCache = {};

  void _clearProgressCache() {
    _progressCache.clear();
  }

  @override
  void initState() {
    super.initState();
    HomeScreen._activeInstance = this;
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Ensure LocalStorageService is initialized before loading data
      await _storage.init();

      // Now safe to load data
      await _loadData();
    } catch (e) {
      debugPrint('Error initializing home screen: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    HomeScreen._activeInstance = null;
    super.dispose();
  }

  // Public method to refresh data when called from other screens
  Future<void> refreshData() async {
    await _loadData();
    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    _clearProgressCache(); // Clear cache when reloading data
    await Future.wait([
      _loadBurnedCalories(),
      _loadTargets(),
      _loadWaterData(),
      _loadStreakData(),
    ]);
  }

  Future<void> _loadStreakData() async {
    try {
      final streak = await StreakService.loadNormalized();
      if (!mounted) return;
      setState(() {
        _streakDays = streak.streakDays;
        _showStreakFlame = streak.isTodayActive && streak.streakDays > 0;
      });
    } catch (_) {
      if (!mounted) return;
    }
  }

  bool get _isSelectedToday {
    final now = DateTime.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
  }

  int _estimateBurnTargetFromActivityLevel(int level) {
    switch (level) {
      case 1:
        return 200;
      case 2:
        return 300;
      case 3:
        return 400;
      case 4:
        return 550;
      case 5:
        return 700;
      default:
        return 400;
    }
  }

  Future<void> _loadBurnedCalories() async {
    try {
      final activities = await _storage.getActivitiesForDate(selectedDate);
      final burned = activities.fold<int>(
        0,
        (sum, a) => sum + (a.caloriesBurned),
      );
      if (!mounted) return;
      setState(() {
        _burnedCaloriesToday = burned;
      });
    } catch (_) {
      if (!mounted) return;
    }
  }

  Future<void> _loadTargets() async {
    try {
      final json = await _storage.getUserProfile();
      if (json == null) return;
      final profile = UserProfile.fromJson(json);
      final active = profile.activeGoalForDate(DateTime.now());
      final overrideBurn = active?.targetBurnCalories;
      if (!mounted) return;
      setState(() {
        _targetBurnCalories = (overrideBurn != null && overrideBurn > 0)
            ? overrideBurn
            : _estimateBurnTargetFromActivityLevel(profile.activityLevel);
      });
    } catch (_) {
      if (!mounted) return;
    }
  }

  Future<void> _loadWaterData() async {
    try {
      final profileJson = await _storage.getUserProfile();
      final profile =
          profileJson != null ? UserProfile.fromJson(profileJson) : null;
      final targets = profile?.calculateDailyTargets(forDate: selectedDate);
      final active = profile?.activeGoalForDate(selectedDate);
      final overrideWater = active?.targetWaterMl;
      final goal = (overrideWater != null && overrideWater > 0)
          ? overrideWater
          : ((targets?['waterMl'] as num?)?.toInt() ??
              (profile != null ? (profile.weightKg * 35).round() : 3000));
      final drunk = await _storage.getWaterForDate(selectedDate);
      if (!mounted) return;
      setState(() {
        _waterGoalMl = goal;
        _waterDrunkMl = drunk;
      });
    } catch (_) {
      if (!mounted) return;
    }
  }

  Future<void> _addWater(int ml) async {
    if (!_isSelectedToday) return;
    await LocalStorageService.instance.addWaterForToday(ml);
    await _loadWaterData();
  }

  Future<void> _subtractWater(int ml) async {
    if (!_isSelectedToday) return;
    await LocalStorageService.instance.removeWaterForToday(ml);
    await _loadWaterData();
  }

  Future<void> _showCustomWaterDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Amount'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount (ml)',
            hintText: '500',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final amount = int.tryParse(controller.text);
              if (amount == null) {
                Navigator.pop(context);
                return;
              }
              Navigator.pop(context, -amount);
            },
            child: const Text('Subtract'),
          ),
          TextButton(
            onPressed: () {
              final amount = int.tryParse(controller.text);
              Navigator.pop(context, amount);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == null) return;
    if (result > 0) {
      await _addWater(result);
    } else if (result < 0) {
      await _subtractWater(-result);
    }
  }

  void showShareDialog() {
    final burnPercent = _targetBurnCalories > 0
        ? (_burnedCaloriesToday / _targetBurnCalories).clamp(0.0, 1.0)
        : 0.0;
    final waterPercent =
        _waterGoalMl > 0 ? (_waterDrunkMl / _waterGoalMl).clamp(0.0, 1.0) : 0.0;
    final overallPercent = ((burnPercent + waterPercent) / 2).clamp(0.0, 1.0);

    showDialog(
      context: context,
      builder: (context) => ShareTemplate(
        streakDays: _streakDays,
        completionPercent: overallPercent,
        weeklyAvg: 0.7,
        strongestHabit: 'Hydration',
        userName: 'User',
      ),
    );
  }

  Future<void> _refreshToday() async {
    await _loadData();
  }

  Future<void> _incrementStreakOnCompletion() async {
    try {
      await StreakService.markActiveToday();
      await _loadStreakData();
    } catch (_) {
      // Silently fail - streak is not critical
    }
  }

  // Progress ring building
  Widget _buildProgressRings(List<_RingSpec> specs, double displayPercent,
      {double ringSize = 200}) {
    return SizedBox(
      width: ringSize,
      height: ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background rings
          ...specs.asMap().entries.map((entry) {
            final index = entry.key;
            return _buildBackgroundRing(ringSize, index);
          }),
          // Progress rings
          ...specs.asMap().entries.map((entry) {
            final index = entry.key;
            final spec = entry.value;
            return _buildProgressRing(
                spec.percent, spec.color, ringSize, index);
          }),
          // Single percentage text (static)
          Text(
            '${(displayPercent * 100).round()}%',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundRing(double size, int index) {
    final strokeWidth = 7.0;
    final ringSize = size - (index * 20);

    return Center(
      child: Container(
        width: ringSize,
        height: ringSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
            width: strokeWidth,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressRing(
      double percent, Color color, double size, int index) {
    final strokeWidth = 12.0; // Premium thickness - substantial but not bulky
    final ringSize = size - (index * 20);

    return Center(
      child: Container(
        width: ringSize,
        height: ringSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withOpacity(0.3),
            width: strokeWidth - 3, // Background slightly thinner for depth
          ),
        ),
        child: Stack(
          children: [
            // Progress ring - clean, no glow
            CustomPaint(
              size: Size(ringSize, ringSize),
              painter: ProgressRingPainter(
                progress: percent,
                color: color,
                strokeWidth: strokeWidth,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return GradientScaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Calculate raw percentages
    final burnPercent = _targetBurnCalories > 0
        ? (_burnedCaloriesToday / _targetBurnCalories)
        : 0.0;
    final waterPercent =
        _waterGoalMl > 0 ? (_waterDrunkMl / _waterGoalMl) : 0.0;

    // Define today's habits (total = 2: Movement + Hydration)
    const totalHabitsToday = 2;

    // Calculate completed habits
    final movementDone = burnPercent >= 0.999;
    final hydrationDone = waterPercent >= 0.70;
    final completedHabits = (movementDone ? 1 : 0) + (hydrationDone ? 1 : 0);

    // Calculate incremental progress (smooth decimals)
    final movementProgress = burnPercent; // 0.0 to 1.0
    final hydrationProgress = (waterPercent / 0.70).clamp(
        0.0, 1.0); // Scale: 70% water = 100% hydration progress, capped at 1.0

    // Overall progress is weighted average of both habits
    final overallProgress = (movementProgress + hydrationProgress) / 2.0;

    // Keep smooth decimals - no rounding, no clamping to 1.0
    final cappedProgress = overallProgress.clamp(0.0, 1.0);

    // Use central status check
    final isAllDone = _isAllDone(completedHabits, totalHabitsToday);

    // Reset completion latch when progress drops below done state.
    // Important: never call setState synchronously during build.
    if (!isAllDone && _completionCelebrated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_completionCelebrated) return;
        setState(() {
          _completionCelebrated = false;
          _showCompletionPulse = false;
        });
      });
    }

    // Determine next action
    final habitItems = <String>[];
    if (!hydrationDone) habitItems.add('Water');
    if (!movementDone) habitItems.add('Movement');
    final nextAction = habitItems.isNotEmpty ? habitItems.first : null;

    // Trigger completion state when all done.
    // Important: never call setState synchronously during build (can cause jank/freezes).
    if (isAllDone && !_completionCelebrated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _completionCelebrated) return;
        setState(() {
          _completionCelebrated = true;
          _showCompletionPulse = true;
        });

        // Success haptic - celebrate!
        HapticService.instance.success();

        _incrementStreakOnCompletion();

        // Reset visual state after delay
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() {
              _showCompletionPulse = false;
            });
          }
        });
      });
    }

    return ShootingStarsAmbientBackground(
      child: GradientScaffold(
        body: SafeArea(
          child: Stack(
            children: [
              // MAIN SCROLLABLE CONTENT
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: UIConstants.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    UIConstants.spacingBetweenSections,

                    // ┌──────── Progress Card ────────┐
                    Container(
                      padding: UIConstants.cardPadding,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.card.withOpacity(0.98),
                            AppColors.card.withOpacity(0.92),
                          ],
                        ),
                        borderRadius:
                            BorderRadius.circular(UIConstants.radiusXL),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 8,
                            color: Colors.black.withOpacity(0.06),
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            blurRadius: 20,
                            color: Colors.black.withOpacity(0.03),
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Circular Progress
                          Center(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                // Use available width but ensure reasonable height
                                final availableWidth = constraints.maxWidth;
                                final ringSize = availableWidth.clamp(
                                    200.0, 280.0); // More flexible range
                                final ringSpecs = <_RingSpec>[
                                  _RingSpec(
                                    percent:
                                        cappedProgress, // Overall progress for consistency with center text
                                    color: AppColors.primary,
                                  ),
                                ];

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: UIConstants.paddingXL,
                                      vertical: UIConstants.paddingMD),
                                  child: StreakFlame(
                                    isGrowing: _showStreakFlame,
                                    child: PulseRing(
                                      isActive: _showCompletionPulse,
                                      color: Theme.of(context).primaryColor,
                                      child: _buildProgressRings(
                                        ringSpecs,
                                        cappedProgress, // Pass static percentage
                                        ringSize: ringSize,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          UIConstants.spacingBetweenItems,

                          // Status Info
                          Column(
                            children: [
                              Text(
                                isAllDone
                                    ? 'All done today 🎉'
                                    : '${habitItems.length} ${habitItems.length == 1 ? 'thing' : 'things'} left today',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_streakDays > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppColors.primary.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '🔥 ${_streakDays}-day streak',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // └───────────────────────────────┘

                    const SizedBox(height: 16),

                    // ┌──────── Action Card ──────────┐
                    if (!isAllDone)
                      Container(
                        padding: UIConstants.cardPadding,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.card.withOpacity(0.98),
                              AppColors.card.withOpacity(0.92),
                            ],
                          ),
                          borderRadius:
                              BorderRadius.circular(UIConstants.radiusXL),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 8,
                              color: Colors.black.withOpacity(0.06),
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              blurRadius: 20,
                              color: Colors.black.withOpacity(0.03),
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title (bold)
                            const Text(
                              "Today",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Sub text (lighter)
                            Text(
                              !hydrationDone && !movementDone
                                  ? 'Hydration and movement are still open'
                                  : !hydrationDone
                                      ? 'Hydration is still open'
                                      : 'Movement is still open',
                              style: UIConstants.statusText,
                            ),
                            const SizedBox(height: UIConstants.spacingSM),
                            if (nextAction != null)
                              Text(
                                nextAction == 'Water'
                                    ? 'You could do: Drink water'
                                    : nextAction == 'Movement'
                                        ? 'You could do: Move your body'
                                        : 'You could do: Drink water',
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      AppColors.textSecondary.withOpacity(0.7),
                                ),
                              ),

                            UIConstants.spacingBetweenItems,

                            // Big rounded button at bottom with shooting stars
                            ShootingStarButton(
                              height: 60,
                              borderRadius: 12,
                              backgroundColor: AppColors.primary,
                              onPressed: () async {
                                await HapticService.instance.medium();
                                if (!context.mounted) return;
                                if (nextAction == 'Movement') {
                                  Navigator.pushNamed(context, Routes.activity)
                                      .then((_) => _refreshToday());
                                  return;
                                }
                                if (nextAction == 'Water') {
                                  _showCustomWaterDialog();
                                  return;
                                }
                              },
                              child: Text(
                                nextAction == 'Movement'
                                    ? '+ Log Movement'
                                    : '+ Log Water',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // └───────────────────────────────┘

                    UIConstants.spacingBetweenCards,

                    // COMPLETION SECTION (only when 100% complete)
                    if (isAllDone)
                      Container(
                        padding: UIConstants.cardPadding,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.card.withOpacity(0.98),
                              AppColors.card.withOpacity(0.92),
                            ],
                          ),
                          borderRadius:
                              BorderRadius.circular(UIConstants.radiusXL),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 8,
                              color: Colors.black.withOpacity(0.06),
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              blurRadius: 20,
                              color: Colors.black.withOpacity(0.03),
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "All done today 🎉",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: UIConstants.spacingXL),
                            SizedBox(
                              width: double.infinity,
                              height: UIConstants.standardButtonHeight,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        UIConstants.radiusMD),
                                  ),
                                ),
                                onPressed: showShareDialog,
                                child: const Text(
                                  'Share Progress',
                                  style: UIConstants.buttonText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    UIConstants.spacingBetweenCards,

                    // Bottom padding for FAB
                    const SizedBox(height: 120),
                  ],
                ),
              ),

              // FLOATING ACTION BUTTON (CLEAN OVERLAY)
              Positioned(
                right: 20,
                bottom: 24,
                child: ExpandableFloatingQuickAdd(
                  onAddMeal: () => Navigator.pushNamed(context, Routes.meals),
                  onAddWater: _showCustomWaterDialog,
                  onAddActivity: () =>
                      Navigator.pushNamed(context, Routes.activity),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingSpec {
  final double percent;
  final Color color;

  const _RingSpec({
    required this.percent,
    required this.color,
  });
}

class ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  Color _getProgressColor(double percent) {
    final color = percent >= 1.0 ? AppColors.accent : AppColors.primary;
    return color;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (strokeWidth / 2);

    final progressColor = _getProgressColor(progress);

    final paint = Paint()
      ..color = progressColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final startAngle = -math.pi / 2;
    final safeProgress = progress.clamp(0.0, 1.0);
    final sweepAngle = 2 * math.pi * safeProgress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is! ProgressRingPainter) return true;
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

// Helper functions
Future<void> addWaterLog(int ml) async {
  await LocalStorageService.instance.addWaterForToday(ml);
}

Future<void> removeWaterLog(int ml) async {
  await LocalStorageService.instance.removeWaterForToday(ml);
}

class StreakFlame extends StatelessWidget {
  final bool isGrowing;
  final Widget child;

  const StreakFlame({
    super.key,
    required this.isGrowing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class PulseRing extends StatelessWidget {
  final bool isActive;
  final Color color;
  final Widget child;

  const PulseRing({
    super.key,
    required this.isActive,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
