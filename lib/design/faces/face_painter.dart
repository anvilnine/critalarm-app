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
    this.shape,
  });

  final FaceState state;
  final Color fillColor;
  final Color strokeColor;
  final Color inkColor;

  /// Horizontal pupil offset in 200-unit coordinates for the watching face.
  final double lookDx;

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

    final isAlarmed = state == FaceState.alarmed;

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

    // Head stroke (12 units for alarmed, 10 units for all others)
    final headStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isAlarmed ? 12.0 : 10.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = strokeColor;
    canvas.drawRRect(headRRect, headStrokePaint);

    // Feature paints
    final featureStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isAlarmed ? 11.0 : 10.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = inkColor;

    final featureFillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = inkColor;

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
    }

    canvas.restore();
  }

  /// Working and success only exist as shapes. Calm keeps its old drawing
  /// unless a shape is passed in.
  FaceShape? get _ownShape => switch (state) {
    FaceState.working || FaceState.success => FaceShape.of(state),
    _ => null,
  };

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
        oldDelegate.shape != shape;
  }
}
