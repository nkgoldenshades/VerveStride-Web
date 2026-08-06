import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A living 3D-style robot head for VerveStride AI.
///
/// Features:
/// - Gentle bob/float animation (feels alive)
/// - Blinking eyes with glow
/// - Antenna pulse
/// - 3D depth via layered shadows and gradients
/// - Active state: eyes glow brighter, faster blink
class AIRobotHead extends StatefulWidget {
  final double size;
  final bool isActive; // thinking / speaking
  final bool isSpeaking;

  const AIRobotHead({
    super.key,
    this.size = 64,
    this.isActive = false,
    this.isSpeaking = false,
  });

  @override
  State<AIRobotHead> createState() => _AIRobotHeadState();
}

class _AIRobotHeadState extends State<AIRobotHead>
    with TickerProviderStateMixin {
  // Float / bob
  late AnimationController _floatCtrl;
  late Animation<double> _floatAnim;

  // Blink
  late AnimationController _blinkCtrl;

  // Antenna pulse
  late AnimationController _antennaCtrl;
  late Animation<double> _antennaAnim;

  // Mouth (speaking)
  late AnimationController _mouthCtrl;
  late Animation<double> _mouthAnim;

  bool _eyeOpen = true;

  @override
  void initState() {
    super.initState();

    // Float up and down
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -4, end: 4).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    // Blink every ~3 seconds
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scheduleBlink();

    // Antenna glow pulse
    _antennaCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _antennaAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _antennaCtrl, curve: Curves.easeInOut),
    );

    // Mouth open/close when speaking
    _mouthCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _mouthAnim = Tween<double>(begin: 0.15, end: 0.45).animate(
      CurvedAnimation(parent: _mouthCtrl, curve: Curves.easeInOut),
    );
  }

  void _scheduleBlink() {
    final delay = Duration(
      milliseconds: 2500 + math.Random().nextInt(2000),
    );
    Future.delayed(delay, () {
      if (!mounted) return;
      setState(() => _eyeOpen = false);
      _blinkCtrl.forward(from: 0).then((_) {
        if (!mounted) return;
        setState(() => _eyeOpen = true);
        _scheduleBlink();
      });
    });
  }

  @override
  void didUpdateWidget(AIRobotHead old) {
    super.didUpdateWidget(old);
    if (widget.isSpeaking && !old.isSpeaking) {
      _mouthCtrl.repeat(reverse: true);
    } else if (!widget.isSpeaking && old.isSpeaking) {
      _mouthCtrl.stop();
      _mouthCtrl.animateTo(0);
    }
    if (widget.isActive) {
      _floatCtrl.duration = const Duration(milliseconds: 1200);
    } else {
      _floatCtrl.duration = const Duration(milliseconds: 2400);
    }
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _blinkCtrl.dispose();
    _antennaCtrl.dispose();
    _mouthCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _floatCtrl,
        _blinkCtrl,
        _antennaCtrl,
        _mouthCtrl,
      ]),
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, _floatAnim.value),
          child: SizedBox(
            width: s,
            height: s * 1.25, // extra height for antenna
            child: CustomPaint(
              painter: _RobotHeadPainter(
                eyeOpen: _eyeOpen,
                antennaGlow: _antennaAnim.value,
                mouthOpen: widget.isSpeaking
                    ? _mouthAnim.value
                    : 0.15,
                isActive: widget.isActive,
                size: s,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RobotHeadPainter extends CustomPainter {
  final bool eyeOpen;
  final double antennaGlow;
  final double mouthOpen;
  final bool isActive;
  final double size;

  _RobotHeadPainter({
    required this.eyeOpen,
    required this.antennaGlow,
    required this.mouthOpen,
    required this.isActive,
    required this.size,
  });

  // Brand colors
  static const Color _primary = Color(0xFF6C63FF);
  static const Color _secondary = Color(0xFF19E3D6);
  static const Color _eyeColor = Color(0xFF19E3D6);
  static const Color _faceBase = Color(0xFF1A1A2E);
  static const Color _faceMid = Color(0xFF16213E);
  static const Color _rim = Color(0xFF6C63FF);

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final s = size;
    final cx = canvasSize.width / 2;
    // Head sits in lower 80% of canvas (top 20% = antenna)
    final headTop = canvasSize.height * 0.22;
    final headH = s * 0.78;
    final headW = s * 0.88;
    final headLeft = cx - headW / 2;
    final headRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(headLeft, headTop, headW, headH),
      Radius.circular(s * 0.18),
    );

    // ── 3D drop shadow (depth) ──────────────────────────────────────────
    final shadowPaint = Paint()
      ..color = _primary.withOpacity(0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(headLeft + s * 0.04, headTop + s * 0.06, headW, headH),
        Radius.circular(s * 0.18),
      ),
      shadowPaint,
    );

    // ── Head body — gradient for 3D feel ───────────────────────────────
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF2A2A4A),
          _faceMid,
          _faceBase,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(headLeft, headTop, headW, headH));
    canvas.drawRRect(headRect, bodyPaint);

    // ── Rim / border glow ──────────────────────────────────────────────
    final rimPaint = Paint()
      ..color = _rim.withOpacity(isActive ? 0.9 : 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.025;
    canvas.drawRRect(headRect, rimPaint);

    // ── Top highlight (3D light source) ───────────────────────────────
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.015;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(headLeft + s * 0.04, headTop + s * 0.02,
            headW - s * 0.08, headH * 0.4),
        Radius.circular(s * 0.15),
      ),
      highlightPaint,
    );

    // ── Antenna ────────────────────────────────────────────────────────
    final antennaStemPaint = Paint()
      ..color = _primary.withOpacity(0.8)
      ..strokeWidth = s * 0.04
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx, headTop),
      Offset(cx, headTop - s * 0.18),
      antennaStemPaint,
    );

    // Antenna ball with glow
    final antGlowPaint = Paint()
      ..color = _secondary.withOpacity(antennaGlow * 0.5)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.06);
    canvas.drawCircle(
      Offset(cx, headTop - s * 0.2),
      s * 0.07,
      antGlowPaint,
    );
    final antBallPaint = Paint()
      ..color = Color.lerp(_secondary, Colors.white, antennaGlow * 0.4)!;
    canvas.drawCircle(
      Offset(cx, headTop - s * 0.2),
      s * 0.055,
      antBallPaint,
    );

    // ── Eyes ───────────────────────────────────────────────────────────
    final eyeY = headTop + headH * 0.35;
    final eyeSpacing = headW * 0.28;
    final eyeR = s * 0.1;

    for (final side in [-1.0, 1.0]) {
      final ex = cx + side * eyeSpacing;

      // Eye socket (dark recess for 3D depth)
      final socketPaint = Paint()
        ..color = Colors.black.withOpacity(0.5);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(ex, eyeY),
          width: eyeR * 2.4,
          height: eyeR * 2.2,
        ),
        socketPaint,
      );

      if (eyeOpen) {
        // Eye glow
        final eyeGlowPaint = Paint()
          ..color = _eyeColor.withOpacity(isActive ? 0.6 : 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.06);
        canvas.drawCircle(Offset(ex, eyeY), eyeR * 1.3, eyeGlowPaint);

        // Eye iris — gradient
        final eyePaint = Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withOpacity(0.9),
              _eyeColor,
              _eyeColor.withOpacity(0.6),
            ],
            stops: const [0.0, 0.4, 1.0],
          ).createShader(
            Rect.fromCircle(center: Offset(ex, eyeY), radius: eyeR),
          );
        canvas.drawCircle(Offset(ex, eyeY), eyeR, eyePaint);

        // Pupil
        canvas.drawCircle(
          Offset(ex + eyeR * 0.15, eyeY - eyeR * 0.1),
          eyeR * 0.35,
          Paint()..color = Colors.black.withOpacity(0.8),
        );

        // Eye shine
        canvas.drawCircle(
          Offset(ex - eyeR * 0.2, eyeY - eyeR * 0.3),
          eyeR * 0.18,
          Paint()..color = Colors.white.withOpacity(0.9),
        );
      } else {
        // Blink — thin line
        final blinkPaint = Paint()
          ..color = _eyeColor.withOpacity(0.6)
          ..strokeWidth = s * 0.025
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(ex - eyeR, eyeY),
          Offset(ex + eyeR, eyeY),
          blinkPaint,
        );
      }
    }

    // ── Mouth ──────────────────────────────────────────────────────────
    final mouthY = headTop + headH * 0.68;
    final mouthW = headW * 0.5;
    final mouthH = headH * mouthOpen;

    final mouthRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, mouthY),
        width: mouthW,
        height: math.max(mouthH, s * 0.025),
      ),
      Radius.circular(s * 0.04),
    );

    // Mouth recess
    canvas.drawRRect(
      mouthRect,
      Paint()..color = Colors.black.withOpacity(0.7),
    );

    // Mouth grill lines (robot aesthetic)
    if (mouthOpen < 0.2) {
      final grillPaint = Paint()
        ..color = _primary.withOpacity(0.5)
        ..strokeWidth = s * 0.018
        ..strokeCap = StrokeCap.round;
      final grillCount = 4;
      final grillSpacing = mouthW / (grillCount + 1);
      for (int i = 1; i <= grillCount; i++) {
        final gx = cx - mouthW / 2 + grillSpacing * i;
        canvas.drawLine(
          Offset(gx, mouthY - s * 0.025),
          Offset(gx, mouthY + s * 0.025),
          grillPaint,
        );
      }
    }

    // ── Ear bolts (3D detail) ──────────────────────────────────────────
    for (final side in [-1.0, 1.0]) {
      final bx = cx + side * (headW / 2 + s * 0.01);
      final by = headTop + headH * 0.45;
      canvas.drawCircle(
        Offset(bx, by),
        s * 0.055,
        Paint()
          ..color = _primary.withOpacity(0.7)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        Offset(bx, by),
        s * 0.055,
        Paint()
          ..color = _rim.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.015,
      );
      // Bolt shine
      canvas.drawCircle(
        Offset(bx - s * 0.015, by - s * 0.015),
        s * 0.018,
        Paint()..color = Colors.white.withOpacity(0.5),
      );
    }

    // ── Active scan line (when thinking) ──────────────────────────────
    if (isActive) {
      final scanPaint = Paint()
        ..color = _secondary.withOpacity(0.15)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.03);
      canvas.drawRect(
        Rect.fromLTWH(headLeft, headTop + headH * 0.3, headW, headH * 0.08),
        scanPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RobotHeadPainter old) =>
      old.eyeOpen != eyeOpen ||
      old.antennaGlow != antennaGlow ||
      old.mouthOpen != mouthOpen ||
      old.isActive != isActive;
}
