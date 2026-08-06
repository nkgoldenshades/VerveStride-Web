import 'package:flutter/material.dart';

/// Animated number counter that smoothly counts up or down
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 600),
    this.style,
    this.prefix = '',
    this.suffix = '',
  });

  final int value;
  final Duration duration;
  final TextStyle? style;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Text(
          '$prefix$animatedValue$suffix',
          style: style,
        );
      },
    );
  }
}

/// Animated double counter for decimal values
class AnimatedDoubleCounter extends StatelessWidget {
  const AnimatedDoubleCounter({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 600),
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.decimalPlaces = 1,
  });

  final double value;
  final Duration duration;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final int decimalPlaces;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Text(
          '$prefix${animatedValue.toStringAsFixed(decimalPlaces)}$suffix',
          style: style,
        );
      },
    );
  }
}
