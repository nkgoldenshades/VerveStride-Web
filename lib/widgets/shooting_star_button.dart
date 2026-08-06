import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../core/app_theme.dart';
import '../services/local_storage_service.dart';

/// Button with shooting star particle effects
class ShootingStarButton extends StatefulWidget {
  const ShootingStarButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.backgroundColor,
    this.height = 60,
    this.borderRadius = 16,
    this.enableParticles = true,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final double height;
  final double borderRadius;
  final bool enableParticles;

  @override
  State<ShootingStarButton> createState() => _ShootingStarButtonState();
}

class _ShootingStarButtonState extends State<ShootingStarButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  bool _isHovered = false;
  bool _performanceMode = false;
  bool _sparkleEnabled = true;

  @override
  void initState() {
    super.initState();
    _refreshSettings();
    _controller = AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 120), // Slower animation = less CPU
    )..addListener(() {
        setState(() {
          _updateParticles();
        });
      });
  }

  Future<void> _refreshSettings() async {
    final performanceMode =
        await LocalStorageService.instance.getPerformanceMode();
    final sparkleEnabled = kIsWeb
        ? await LocalStorageService.instance.getSparkleEffectEnabled()
        : true;

    if (!mounted) return;
    setState(() {
      _performanceMode = performanceMode;
      _sparkleEnabled = sparkleEnabled;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateParticles() {
    // Update existing particles
    for (var particle in _particles) {
      particle.update();
    }

    // Remove dead particles
    _particles.removeWhere((p) => p.isDead);
  }

  void _spawnParticles(Offset position, Size size) {
    if (!widget.enableParticles || _performanceMode) return;
    if (kIsWeb && !_sparkleEnabled) return;

    final random = math.Random();
    final sizeScale = kIsWeb ? 1.8 : 1.0;
    // Reduce particle count from 3 to 2 for hover
    for (var i = 0; i < 2; i++) {
      _particles.add(
        _Particle(
          position: Offset(
            position.dx +
                random.nextDouble() * size.width * 0.2 - // Smaller spread area
                size.width * 0.1,
            position.dy + random.nextDouble() * 10 - 5, // Smaller Y spread
          ),
          velocity: Offset(
            random.nextDouble() * 2 - 1, // Slower horizontal velocity
            -random.nextDouble() * 1.5 - 1, // Slower vertical velocity
          ),
          color: widget.backgroundColor ?? AppColors.primary,
          size: (random.nextDouble() * 2 + 1) * sizeScale,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        _refreshSettings();
        setState(() => _isHovered = true);
        if (!_controller.isAnimating) {
          _controller.repeat();
        }
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.stop();
      },
      onHover: (event) {
        if (widget.enableParticles && _isHovered && !_performanceMode) {
          if (kIsWeb && !_sparkleEnabled) return;
          final box = context.findRenderObject() as RenderBox?;
          if (box != null) {
            _spawnParticles(event.localPosition, box.size);
          }
        }
      },
      child: GestureDetector(
        onTapDown: (details) {
          _refreshSettings();
          if (widget.enableParticles && !_performanceMode) {
            if (kIsWeb && !_sparkleEnabled) return;
            final box = context.findRenderObject() as RenderBox?;
            if (box != null) {
              // Reduce particle count from 8 to 4 for tap
              for (var i = 0; i < 4; i++) {
                _spawnParticles(details.localPosition, box.size);
              }
            }
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: Stack(
            children: [
              // Button
              AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              height: widget.height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.backgroundColor ?? AppColors.primary,
                    (widget.backgroundColor ?? AppColors.primary)
                        .withOpacity(0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: [
                  BoxShadow(
                    blurRadius: _isHovered ? 12 : 6,
                    color: (widget.backgroundColor ?? AppColors.primary)
                        .withOpacity(_isHovered ? 0.4 : 0.2),
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  onTap: widget.onPressed,
                  child: Container(
                    alignment: Alignment.center,
                    child: widget.child,
                  ),
                ),
              ),
            ),
            // Particles - ignore pointer events so they don't block clicks
            if (widget.enableParticles && !_performanceMode && (!kIsWeb || _sparkleEnabled))
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ParticlePainter(particles: _particles),
                  ),
                ),
              ),
          ],
          ),
        ),
      ),
    );
  }
}

class _Particle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double life = 1.0;

  _Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
  });

  void update() {
    position += velocity;
    velocity = Offset(velocity.dx * 0.96, velocity.dy + 0.15); // Slower physics
    life -= kIsWeb ? 0.015 : 0.025;
  }

  bool get isDead => life <= 0;
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;

  _ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity((kIsWeb ? (particle.life * 1.15) : particle.life).clamp(0, 1))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(particle.position, particle.size, paint);

      // Glow effect
      final glowPaint = Paint()
        ..color = particle.color.withOpacity((particle.life * (kIsWeb ? 0.55 : 0.3)).clamp(0, 1))
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          kIsWeb ? 7 : 4,
        );

      canvas.drawCircle(particle.position, particle.size * 1.5, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}
