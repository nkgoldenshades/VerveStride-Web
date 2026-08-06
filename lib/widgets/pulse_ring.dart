import 'package:flutter/material.dart';

class PulseRing extends StatefulWidget {
  const PulseRing({
    super.key,
    required this.child,
    this.isActive = false,
    this.duration = const Duration(milliseconds: 800),
    this.scaleFactor = 1.2,
    this.color,
  });

  final Widget child;
  final bool isActive;
  final Duration duration;
  final double scaleFactor;
  final Color? color;

  @override
  State<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.8,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    ));
  }

  @override
  void didUpdateWidget(PulseRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.forward().then((_) {
        if (mounted) {
          _controller.reset();
        }
      });
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (widget.isActive)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.color ?? Theme.of(context).primaryColor,
                        width: 3,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        widget.child,
      ],
    );
  }
}

class StreakFlame extends StatefulWidget {
  const StreakFlame({
    super.key,
    required this.child,
    this.isGrowing = false,
    this.duration = const Duration(milliseconds: 1000),
  });

  final Widget child;
  final bool isGrowing;
  final Duration duration;

  @override
  State<StreakFlame> createState() => _StreakFlameState();
}

class _StreakFlameState extends State<StreakFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _flameAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _flameAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void didUpdateWidget(StreakFlame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isGrowing && !oldWidget.isGrowing) {
      _controller.forward().then((_) {
        if (mounted) {
          _controller.reset();
        }
      });
    } else if (!widget.isGrowing && oldWidget.isGrowing) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (widget.isGrowing)
          AnimatedBuilder(
            animation: _flameAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_flameAnimation.value * 0.3),
                child: Icon(
                  Icons.local_fire_department,
                  color: Colors.orange.withOpacity(0.8 * _flameAnimation.value),
                  size: 24 + (_flameAnimation.value * 16),
                ),
              );
            },
          ),
        widget.child,
      ],
    );
  }
}

