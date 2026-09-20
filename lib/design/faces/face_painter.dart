import 'dart:math' as math;

import 'package:critalarm/design/faces/face_shape.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:flutter/rendering.dart';

/// Draws one [FaceShape] in a 200 unit box.
///
/// Every face in the app is a shape now, so this painter has one job: take
/// the parts of a face and put them on the canvas. Which numbers make up
/// which face lives in `face_shape.dart`.
class FacePainter extends CustomPainter {
  /// Paints [shape], or the face [state] rests at when no shape is given.
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

  /// The face to draw when [shape] is null, and the source of the head
  /// colours either way.
  final FaceState state;

  /// The head.
  final Color fillColor;

  /// The head outline.
  final Color strokeColor;

  /// Brows, pupils, lids and mouths.
  final Color inkColor;

  /// Slides both pupils sideways, which is how the watching face drifts.
  final double lookDx;

  /// Turns the swirl in a spiral eye.
  final double spiralRotation;

  /// Fills an open mouth that does not name its own colour. Coral by default.
  final Color? tongueColor;

  /// Draws this instead of the face [state] rests at.
  final FaceShape? shape;

  static const Color _white = Color(0xFFFFFFFF);
  static const Rect _headRect = Rect.fromLTWH(12, 12, 176, 176);
  static const Offset _middle = Offset(100, 100);

  @override
  void paint(Canvas canvas, Size size) {
    final face = shape ?? faceFor(state);
    canvas
      ..save()
      ..scale(size.width / 200);

    // A squashed head takes everything drawn on it along, so the features
    // never slide off a head that has changed shape.
    if (face.head.squashX != 1 || face.head.squashY != 1) {
      canvas
        ..translate(_middle.dx, _middle.dy)
        ..scale(face.head.squashX, face.head.squashY)
        ..translate(-_middle.dx, -_middle.dy);
    }

    final head = RRect.fromRectAndRadius(_headRect, const Radius.circular(66));
    canvas
      ..drawRRect(head, Paint()..color = fillColor)
      ..drawRRect(head, _pen(strokeColor, face.head.strokeWidth));

    for (final brow in [face.leftBrow, face.rightBrow]) {
      _paintBrow(canvas, brow);
    }
    for (final eye in [face.leftEye, face.rightEye]) {
      _paintEye(canvas, eye);
    }
    _paintMouth(canvas, face.mouth);
    for (final prop in face.props) {
      _paintProp(canvas, prop);
    }

    canvas.restore();
  }

