import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// Beautiful empty state view with animated icon
class EmptyStateView extends StatefulWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  @override
  State<EmptyStateView> createState() => _EmptyStateViewState();
}

class _EmptyStateViewState extends State<EmptyStateView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated icon container
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          (widget.iconColor ?? AppColors.primary)
                              .withOpacity(0.2),
                          (widget.iconColor ?? AppColors.primary)
                              .withOpacity(0.1),
                        ],
                      ),
                      border: Border.all(
                        color: (widget.iconColor ?? AppColors.primary)
                            .withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      size: 60,
                      color: widget.iconColor ?? AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Title
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Message
                Text(
                  widget.message,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget.actionLabel != null && widget.onAction != null) ...[
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: widget.onAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      widget.actionLabel!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Predefined empty states
class EmptyStates {
  static Widget noActivities({VoidCallback? onAdd}) => EmptyStateView(
        icon: Icons.directions_run,
        title: 'No Activities Yet',
        message: 'Start tracking your movement and\nbuild healthy habits!',
        actionLabel: 'Log Activity',
        onAction: onAdd,
        iconColor: AppColors.primary,
      );

  static Widget noMeals({VoidCallback? onAdd}) => EmptyStateView(
        icon: Icons.restaurant,
        title: 'No Meals Logged',
        message: 'Track your meals to understand\nyour nutrition better!',
        actionLabel: 'Log Meal',
        onAction: onAdd,
        iconColor: AppColors.secondary,
      );

  static Widget noWorkouts({VoidCallback? onAdd}) => EmptyStateView(
        icon: Icons.fitness_center,
        title: 'No Workouts',
        message: 'Start a workout session to\ntrack your progress!',
        actionLabel: 'Start Workout',
        onAction: onAdd,
        iconColor: AppColors.accent,
      );

  static Widget noWaterLogs({VoidCallback? onAdd}) => EmptyStateView(
        icon: Icons.water_drop,
        title: 'No Water Logged',
        message: 'Stay hydrated! Start logging\nyour water intake.',
        actionLabel: 'Add Water',
        onAction: onAdd,
        iconColor: AppColors.secondary,
      );

  static Widget noCalendarEvents({VoidCallback? onAdd}) => EmptyStateView(
        icon: Icons.calendar_today,
        title: 'No Events Today',
        message: 'Your calendar is clear.\nEnjoy your free time!',
        actionLabel: null,
        onAction: null,
        iconColor: AppColors.primary,
      );
}
