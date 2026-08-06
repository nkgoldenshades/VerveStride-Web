import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class ShootingStarsBackground extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final int starCount;
  final Color primaryColor;
  final Color secondaryColor;
  final double opacity;

  const ShootingStarsBackground({
    super.key,
    required this.child,
    this.enabled = true,
    this.starCount = 15,
    this.primaryColor = Colors.white,
    this.secondaryColor = const Color(0xFF87CEEB),
    this.opacity = 0.6,
  });

  @override
  State<ShootingStarsBackground> createState() => _ShootingStarsBackgroundState();
}

class _ShootingStarsBackgroundState extends State<ShootingStarsBackground>
    with TickerProviderStateMixin {
  final List<ShootingStar> _stars = [];
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    if (widget.enabled) {
      _initializeStars();
      _startAnimation();
    }
  }

  @override
  void didUpdateWidget(ShootingStarsBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _initializeStars();
        _startAnimation();
      } else {
        _animationController.stop();
        _stars.clear();
      }
    }
  }

  void _initializeStars() {
    _stars.clear();
    for (int i = 0; i < widget.starCount; i++) {
      _stars.add(ShootingStar(
        vsync: this,
        primaryColor: widget.primaryColor,
        secondaryColor: widget.secondaryColor,
        opacity: widget.opacity,
      ));
    }
  }

  void _startAnimation() {
    _animationController.repeat();
    
    // Stagger star animations
    for (int i = 0; i < _stars.length; i++) {
      Future.delayed(Duration(milliseconds: i * 300), () {
        if (mounted) {
          _stars[i].startAnimation();
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (final star in _stars) {
      star.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return Stack(
      children: [
        // Gradient background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0F0C29).withOpacity(0.1),
                const Color(0xFF302B63).withOpacity(0.1),
                const Color(0xFF24243E).withOpacity(0.1),
              ],
            ),
          ),
        ),
        
        // Shooting stars
        ..._stars.map((star) => AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return CustomPaint(
              size: MediaQuery.of(context).size,
              painter: ShootingStarPainter(star),
            );
          },
        )),
        
        // Main content
        widget.child,
      ],
    );
  }
}

class ShootingStar {
  ShootingStar({
    required TickerProvider vsync,
    required this.primaryColor,
    required this.secondaryColor,
    required this.opacity,
  }) {
    _controller = AnimationController(
      vsync: vsync,
      duration: Duration(milliseconds: 1400 + _random.nextInt(900)),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        isVisible = false;
      }
    });
  }

  final Color primaryColor;
  final Color secondaryColor;
  final double opacity;
  
  late AnimationController _controller;
  
  double startX = 0;
  double startY = 0;
  double endX = 0;
  double endY = 0;
  double currentX = 0;
  double currentY = 0;
  double trailLength = 0;
  double speed = 0;
  double size = 0;
  bool isVisible = false;
  final Random _random = Random();

  void startAnimation() {
    _initializePosition();
    if (!_controller.isAnimating) {
      _controller.forward(from: 0);
    }
  }

  void _initializePosition() {
    final screenWidth = 400.0; // Will be updated in paint
    final screenHeight = 800.0; // Will be updated in paint
    
    // Random starting position (top or right side)
    if (_random.nextBool()) {
      // Start from top
      startX = _random.nextDouble() * screenWidth;
      startY = -50;
    } else {
      // Start from right
      startX = screenWidth + 50;
      startY = _random.nextDouble() * screenHeight * 0.5;
    }
    
    // Random ending position (bottom or left side)
    final angle = _random.nextDouble() * pi / 3 + pi / 6; // 30-60 degrees
    final distance = _random.nextDouble() * 300 + 200;
    
    endX = startX - cos(angle) * distance;
    endY = startY + sin(angle) * distance;
    
    // Random properties
    speed = _random.nextDouble() * 2 + 1;
    size = _random.nextDouble() * 2 + 1;
    trailLength = _random.nextDouble() * 80 + 40;
    
    currentX = startX;
    currentY = startY;
    isVisible = true;
  }

  void update(double progress, double screenWidth, double screenHeight) {
    if (!isVisible) return;
    
    // Update position based on progress
    currentX = startX + (endX - startX) * progress;
    currentY = startY + (endY - startY) * progress;
    
    // Reset if star is off screen
    if (currentX < -100 || currentY > screenHeight + 100) {
      isVisible = false;
    }
  }

  void dispose() {
    _controller.dispose();
  }
}

class ShootingStarPainter extends CustomPainter {
  final ShootingStar star;
  
  ShootingStarPainter(this.star);

  @override
  void paint(Canvas canvas, Size size) {
    if (!star.isVisible) return;
    
    // Update star position based on screen size
    final screenWidth = size.width;
    final screenHeight = size.height;
    
    // Initialize position if needed
    if (star.startX == 0 && star.startY == 0) {
      star._initializePosition();
      // Adjust for actual screen size
      star.startX = star.startX * (screenWidth / 400);
      star.endX = star.endX * (screenWidth / 400);
      star.startY = star.startY * (screenHeight / 800);
      star.endY = star.endY * (screenHeight / 800);
    }

    star.update(star._controller.value, screenWidth, screenHeight);
    if (!star.isVisible) return;
    
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          star.primaryColor.withOpacity(star.opacity),
          star.secondaryColor.withOpacity(star.opacity * 0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: Offset(star.currentX, star.currentY),
          radius: star.trailLength,
        ),
      )
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = star.size
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    
    // Draw shooting star trail
    final path = Path();
    final trailStartX = star.currentX + star.trailLength * 0.7;
    final trailStartY = star.currentY - star.trailLength * 0.7;
    
    path.moveTo(trailStartX, trailStartY);
    path.lineTo(star.currentX, star.currentY);
    
    canvas.drawPath(path, paint);
    
    // Draw star head (brighter point)
    final headPaint = Paint()
      ..color = star.primaryColor.withOpacity(star.opacity)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    
    canvas.drawCircle(
      Offset(star.currentX, star.currentY),
      star.size * 2,
      headPaint,
    );
    
    // Add sparkle effect
    final sparklePaint = Paint()
      ..color = Colors.white.withOpacity(star.opacity * 0.8)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(
      Offset(star.currentX - 2, star.currentY - 2),
      star.size * 0.5,
      sparklePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Ambient background widget for screens
class ShootingStarsAmbientBackground extends StatelessWidget {
  final Widget child;

  const ShootingStarsAmbientBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ShootingStarsBackground(
      enabled: true, // Always enabled
      starCount: 12,
      primaryColor: Colors.white,
      secondaryColor: const Color(0xFF87CEEB),
      opacity: 0.4,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F0C29).withOpacity(0.05),
              const Color(0xFF302B63).withOpacity(0.03),
              const Color(0xFF24243E).withOpacity(0.02),
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}