  Paint _pen(Color color, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color;

  Color _ink(double alpha) => inkColor.withValues(alpha: inkColor.a * alpha);

  /// A curve through three points, where the middle one sits on the curve
  /// itself. The control point is pulled back out so it does.
  Path _through(List<Offset> p) {
    final control = p[1] * 2 - (p[0] + p[2]) / 2;
    return Path()
      ..moveTo(p[0].dx, p[0].dy)
      ..quadraticBezierTo(control.dx, control.dy, p[2].dx, p[2].dy);
  }

  void _paintBrow(Canvas canvas, BrowShape brow) {
    final alpha = brow.alpha.clamp(0.0, 1.0);
    if (alpha <= 0) return;
    canvas.drawPath(_through(brow.points), _pen(_ink(alpha), brow.width));
  }

  void _paintEye(Canvas canvas, EyeShape eye) {
    final open = (1 - eye.lid).clamp(0.0, 1.0);
    final shut = eye.lid.clamp(0.0, 1.0);

    if (open > 0) {
      // A lid comes down over an eye, it does not fade through it. So the
      // eye is squeezed flat against the lid line as it shuts, and what is
      // left of it is what you see under a half closed lid.
      final lidMiddle = eye.resolvedLidPoints[1];
      final centre = Offset.lerp(eye.centre, lidMiddle, shut)!;
      final squeeze = open;

      final ball = Rect.fromCenter(
        center: centre,
        width: eye.ball * 2,
        height: eye.ball * 2 * eye.ballSquash * squeeze,
      );
      final pupil =
          centre +
          Offset(
            eye.pupilOffset.dx + lookDx,
            eye.pupilOffset.dy * squeeze,
          );
      // A plain dot has no white showing at all. As the eye opens the white
      // and its ring fade up together, so the ring never draws itself tight
      // around a pupil it is the same size as.
      final white = eye.whiteShowing;

      if (white > 0) {
        // Most ringed eyes have a white behind the pupil. The alarm's wide
        // ring leaves the head showing through instead.
        final inside = eye.ballIsHead ? fillColor : _white;
        canvas
          ..drawOval(
            ball,
            Paint()..color = inside.withValues(alpha: inside.a * white),
          )
          ..save()
          // The pupil is kept inside the white, so an eye looking hard to one
          // side crowds the edge instead of leaking past it.
          ..clipPath(Path()..addOval(ball));
      }

      if (eye.spiral > 0) {
        _paintSpiral(canvas, pupil, eye.pupilRadius, eye.spiral);
      } else if (eye.pupilRadius > 0) {
        canvas.drawOval(
          Rect.fromCenter(
            center: pupil,
            width: eye.pupilRadius * 2,
            height: eye.pupilRadius * 2 * squeeze,
          ),
          Paint()..color = inkColor,
        );
      }
      if (eye.shineRadius > 0) {
        canvas.drawOval(
          Rect.fromCenter(
            center:
                pupil +
                Offset(eye.shineOffset.dx, eye.shineOffset.dy * squeeze),
            width: eye.shineRadius * 2,
            height: eye.shineRadius * 2 * squeeze,
          ),
          Paint()..color = _white,
        );
      }

      if (white > 0) {
        canvas
          ..restore()
          ..drawOval(ball, _pen(_ink(white), eye.ballWidth));
      }
    }

    if (shut > 0) {
      canvas.drawPath(
        _through(eye.resolvedLidPoints),
        _pen(_ink(shut), eye.lidWidth),
      );
    }
  }

  /// Two and a half turns of a swirl, for the dizzy eyes.
  void _paintSpiral(Canvas canvas, Offset centre, double radius, double alpha) {
    if (alpha <= 0) return;
    final path = Path()..moveTo(centre.dx, centre.dy);
    const steps = 48;
    const turns = 2.5;
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final angle = spiralRotation + t * turns * 2 * math.pi;
      final r = radius * t;
      path.lineTo(
        centre.dx + r * math.cos(angle),
        centre.dy + r * math.sin(angle),
      );
    }
    canvas.drawPath(path, _pen(_ink(alpha), 4));
  }

