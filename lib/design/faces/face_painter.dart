import 'dart:math' as math;

import 'package:critalarm/design/faces/face_shape.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:flutter/rendering.dart';

/// Exact 200 unit viewBox vector painter for the Crit Alarm face character.
class FacePainter extends CustomPainter {
  const FacePainter({
    required this.state,
    required this.fillColor,
    required this.strokeColor,
    required this.inkColor,
    this.lookDx = 0.0,
    this.spiralRotation = 0.0,
    this.tongueColor,
    this.shape,
  });

  final FaceState state;
  final Color fillColor;
  final Color strokeColor;
  final Color inkColor;

  /// Horizontal pupil offset in 200-unit coordinates for the watching face.
  final double lookDx;

  /// Rotation angle in radians for spiral eyes in dizzy state.
  final double spiralRotation;

  /// Optional tongue color override (defaults to coral #FA7970).
  final Color? tongueColor;

  /// When set, the eyes and mouth come from this shape instead of [state].
  /// The refresh face uses it to blend between faces.
  final FaceShape? shape;

  @override
  void paint(Canvas canvas, Size size) {
    // Scale coordinate system to match standard 200x200 viewBox
    final scale = size.width / 200.0;
    canvas
      ..save()
      ..scale(scale, scale);

    final isAlarmed = state == FaceState.alarmed || state == FaceState.shocked;

    // Head fill
    const headRect = Rect.fromLTWH(12, 12, 176, 176);
    final headRRect = RRect.fromRectAndRadius(
      headRect,
      const Radius.circular(66),
    );

    final headFillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = fillColor;
    canvas.drawRRect(headRRect, headFillPaint);

    // Head stroke (12 units for alarmed and shocked, 10 units for all others)
    final headStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isAlarmed ? 12.0 : 10.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = strokeColor;
    canvas.drawRRect(headRRect, headStrokePaint);

    // Feature paints
    final isBold =
        isAlarmed ||
        state == FaceState.determined ||
        state == FaceState.laughing;
    final featureStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isBold ? 11.0 : 10.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = inkColor;

    final featureFillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = inkColor;

    final whiteFillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFFFFFF);

    final effectiveTongueColor = tongueColor ?? const Color(0xFFFA7970);

    final faceShape = shape ?? _ownShape;
    if (faceShape != null) {
      _paintShape(canvas, faceShape, featureFillPaint);
      canvas.restore();
      return;
    }

