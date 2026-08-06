import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Confetti celebration effect
class ConfettiWidget extends StatefulWidget {
  const ConfettiWidget({
    super.key,
    this.numberOfParticles = 50,
    this.duration = const Duration(seconds: 3),
    this.colors = const [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
    ],
  });

  final int numberOfParticles;
  final Duration duration;
  final List<Color> colors;

  @override
  State<ConfettiWidget> createState() => _ConfettiWidgetState();
}

class _ConfettiWidgetState extends State<ConfettiWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_ConfettiParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _generateParticles();
    _controller.forward();
    _controller.addListener(() {
      setState(() {
        for (var particle in _particles) {
          particle.update();
        }
      });
    });
  }

  void _generateParticles() {
    final random = math.Random();
    for (var i = 0; i < widget.numberOfParticles; i++) {
      _particles.add(_ConfettiParticle(
        x: random.nextDouble(),
        y: -0.1,
        velocityX: random.nextDouble() * 2 - 1,
        velocityY: random.nextDouble() * 3 + 2,
        color: widget.colors[random.nextInt(widget.colors.length)],
        size: random.nextDouble() * 8 + 4,
        rotation: random.nextDouble() * 2 * math.pi,
        rotationSpeed: random.nextDouble() * 0.2 - 0.1,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ConfettiPainter(particles: _particles),
        size: Size.infinite,
      ),
    );
  }
}

class _ConfettiParticle {
  double x;
  double y;
  double velocityX;
  double velocityY;
  Color color;
  double size;
  double rotation;
  double rotationSpeed;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.velocityX,
    required this.velocityY,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
  });

  void update() {
    y += velocityY * 0.01;
    x += velocityX * 0.005;
    velocityY += 0.05; // Gravity
    rotation += rotationSpeed;
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;

  _ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final paint = Paint()
        ..color = particle.color
        ..style = PaintingStyle.fill;

      final x = particle.x * size.width;
      final y = particle.y * size.height;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(particle.rotation);

      // Draw rectangle confetti
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: particle.size,
            height: particle.size * 1.5,
          ),
          Radius.circular(particle.size * 0.2),
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => true;
}
