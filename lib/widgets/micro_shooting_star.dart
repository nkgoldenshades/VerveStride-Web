import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class MicroShootingStar extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const MicroShootingStar({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  State<MicroShootingStar> createState() => _MicroShootingStarState();
}

class _MicroShootingStarState extends State<MicroShootingStar>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _positionAnimation;
  late Animation<double> _opacityAnimation;
  
  final Random _random = Random();
  Timer? _timer;
  bool _showStar = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _positionAnimation = Tween<double>(
      begin: -50,
      end: 150,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 0.6,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
    ));

    if (widget.enabled) {
      _startRandomShootingStars();
    }
  }

  void _startRandomShootingStars() {
    _timer = Timer.periodic(Duration(seconds: 8 + _random.nextInt(12)), (timer) {
      if (mounted && widget.enabled) {
        _triggerShootingStar();
      }
    });
  }

  void _triggerShootingStar() {
    if (!mounted) return;
    
    setState(() {
      _showStar = true;
    });
    
    _controller.forward(from: 0.0);
    
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showStar = false;
        });
      }
    });
  }

  @override
  void didUpdateWidget(MicroShootingStar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _startRandomShootingStars();
      } else {
        _timer?.cancel();
        setState(() {
          _showStar = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showStar && widget.enabled)
          Positioned(
            top: 10,
            right: 20,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_positionAnimation.value, -20),
                  child: Opacity(
                    opacity: _opacityAnimation.value,
                    child: CustomPaint(
                      size: const Size(30, 2),
                      painter: _MicroStarPainter(),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _MicroStarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFF87CEEB),
          Colors.transparent,
        ],
        stops: [0.0, 0.6, 1.0],
      ).createShader(const Rect.fromLTWH(0, 0, 30, 2))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);

    // Draw micro shooting star trail
    final path = Path();
    path.moveTo(0, 1);
    path.lineTo(25, 1);
    canvas.drawPath(path, paint);

    // Draw tiny star head
    final headPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(const Offset(25, 1), 1.5, headPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

