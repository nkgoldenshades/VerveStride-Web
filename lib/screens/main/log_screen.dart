import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/routes.dart';
import '../../core/health_calculations.dart';
import '../workout/live_pose_screen.dart';

class LogScreen extends StatelessWidget {
  final VoidCallback onCompleted;

  const LogScreen({
    super.key,
    required this.onCompleted,
  });

  Future<void> _quickWater(BuildContext context) async {
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.card.withOpacity(0.98),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Water',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _SheetButton(
                        label: '+250 ml',
                        onPressed: () => Navigator.pop(context, 250),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SheetButton(
                        label: '+500 ml',
                        onPressed: () => Navigator.pop(context, 500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _SheetButton(
                        label: '-250 ml',
                        onPressed: () => Navigator.pop(context, -250),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SheetButton(
                        label: '-500 ml',
                        onPressed: () => Navigator.pop(context, -500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: Colors.white.withOpacity(0.12)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null || result == 0) return;
    if (result > 0) {
      await addWaterLog(result);
      onCompleted();
    } else if (result < 0) {
      await removeWaterLog(-result);
      onCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  const Text(
                    'What do you want to log?',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _LogButton(
                    label: 'Meal',
                    icon: Icons.restaurant,
                    color: const Color(0xFF00C853),
                    onPressed: () {
                      Navigator.pushNamed(context, Routes.meals).then((_) {
                        onCompleted();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _LogButton(
                    label: 'Activity',
                    icon: Icons.directions_run,
                    color: const Color(0xFF2962FF),
                    onPressed: () {
                      Navigator.pushNamed(context, Routes.activity).then((_) {
                        onCompleted();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _LogButton(
                    label: 'Workout',
                    icon: Icons.fitness_center,
                    color: const Color(0xFFFF6D00),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LivePoseScreen(),
                        ),
                      ).then((_) {
                        onCompleted();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _LogButton(
                    label: 'Quick Water',
                    icon: Icons.water_drop,
                    color: const Color(0xFF00B0FF),
                    onPressed: () => _quickWater(context),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LogButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _LogButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.card.withOpacity(0.9),
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
        ),
        onPressed: onPressed,
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SheetButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