  void _paintMouth(Canvas canvas, MouthShape mouth) {
    final m = mouth.points;
    // A smooth curve through the midpoints, so a wiggle reads as a wave and
    // not a zigzag.
    final path = Path()..moveTo(m.first.dx, m.first.dy);
    for (var i = 1; i < m.length - 1; i++) {
      final mid = Offset.lerp(m[i], m[i + 1], 0.5)!;
      path.quadraticBezierTo(m[i].dx, m[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(m.last.dx, m.last.dy);

    final fill = mouth.fill.clamp(0.0, 1.0);
    if (fill > 0) {
      final inside = Path.from(path)..close();
      // A dark mouth follows the ink so it reads in both themes. Everything
      // else is a tongue, which is coral whatever the theme is doing.
      final colour =
          mouth.fillColor ??
          (mouth.fillsWithInk
              ? inkColor
              : (tongueColor ?? const Color(0xFFFA7970)));
      canvas.drawPath(
        inside,
        Paint()..color = colour.withValues(alpha: colour.a * fill),
      );
    }
    if (mouth.width > 0) {
      canvas.drawPath(path, _pen(inkColor, mouth.width));
    }
  }

  void _paintProp(Canvas canvas, PropShape prop) {
    final alpha = prop.alpha.clamp(0.0, 1.0);
    if (alpha <= 0 || prop.scale <= 0) return;
    final ink = _ink(alpha);

    switch (prop.kind) {
      case PropKind.popLines:
        // Three short lines fanned above the head.
        final pen = _pen(ink, 8);
        for (final degrees in const [-120.0, -90.0, -60.0]) {
          final angle = degrees * math.pi / 180;
          final dir = Offset(math.cos(angle), math.sin(angle));
          canvas.drawLine(
            prop.at + dir * 110,
            prop.at + dir * (110 + 16 * prop.scale),
            pen,
          );
        }

      case PropKind.zzz:
        // Three Z's climbing away, each smaller than the one before it.
        for (var i = 0; i < 3; i++) {
          final size = (16 - i * 4) * prop.scale;
          final at = prop.at + Offset(i * 13.0, -i * 15.0) * prop.scale;
          canvas.drawPath(
            Path()
              ..moveTo(at.dx, at.dy)
              ..lineTo(at.dx + size, at.dy)
              ..lineTo(at.dx, at.dy + size)
              ..lineTo(at.dx + size, at.dy + size),
            _pen(ink, 4 * prop.scale),
          );
        }

      case PropKind.puff:
        // A small cloud. The circles are merged into one shape first, or the
        // outline draws every circle it is made of and reads as a scribble.
        const blobs = [
          (Offset.zero, 14.0),
          (Offset(16, 6), 10.0),
          (Offset(-3, 14), 9.0),
        ];
        var cloud = Path();
        for (final (at, r) in blobs) {
          final blob = Path()
            ..addOval(
              Rect.fromCircle(
                center: prop.at + at * prop.scale,
                radius: r * prop.scale,
              ),
            );
          cloud = Path.combine(PathOperation.union, cloud, blob);
        }
        canvas
          ..drawPath(cloud, Paint()..color = _white.withValues(alpha: alpha))
          ..drawPath(cloud, _pen(ink, 4.5 * prop.scale));

      case PropKind.heart:
        final s = prop.scale;
        final heart = Path()
          ..moveTo(prop.at.dx, prop.at.dy + 13 * s)
          ..cubicTo(
            prop.at.dx - 16 * s,
            prop.at.dy + 1 * s,
            prop.at.dx - 9 * s,
            prop.at.dy - 12 * s,
            prop.at.dx,
            prop.at.dy - 4 * s,
          )
          ..cubicTo(
            prop.at.dx + 9 * s,
            prop.at.dy - 12 * s,
            prop.at.dx + 16 * s,
            prop.at.dy + 1 * s,
            prop.at.dx,
            prop.at.dy + 13 * s,
          )
          ..close();
        canvas.drawPath(
          heart,
          Paint()..color = const Color(0xFFE25563).withValues(alpha: alpha),
        );

      case PropKind.motionArcs:
        // A pair of curved lines either side of the head, for a shake.
        final pen = _pen(ink, 5 * prop.scale);
        for (final side in const [-1.0, 1.0]) {
          for (final spread in const [0.0, 1.0]) {
            final r = (14 + spread * 9) * prop.scale;
            canvas.drawArc(
              Rect.fromCircle(
                center: prop.at + Offset(side * 96, 0),
                radius: r,
              ),
              side < 0 ? math.pi * 0.72 : -math.pi * 0.28,
              math.pi * 0.56,
              false,
              pen,
            );
          }
        }
    }
  }

  @override
  bool shouldRepaint(covariant FacePainter oldDelegate) =>
      oldDelegate.state != state ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.inkColor != inkColor ||
      oldDelegate.lookDx != lookDx ||
      oldDelegate.spiralRotation != spiralRotation ||
      oldDelegate.tongueColor != tongueColor ||
      oldDelegate.shape != shape;
}
