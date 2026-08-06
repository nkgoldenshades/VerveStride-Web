import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import 'ai_robot_head.dart';

/// Animated AI orb with orbiting sparkle stars.
/// Used in the chat empty state and as the AI "thinking" indicator.
///
/// Features:
/// - Pulsing gradient circle (the orb)
/// - Orbiting 3D-style stars that rotate around the orb
/// - Sparkling effect when [isActive] is true (speaking/thinking)
/// - Stars shoot outward when [isSpeaking] is true
class AIOrb extends StatefulWidget {
  final bool isActive;    // thinking / processing
  final bool isSpeaking;  // voice output active
  final double size;
  final Widget? centerChild;

  const AIOrb({
    super.key,
    this.isActive = false,
    this.isSpeaking = false,
    this.size = 72,
    this.centerChild,
  });

  @override
  State<AIOrb> createState() => _AIOrbState();
}

class _AIOrbState extends State<AIOrb> with TickerProviderStateMixin {
  late AnimationController _orbitController;   // stars orbiting
  late AnimationController _pulseController;   // orb pulsing
  late AnimationController _sparkleController; // sparkle opacity
  late AnimationController _rotateController;  // slow orb rotation

  late Animation<double> _pulseAnim;
  late Animation<double> _sparkleAnim;

  @override
  void initState() {
    super.initState();

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _sparkleAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _sparkleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _pulseController.dispose();
    _sparkleController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final orbitRadius = s * 0.72;

    return SizedBox(
      width: s * 2.2,
      height: s * 2.2,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _orbitController,
          _pulseController,
          _sparkleController,
          _rotateController,
        ]),
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // ── Outer glow ring ──────────────────────────────────────
              Container(
                width: s * 1.5,
                height: s * 1.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withOpacity(widget.isActive ? 0.18 : 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // ── Orbiting stars ───────────────────────────────────────
              ..._buildOrbitingStars(orbitRadius),

              // ── Pulsing orb ──────────────────────────────────────────
              Transform.scale(
                scale: _pulseAnim.value,
                child: Transform.rotate(
                  angle: _rotateController.value * 2 * math.pi,
                  child: Container(
                    width: s,
                    height: s,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.secondary,
                          const Color(0xFF9C27B0),
                          AppColors.primary,
                        ],
                        stops: const [0.0, 0.35, 0.7, 1.0],
                        transform: GradientRotation(
                          _rotateController.value * 2 * math.pi,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(widget.isActive ? 0.6 : 0.3),
                          blurRadius: widget.isActive ? 24 : 12,
                          spreadRadius: widget.isActive ? 4 : 0,
                        ),
                        BoxShadow(
                          color: AppColors.secondary.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: widget.centerChild ??
                          AIRobotHead(
                            size: s * 0.72,
                            isActive: widget.isActive,
                            isSpeaking: widget.isSpeaking,
                          ),
                    ),
                  ),
                ),
              ),

              // ── Active sparkles (shooting outward) ───────────────────
              if (widget.isActive || widget.isSpeaking)
                ..._buildShootingSparkles(s),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildOrbitingStars(double orbitRadius) {
    const starCount = 6;
    final stars = <Widget>[];

    for (int i = 0; i < starCount; i++) {
      final baseAngle = (i / starCount) * 2 * math.pi;
      final angle = baseAngle + _orbitController.value * 2 * math.pi;

      // Elliptical orbit (3D perspective effect)
      final x = math.cos(angle) * orbitRadius;
      final y = math.sin(angle) * orbitRadius * 0.38;

      // Stars further "back" are smaller and dimmer
      final depth = (math.sin(angle) + 1) / 2;
      final starSize = 4.0 + depth * 5.0;
      final opacity = 0.3 + depth * 0.7;

      final colors = [
        AppColors.primary,
        AppColors.secondary,
        const Color(0xFFFFD700),
        AppColors.primary,
        const Color(0xFFE040FB),
        AppColors.secondary,
      ];

      // Use Transform.translate from center instead of Positioned
      // This avoids negative coordinate issues in the Stack
      stars.add(
        Align(
          alignment: Alignment.center,
          child: Transform.translate(
            offset: Offset(x, y),
            child: Opacity(
              opacity: opacity,
              child: _Star(
                size: starSize,
                color: colors[i % colors.length],
                sparkle: _sparkleAnim.value,
              ),
            ),
          ),
        ),
      );
    }
    return stars;
  }

  List<Widget> _buildShootingSparkles(double s) {
    const count = 8;
    final sparkles = <Widget>[];
    final progress = _sparkleController.value;

    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi;
      final distance = s * 0.6 + progress * s * 0.5;
      final x = math.cos(angle) * distance;
      final y = math.sin(angle) * distance;
      final opacity = (1.0 - progress) * 0.8;

      sparkles.add(
        Align(
          alignment: Alignment.center,
          child: Transform.translate(
            offset: Offset(x, y),
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i % 2 == 0 ? AppColors.primary : AppColors.secondary,
                  boxShadow: [
                    BoxShadow(
                      color: (i % 2 == 0 ? AppColors.primary : AppColors.secondary)
                          .withOpacity(0.6),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return sparkles;
  }
}

/// A 4-pointed star shape with a glow
class _Star extends StatelessWidget {
  final double size;
  final Color color;
  final double sparkle; // 0.0 to 1.0

  const _Star({
    required this.size,
    required this.color,
    required this.sparkle,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _StarPainter(color: color, sparkle: sparkle),
    );
  }
}

class _StarPainter extends CustomPainter {
  final Color color;
  final double sparkle;

  _StarPainter({required this.color, required this.sparkle});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(sparkle)
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = color.withOpacity(sparkle * 0.4)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final cx = size.width / 2;
    final cy = size.height / 2;
    final outer = size.width / 2;
    final inner = size.width / 5;

    // 4-pointed star
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) - math.pi / 2;
      final r = i % 2 == 0 ? outer : inner;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_StarPainter old) =>
      old.sparkle != sparkle || old.color != color;
}
