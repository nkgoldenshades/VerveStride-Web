import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Sparkle effect overlay that shows twinkling stars
class SparkleOverlay extends StatefulWidget {
  const SparkleOverlay({
    super.key,
    required this.child,
    this.isActive = true,
    this.numberOfSparkles = 5,
    this.color = Colors.amber,
    this.size = 20.0,
  });

  final Widget child;
  final bool isActive;
  final int numberOfSparkles;
  final Color color;
  final double size;

  @override
  State<SparkleOverlay> createState() => _SparkleOverlayState();
}

class _SparkleOverlayState extends State<SparkleOverlay>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<_Sparkle> _sparkles;

  @override
  void initState() {
    super.initState();
    _generateSparkles();
  }

  void _generateSparkles() {
    final random = math.Random();
    _controllers = List.generate(
      widget.numberOfSparkles,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 800 + random.nextInt(400)),
      )..repeat(reverse: true),
    );

    _sparkles = List.generate(
      widget.numberOfSparkles,
      (index) => _Sparkle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        angle: random.nextDouble() * 2 * math.pi,
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        if (widget.isActive)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: Listenable.merge(_controllers),
                builder: (context, _) {
                  return CustomPaint(
                    painter: _SparklePainter(
                      sparkles: _sparkles,
                      controllers: _controllers,
                      color: widget.color,
                      size: widget.size,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _Sparkle {
  final double x;
  final double y;
  final double angle;

  _Sparkle({
    required this.x,
    required this.y,
    required this.angle,
  });
}

class _SparklePainter extends CustomPainter {
  final List<_Sparkle> sparkles;
  final List<AnimationController> controllers;
  final Color color;
  final double size;

  _SparklePainter({
    required this.sparkles,
    required this.controllers,
    required this.color,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    for (var i = 0; i < sparkles.length; i++) {
      final sparkle = sparkles[i];
      final opacity = controllers[i].value;

      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final center = Offset(
        sparkle.x * canvasSize.width,
        sparkle.y * canvasSize.height,
      );

      // Draw star shape
      final path = Path();
      for (var j = 0; j < 4; j++) {
        final angle = sparkle.angle + (j * math.pi / 2);
        final length = size * (0.5 + opacity * 0.5);

        final start = Offset(
          center.dx + math.cos(angle) * length * 0.3,
          center.dy + math.sin(angle) * length * 0.3,
        );
        final end = Offset(
          center.dx + math.cos(angle) * length,
          center.dy + math.sin(angle) * length,
        );

        path.moveTo(start.dx, start.dy);
        path.lineTo(end.dx, end.dy);
      }

      canvas.drawPath(path, paint);

      // Draw glow
      final glowPaint = Paint()
        ..color = color.withOpacity(opacity * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(center, size * 0.5, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => true;
}