    switch (state) {
      case FaceState.working:
      case FaceState.success:
        // Drawn above from their FaceShape.
        break;

      case FaceState.calm:
        // Round eyes r 11 at (70, 90) and (130, 90)
        canvas.drawCircle(const Offset(70, 90), 11, featureFillPaint);
        canvas.drawCircle(const Offset(130, 90), 11, featureFillPaint);

        // Easy mouth M70 128 Q100 148 130 128
        final mouth = Path()
          ..moveTo(70, 128)
          ..quadraticBezierTo(100, 148, 130, 128);
        canvas.drawPath(mouth, featureStrokePaint);

      case FaceState.watching:
        // Drifting pupils r 11 at (80 + lookDx, 92) and (140 + lookDx, 92)
        canvas.drawCircle(Offset(80 + lookDx, 92), 11, featureFillPaint);
        canvas.drawCircle(Offset(140 + lookDx, 92), 11, featureFillPaint);

        // Raised left brow M56 68 Q70 58 86 64
        final brow = Path()
          ..moveTo(56, 68)
          ..quadraticBezierTo(70, 58, 86, 64);
        canvas.drawPath(brow, featureStrokePaint);

        // Flat mouth M84 134 H118
        final mouth = Path()
          ..moveTo(84, 134)
          ..lineTo(118, 134);
        canvas.drawPath(mouth, featureStrokePaint);

      case FaceState.worried:
        // Pinching brows M54 70 L84 58 and M116 58 L146 70
        final brows = Path()
          ..moveTo(54, 70)
          ..lineTo(84, 58)
          ..moveTo(116, 58)
          ..lineTo(146, 70);
        canvas.drawPath(brows, featureStrokePaint);

        // Round eyes r 11 at (70, 92) and (130, 92)
        canvas.drawCircle(const Offset(70, 92), 11, featureFillPaint);
        canvas.drawCircle(const Offset(130, 92), 11, featureFillPaint);

        // Wavering mouth M72 138 Q86 124 100 138 T128 138
        // Note: T (smooth quad) reflected control point:
        // 2*100-86=114, 2*138-124=152
        final mouth = Path()
          ..moveTo(72, 138)
          ..quadraticBezierTo(86, 124, 100, 138)
          ..quadraticBezierTo(114, 152, 128, 138);
        canvas.drawPath(mouth, featureStrokePaint);

      case FaceState.alarmed:
        // Downward angled brows M50 58 L84 68 and M116 68 L150 58
        final brows = Path()
          ..moveTo(50, 58)
          ..lineTo(84, 68)
          ..moveTo(116, 68)
          ..lineTo(150, 58);
        canvas.drawPath(brows, featureStrokePaint);

        // Wide outer eyes r 17 with stroke 11 at (70, 94) and (130, 94)
        canvas.drawCircle(const Offset(70, 94), 17, featureStrokePaint);
        canvas.drawCircle(const Offset(130, 94), 17, featureStrokePaint);

        // Inner pupil dots r 6 at (70, 94) and (130, 94)
        canvas.drawCircle(const Offset(70, 94), 6, featureFillPaint);
        canvas.drawCircle(const Offset(130, 94), 6, featureFillPaint);

        // Open mouth ellipse cx 100 cy 142 rx 17 ry 22
        canvas.drawOval(
          Rect.fromCenter(
            center: const Offset(100, 142),
            width: 34,
            height: 44,
          ),
          featureFillPaint,
        );

      case FaceState.acked:
        // Closed eyes arches M56 94 Q70 78 84 94 and M116 94 Q130 78 144 94
        final eyes = Path()
          ..moveTo(56, 94)
          ..quadraticBezierTo(70, 78, 84, 94)
          ..moveTo(116, 94)
          ..quadraticBezierTo(130, 78, 144, 94);
        canvas.drawPath(eyes, featureStrokePaint);

        // Gentle mouth M76 128 Q100 146 124 128
        final mouth = Path()
          ..moveTo(76, 128)
          ..quadraticBezierTo(100, 146, 124, 128);
        canvas.drawPath(mouth, featureStrokePaint);

      case FaceState.shocked:
        // Fierce downward angled eyebrows
        canvas.drawLine(
          const Offset(46, 62),
          const Offset(88, 80),
          featureStrokePaint,
        );
        canvas.drawLine(
          const Offset(154, 62),
          const Offset(112, 80),
          featureStrokePaint,
        );

        // Furrow crease mark between eyebrows
        final furrow = Path()
          ..moveTo(96, 64)
          ..lineTo(100, 73)
          ..lineTo(104, 64)
          ..moveTo(100, 73)
          ..lineTo(100, 83);
        canvas.drawPath(
          furrow,
          Paint()
            ..color = inkColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.0
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );

        // Huge wide eyes: white sclera + black border + black pupil + shine
        const leftEyeCenter = Offset(68, 102);
        const rightEyeCenter = Offset(132, 102);
        final eyeBorder = Paint()
          ..color = inkColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5;

        canvas.drawCircle(leftEyeCenter, 21, whiteFillPaint);
        canvas.drawCircle(leftEyeCenter, 21, eyeBorder);
        canvas.drawCircle(leftEyeCenter, 10.5, featureFillPaint);
        canvas.drawCircle(const Offset(64, 98), 3.5, whiteFillPaint);

        canvas.drawCircle(rightEyeCenter, 21, whiteFillPaint);
        canvas.drawCircle(rightEyeCenter, 21, eyeBorder);
        canvas.drawCircle(rightEyeCenter, 10.5, featureFillPaint);
        canvas.drawCircle(const Offset(128, 98), 3.5, whiteFillPaint);

        // Subtle under-eye shading arc
        final underEye = Paint()
          ..color = inkColor.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(
          Rect.fromCircle(center: leftEyeCenter, radius: 25),
          0.5,
          1,
          false,
          underEye,
        );
        canvas.drawArc(
          Rect.fromCircle(center: rightEyeCenter, radius: 25),
          1.64,
          1,
          false,
          underEye,
        );

        // Open screaming mouth
        final shockedMouth = Path()
          ..moveTo(82, 134)
          ..quadraticBezierTo(100, 122, 118, 134)
          ..quadraticBezierTo(126, 148, 124, 168)
          ..quadraticBezierTo(100, 172, 76, 168)
          ..quadraticBezierTo(74, 148, 82, 134)
          ..close();
        canvas.drawPath(shockedMouth, featureFillPaint);

        // Coral tongue at bottom of mouth
        canvas.save();
        canvas.clipPath(shockedMouth);
        final shockedTongue = Path()
          ..addOval(
            Rect.fromCenter(
              center: const Offset(100, 172),
              width: 36,
              height: 24,
            ),
          );
        canvas.drawPath(
          shockedTongue,
          Paint()
            ..color = effectiveTongueColor
            ..style = PaintingStyle.fill,
        );
        canvas.restore();

      case FaceState.laughing:
        // Squeezed > < eyes
        final leftEye = Path()
          ..moveTo(48, 74)
          ..lineTo(82, 90)
          ..lineTo(48, 106);
        canvas.drawPath(leftEye, featureStrokePaint);

        final rightEye = Path()
          ..moveTo(152, 74)
          ..lineTo(118, 90)
          ..lineTo(152, 106);
        canvas.drawPath(rightEye, featureStrokePaint);

        // Joyful wide laugh mouth
        final laughingMouth = Path()
          ..moveTo(52, 120)
          ..quadraticBezierTo(100, 126, 148, 120)
          ..quadraticBezierTo(148, 168, 100, 168)
          ..quadraticBezierTo(52, 168, 52, 120)
          ..close();
        canvas.drawPath(laughingMouth, featureFillPaint);

        // Tongue visible at base of mouth
        canvas.save();
        canvas.clipPath(laughingMouth);
        final laughingTongue = Path()
          ..addOval(
            Rect.fromCenter(
              center: const Offset(100, 170),
              width: 58,
              height: 34,
            ),
          );
        canvas.drawPath(
          laughingTongue,
          Paint()
            ..color = effectiveTongueColor
            ..style = PaintingStyle.fill,
        );
        canvas.restore();

      case FaceState.surprised:
        // Raised curved eyebrows
        final leftBrow = Path()
          ..moveTo(44, 58)
          ..quadraticBezierTo(62, 34, 84, 48);
        canvas.drawPath(leftBrow, featureStrokePaint);

        final rightBrow = Path()
          ..moveTo(116, 48)
          ..quadraticBezierTo(138, 34, 156, 58);
        canvas.drawPath(rightBrow, featureStrokePaint);

        // Big glossy cute eyes with shine highlight
        canvas.drawCircle(const Offset(68, 92), 21, featureFillPaint);
        canvas.drawCircle(const Offset(75, 84), 7.5, whiteFillPaint);

        canvas.drawCircle(const Offset(132, 92), 21, featureFillPaint);
        canvas.drawCircle(const Offset(139, 84), 7.5, whiteFillPaint);

        // Round open 'O' mouth
        canvas.drawCircle(const Offset(100, 144), 14, featureFillPaint);

      case FaceState.skeptical:
        // Cocked eyebrows (lowered left, raised right)
        final leftBrow = Path()
          ..moveTo(46, 70)
          ..quadraticBezierTo(66, 76, 86, 74);
        canvas.drawPath(leftBrow, featureStrokePaint);

        final rightBrow = Path()
          ..moveTo(110, 66)
          ..quadraticBezierTo(126, 42, 148, 58);
        canvas.drawPath(rightBrow, featureStrokePaint);

        // Round solid eyes
        canvas.drawCircle(const Offset(68, 94), 11, featureFillPaint);
        canvas.drawCircle(const Offset(126, 92), 11, featureFillPaint);

        // Slanted smirk mouth
        final mouth = Path()
          ..moveTo(72, 146)
          ..lineTo(126, 138);
        canvas.drawPath(mouth, featureStrokePaint);

      case FaceState.dizzy:
        // Worried drooping eyebrows
        final leftBrow = Path()
          ..moveTo(50, 66)
          ..quadraticBezierTo(70, 42, 82, 58);
        canvas.drawPath(leftBrow, featureStrokePaint);

        final rightBrow = Path()
          ..moveTo(118, 58)
          ..quadraticBezierTo(130, 42, 150, 66);
        canvas.drawPath(rightBrow, featureStrokePaint);

        // Hypnotic spiral swirl eyes
        final spiralPaint = Paint()
          ..color = inkColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        _drawSpiral(
          canvas,
          const Offset(72, 94),
          spiralPaint,
          rotation: spiralRotation,
        );
        _drawSpiral(
          canvas,
          const Offset(128, 94),
          spiralPaint,
          rotation: spiralRotation,
        );

        // Wavy wobbly mouth
        final mouth = Path()..moveTo(68, 146);
        mouth.cubicTo(74, 156, 82, 156, 88, 146);
        mouth.cubicTo(94, 136, 102, 136, 108, 146);
        mouth.cubicTo(114, 156, 122, 156, 128, 146);
        mouth.lineTo(132, 146);
        canvas.drawPath(
          mouth,
          Paint()
            ..color = inkColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9.0
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );

      case FaceState.determined:
        // Fierce downward V-brows
        final leftBrow = Path()
          ..moveTo(54, 46)
          ..lineTo(88, 70);
        canvas.drawPath(leftBrow, featureStrokePaint);

        final rightBrow = Path()
          ..moveTo(146, 46)
          ..lineTo(112, 70);
        canvas.drawPath(rightBrow, featureStrokePaint);

        // Sparkling anime eyes
        final eyeBorder = Paint()
          ..color = inkColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5;

        canvas.drawCircle(const Offset(70, 92), 20, whiteFillPaint);
        canvas.drawCircle(const Offset(70, 92), 20, eyeBorder);
        canvas.drawCircle(const Offset(70, 94), 14, featureFillPaint);
        canvas.drawCircle(const Offset(74, 86), 5.5, whiteFillPaint);
        canvas.drawCircle(const Offset(64, 98), 2.5, whiteFillPaint);

        canvas.drawCircle(const Offset(130, 92), 20, whiteFillPaint);
        canvas.drawCircle(const Offset(130, 92), 20, eyeBorder);
        canvas.drawCircle(const Offset(130, 94), 14, featureFillPaint);
        canvas.drawCircle(const Offset(134, 86), 5.5, whiteFillPaint);
        canvas.drawCircle(const Offset(124, 98), 2.5, whiteFillPaint);

        // Open yelling mouth with tongue
        final mouth = Path()
          ..moveTo(84, 134)
          ..quadraticBezierTo(100, 130, 116, 134)
          ..quadraticBezierTo(118, 156, 100, 158)
          ..quadraticBezierTo(82, 156, 84, 134)
          ..close();
        canvas.drawPath(mouth, featureFillPaint);

        canvas.save();
        canvas.clipPath(mouth);
        final tongue = Path()
          ..addOval(
            Rect.fromCenter(
              center: const Offset(100, 160),
              width: 28,
              height: 18,
            ),
          );
        canvas.drawPath(
          tongue,
          Paint()
            ..color = effectiveTongueColor
            ..style = PaintingStyle.fill,
        );
        canvas.restore();

      case FaceState.confused:
        // Asymmetrical puzzled brows
        final leftBrow = Path()
          ..moveTo(44, 76)
          ..quadraticBezierTo(62, 54, 82, 68);
        canvas.drawPath(leftBrow, featureStrokePaint);

        final rightBrow = Path()
          ..moveTo(122, 68)
          ..quadraticBezierTo(136, 68, 148, 76);
        canvas.drawPath(rightBrow, featureStrokePaint);

        // Round solid eyes
        canvas.drawCircle(const Offset(74, 98), 11, featureFillPaint);
        canvas.drawCircle(const Offset(126, 92), 11, featureFillPaint);

        // Slanted flat mouth
        final mouth = Path()
          ..moveTo(78, 142)
          ..lineTo(126, 134);
        canvas.drawPath(mouth, featureStrokePaint);

      case FaceState.sad:
        // Sad drooping brows
        final leftBrow = Path()
          ..moveTo(44, 86)
          ..quadraticBezierTo(60, 64, 82, 66);
        canvas.drawPath(leftBrow, featureStrokePaint);

        final rightBrow = Path()
          ..moveTo(118, 66)
          ..quadraticBezierTo(140, 64, 156, 86);
        canvas.drawPath(rightBrow, featureStrokePaint);

        // Round solid eyes
        canvas.drawCircle(const Offset(70, 98), 11, featureFillPaint);
        canvas.drawCircle(const Offset(130, 98), 11, featureFillPaint);

        // Downward frown mouth
        final mouth = Path()
          ..moveTo(66, 150)
          ..quadraticBezierTo(100, 126, 134, 150);
        canvas.drawPath(mouth, featureStrokePaint);
    }

