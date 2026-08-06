import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AmbientBackground extends StatefulWidget {
  const AmbientBackground({super.key});

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    
    // Optimize animation duration for web performance
    final duration = kIsWeb 
        ? const Duration(seconds: 60)  // Slower on web to reduce CPU usage
        : const Duration(seconds: 32); // Original speed on native
        
    _controller = AnimationController(
      vsync: this,
      duration: duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.maybeOf(context);
    final disableAnimations = (mq?.disableAnimations ?? false) ||
        (mq?.accessibleNavigation ?? false);
    if (disableAnimations) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _AmbientPainter(
                t: _controller.value,
                isDark: isDark,
                context: context,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({required this.t, required this.isDark, required this.context});

  final double t;
  final bool isDark;
  final BuildContext context;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    
    // Reduce complexity on web for better performance
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio.clamp(1.0, 3.0);
    final scaleFactor = kIsWeb 
        ? devicePixelRatio.clamp(1.0, 1.5)  // Lower scale factor on web
        : devicePixelRatio.clamp(1.0, 2.0); // Original scale on native
        
    if (isDark) {
      _paintDarkStars(canvas, size, scaleFactor);
    } else {
      _paintLightBlobs(canvas, size, scaleFactor);
    }
  }

  void _paintDarkStars(Canvas canvas, Size size, double scaleFactor) {
    final exclusionCenter = Offset(size.width * 0.5, size.height * 0.38);
    final exclusionRadius = min(size.width, size.height) * 0.30;
    final exclusionRect = Rect.fromCircle(
      center: exclusionCenter,
      radius: exclusionRadius,
    );

    final maskPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(exclusionRect);

    canvas.save();
    canvas.clipPath(maskPath);

    final rnd = Random(1337);

    // Reduce star count on web for better performance
    final starCount = kIsWeb ? 12 : 24;
    
    final starPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < starCount; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      if ((Offset(x, y) - exclusionCenter).distance <= exclusionRadius) {
        continue;
      }
      final tw = 0.55 + 0.45 * sin((t * pi) + (i * 0.55)).abs();
      final r = (0.55 + (i % 3) * 0.22) * scaleFactor;
      final a = 0.010 + (i % 5) * 0.003;
      starPaint.color =
          Colors.white.withOpacity((a * tw).clamp(0, 0.030));
      canvas.drawCircle(Offset(x, y), r, starPaint);
    }

    final streakPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Reduce shooting star count on web
    final shootingStarCount = kIsWeb ? 1 : 2;
    
    for (int i = 0; i < shootingStarCount; i++) {
      final phase = (t + (i * 0.47)) % 1.0;
      final local = (phase - 0.04) / 0.04;
      if (local < 0 || local > 1) continue;

      final y0 = (0.08 + (i * 0.18)) * size.height;
      final x0 = (0.10 + (i * 0.18)) * size.width;

      final travelX = size.width * 0.62;
      final travelY = size.height * 0.12;

      final head = Offset(
        x0 + (travelX * Curves.easeInOut.transform(local)),
        y0 + (travelY * Curves.easeInOut.transform(local)),
      );

      final tailLen = (70.0 + (i * 18.0)) * scaleFactor;
      final dir = const Offset(1, 0.22);
      final tail = head - dir * tailLen;

      final alpha = (0.08 * (1 - (local - 0.5).abs() * 2))
          .clamp(0.0, 0.045)
          .toDouble();
      streakPaint
        ..strokeWidth = 1.0 * scaleFactor
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(alpha),
          ],
        ).createShader(Rect.fromPoints(tail, head));

      canvas.drawLine(tail, head, streakPaint);
    }

    // Skip aurora effect on web for better performance
    if (!kIsWeb) {
      final auroraPhase = (t + 0.23) % 1.0;
      final auroraLocal = (auroraPhase - 0.54) / 0.04;
      if (auroraLocal >= 0 && auroraLocal <= 1) {
        final intensity = (1 - (auroraLocal - 0.5).abs() * 2).clamp(0.0, 1.0);
        final sweep = Curves.easeInOut.transform(auroraLocal);
        final xShift = (sweep - 0.5) * size.width * 0.35;
        final yBase = size.height * (0.20 + 0.08 * sin((t * 2 * pi)));

        final path = Path()
          ..moveTo(size.width * 0.05 + xShift, yBase)
          ..quadraticBezierTo(
            size.width * 0.30 + xShift,
            yBase + size.height * 0.10,
            size.width * 0.55 + xShift,
            yBase + size.height * 0.02,
          )
          ..quadraticBezierTo(
            size.width * 0.80 + xShift,
            yBase - size.height * 0.08,
            size.width * 1.02 + xShift,
            yBase + size.height * 0.02,
          );

        final auroraPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 10.0 * scaleFactor
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18.0 * scaleFactor)
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              const Color(0xFF19E3D6)
                  .withOpacity((0.0).clamp(0.0, 1.0)),
              const Color(0xFF7C5CFF)
                  .withOpacity((0.008 * intensity).clamp(0.0, 0.014)),
              const Color(0xFF19E3D6)
                  .withOpacity((0.006 * intensity).clamp(0.0, 0.012)),
              const Color(0xFF7C5CFF)
                  .withOpacity((0.0).clamp(0.0, 1.0)),
            ],
          ).createShader(Offset.zero & size);

        canvas.drawPath(path, auroraPaint);
      }
    }

    canvas.restore();
  }

  void _paintLightBlobs(Canvas canvas, Size size, double scaleFactor) {
    final exclusionCenter = Offset(size.width * 0.5, size.height * 0.38);
    final exclusionRadius = min(size.width, size.height) * 0.30;
    final exclusionRect = Rect.fromCircle(
      center: exclusionCenter,
      radius: exclusionRadius,
    );

    final maskPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(exclusionRect);

    canvas.save();
    canvas.clipPath(maskPath);

    final paint = Paint()..style = PaintingStyle.fill;

    // Reduce blob count on web
    final centers = kIsWeb 
        ? <Offset>[
            Offset(size.width * 0.20, size.height * 0.25),
            Offset(size.width * 0.85, size.height * 0.22),
          ]
        : <Offset>[
            Offset(size.width * 0.20, size.height * 0.25),
            Offset(size.width * 0.85, size.height * 0.22),
            Offset(size.width * 0.72, size.height * 0.70),
          ];

    for (int i = 0; i < centers.length; i++) {
      final c = centers[i];
      final drift = sin((t * 2 * pi) + (i * 1.3));
      final drift2 = cos((t * 2 * pi) + (i * 1.1));
      final center = c.translate(drift * 10, drift2 * 8);
      final radius = ((140 + i * 55) + (drift.abs() * 14)) * scaleFactor;

      final colorA = (i.isEven
              ? const Color(0xFF7C5CFF)
              : const Color(0xFF19E3D6))
          .withOpacity(0.04);
      final colorB = const Color(0xFF7C5CFF).withOpacity(0.0);

      paint.shader = RadialGradient(
        colors: [colorA, colorB],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius),
      );

      canvas.drawCircle(center, radius, paint);
    }

    // Skip shimmer effect on web for better performance
    if (!kIsWeb) {
      final shimmerPhase = (t + 0.11) % 1.0;
      final shimmerLocal = (shimmerPhase - 0.78) / 0.05;
      if (shimmerLocal >= 0 && shimmerLocal <= 1) {
        final intensity = (1 - (shimmerLocal - 0.5).abs() * 2).clamp(0.0, 1.0);
        final sweep = Curves.easeInOut.transform(shimmerLocal);
        final center = Offset(
          size.width * (0.10 + 0.86 * sweep),
          size.height * (0.18 + 0.12 * sin((t * 2 * pi) + 1.2)),
        );

        final shimmerPaint = Paint()
          ..style = PaintingStyle.fill
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18.0 * scaleFactor)
          ..shader = RadialGradient(
            colors: [
              const Color(0xFF7C5CFF).withOpacity((0.018 * intensity).clamp(0.0, 0.020)),
              const Color(0xFF19E3D6).withOpacity((0.010 * intensity).clamp(0.0, 0.012)),
              Colors.white.withOpacity(0.0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: 180 * scaleFactor));

        canvas.drawCircle(center, 180 * scaleFactor, shimmerPaint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.isDark != isDark;
  }
}