    canvas.restore();
  }

  /// Working and success only exist as shapes. Calm keeps its old drawing
  /// unless a shape is passed in.
  FaceShape? get _ownShape => switch (state) {
    FaceState.working || FaceState.success => FaceShape.of(state),
    _ => null,
  };

  void _drawSpiral(
    Canvas canvas,
    Offset center,
    Paint paint, {
    double rotation = 0.0,
  }) {
    final path = Path();
    const steps = 60;
    const turns = 1.75;
    const maxR = 19.0;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final angle = t * turns * 2 * math.pi + rotation;
      final r = 3.0 + t * (maxR - 3.0);
      final pt = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  Paint _pen(Color color, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color;

  void _paintShape(Canvas canvas, FaceShape shape, Paint fill) {
    for (final eye in [shape.leftEye, shape.rightEye]) {
      if (eye.isDot) {
        // A zero length line would lean on how Skia caps it. Draw the dot.
        canvas.drawCircle(eye.points[1], eye.width / 2, fill);
      } else {
        final p = eye.points;
        canvas.drawPath(
          Path()
            ..moveTo(p[0].dx, p[0].dy)
            ..lineTo(p[1].dx, p[1].dy)
            ..lineTo(p[2].dx, p[2].dy),
          _pen(inkColor, eye.width),
        );
      }
    }

    // A smooth curve through the midpoints, so a wiggle reads as a wave and
    // not a zigzag.
    final m = shape.mouth.points;
    final mouth = Path()..moveTo(m.first.dx, m.first.dy);
    for (var i = 1; i < m.length - 1; i++) {
      final mid = Offset.lerp(m[i], m[i + 1], 0.5)!;
      mouth.quadraticBezierTo(m[i].dx, m[i].dy, mid.dx, mid.dy);
    }
    mouth.lineTo(m.last.dx, m.last.dy);
    canvas.drawPath(mouth, _pen(inkColor, shape.mouth.width));

    if (shape.burst > 0) {
      // Three short lines fanned above the head, growing out as burst goes
      // from 0 to 1. They sit outside the 200 unit box, above the head.
      final pen = _pen(
        inkColor.withValues(alpha: inkColor.a * shape.burst.clamp(0, 1)),
        8,
      );
      const centre = Offset(100, 100);
      for (final degrees in const [-120.0, -90.0, -60.0]) {
        final angle = degrees * math.pi / 180;
        final dir = Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(
          centre + dir * 110,
          centre + dir * (110 + 16 * shape.burst),
          pen,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant FacePainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.inkColor != inkColor ||
        oldDelegate.lookDx != lookDx ||
        oldDelegate.spiralRotation != spiralRotation ||
        oldDelegate.tongueColor != tongueColor ||
        oldDelegate.shape != shape;
  }
}
