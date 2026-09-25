import 'dart:math' as math;

import 'package:critalarm/design/faces/face_painter.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/ringing/ringing_frame.dart';
import 'package:flutter/rendering.dart';

/// Draws one [RingingFrame] on a square stage.
///
/// The stage is [stageUnits] wide in the same units the face painter uses,
/// with the face's 200 unit box in the middle, so the extras have room to
/// fly off the head without being cut off. The head, brows, eyes and mouth
/// are drawn by [FacePainter]; this adds the head's movement, its colour
/// changes and the extras.
class RingingFacePainter extends CustomPainter {
  /// Paints [frame] in the given colours.
  const RingingFacePainter({
    required this.frame,
    required this.fillColor,
    required this.strokeColor,
    required this.inkColor,
    required this.accentColor,
  });

  /// What to draw.
  final RingingFrame frame;

  /// The head.
  final Color fillColor;

  /// The head outline.
  final Color strokeColor;

  /// Brows, pupils, lids and mouths.
  final Color inkColor;

  /// The alarm colour: the flush, the siren, the anger vein.
  final Color accentColor;

  /// How wide the stage is, in face units. The face takes the middle 200.
  static const double stageUnits = 280;

  /// How far in the face's box starts.
  static const double _inset = (stageUnits - 200) / 2;

  static const Offset _middle = Offset(100, 100);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _sweatBlue = Color(0xFF8FD3F7);
  static const Color _tearBlue = Color(0xFF4FA8E8);
  static const Color _gold = Color(0xFFFFC93C);
  static const Color _starYellow = Color(0xFFFFD84A);
  static const Color _blushPink = Color(0xFFFF8FA3);

  @override
  void paint(Canvas canvas, Size size) {
    final f = frame;
    final fill = Color.lerp(fillColor, accentColor, f.flush * 0.8)!;
    final headFill = Color.lerp(fill, inkColor, f.flash)!;
    final ink = Color.lerp(inkColor, fill, f.flash)!;

    canvas
      ..save()
      ..scale(size.width / stageUnits)
      ..translate(_inset, _inset);

    for (final fx in f.fx) {
      if (!fx.onHead && !fx.inFront) _paintFx(canvas, fx, ink, headFill);
    }

    final nudge = f.nudge + f.face.nudge;
    canvas
      ..save()
      ..translate(nudge.dx, nudge.dy)
      ..translate(_middle.dx, _middle.dy)
      ..rotate(f.tilt + f.face.tilt)
      ..scale(f.scale)
      ..translate(-_middle.dx, -_middle.dy);

    for (final fx in f.fx) {
      if (fx.onHead && !fx.inFront) _paintFx(canvas, fx, ink, headFill);
    }

    FacePainter(
      state: FaceState.alarmed,
      fillColor: headFill,
      strokeColor: strokeColor,
      inkColor: ink,
      spiralRotation: f.spin,
      shape: f.face,
    ).paint(canvas, const Size(200, 200));

    // Extras on the head squash with it, the way the features do.
    canvas
      ..save()
      ..translate(_middle.dx, _middle.dy)
      ..scale(f.face.head.squashX, f.face.head.squashY)
      ..translate(-_middle.dx, -_middle.dy);
    for (final fx in f.fx) {
      if (fx.onHead && fx.inFront) _paintFx(canvas, fx, ink, headFill);
    }
    canvas
      ..restore()
      ..restore();

    for (final fx in f.fx) {
      if (!fx.onHead && fx.inFront) _paintFx(canvas, fx, ink, headFill);
    }
    canvas.restore();
  }

  Paint _pen(Color color, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = color;

  Paint _solid(Color color) => Paint()..color = color;

  Color _a(Color c, double alpha) => c.withValues(alpha: c.a * alpha);

  void _paintFx(Canvas canvas, RingFx fx, Color ink, Color headFill) {
    final alpha = fx.alpha.clamp(0.0, 1.0);
    if (alpha <= 0 || fx.scale <= 0) return;
    final line = _a(ink, alpha);

    canvas
      ..save()
      ..translate(fx.at.dx, fx.at.dy)
      ..rotate(fx.rotation)
      ..scale(fx.scale);

    switch (fx.kind) {
      case RingFxKind.soundWaves:
        // Three arcs either side of the head, rippling outward.
        for (final side in const [-1.0, 1.0]) {
          for (var i = 0; i < 3; i++) {
            final p = (fx.phase + i / 3) % 1;
            final r = 12 + p * 30;
            canvas.drawArc(
              Rect.fromCircle(center: Offset(side * 84, 0), radius: r),
              side < 0 ? math.pi * 0.75 : -math.pi * 0.25,
              math.pi * 0.5,
              false,
              _pen(_a(line, 1 - p), 6),
            );
          }
        }

      case RingFxKind.sweat:
      case RingFxKind.tear:
        final colour = fx.kind == RingFxKind.sweat ? _sweatBlue : _tearBlue;
        final drop = _dropPath(9);
        canvas
          ..drawPath(drop, _solid(_a(colour, alpha)))
          ..drawPath(drop, _pen(line, 3))
          ..drawCircle(
            const Offset(-2.5, 3),
            2.2,
            _solid(_a(_white, alpha)),
          );

      case RingFxKind.drip:
        final drop = _dropPath(10, stretch: 1.6);
        canvas
          ..drawPath(drop, _solid(_a(headFill, alpha)))
          ..drawPath(drop, _pen(_a(strokeColor, alpha), 4));

      case RingFxKind.steam:
        var cloud = Path();
        for (final (at, r) in const [
          (Offset.zero, 14.0),
          (Offset(14, 5), 10.0),
          (Offset(-12, 6), 9.0),
          (Offset(2, -10), 9.0),
        ]) {
          cloud = Path.combine(
            PathOperation.union,
            cloud,
            Path()..addOval(Rect.fromCircle(center: at, radius: r)),
          );
        }
        canvas
          ..drawPath(cloud, _solid(_a(_white, alpha * 0.95)))
          ..drawPath(cloud, _pen(_a(line, 0.7), 3.5));

      case RingFxKind.angerVein:
        // Four bent strokes around a gap: the cartoon cross of a temper.
        final pen = _pen(_a(accentColor, alpha), 6);
        for (var i = 0; i < 4; i++) {
          canvas
            ..save()
            ..rotate(i * math.pi / 2)
            ..drawPath(
              Path()
                ..moveTo(4, -16)
                ..quadraticBezierTo(4, -4, 16, -4),
              pen,
            )
            ..restore();
        }

      case RingFxKind.question:
        final path = Path()
          ..moveTo(-11, -12)
          ..cubicTo(-11, -26, 12, -27, 12, -13)
          ..cubicTo(12, -3, 0, -3, 0, 7);
        canvas
          ..drawPath(path, _pen(line, 7))
          ..drawCircle(const Offset(0, 19), 4.5, _solid(line));

      case RingFxKind.exclaim:
        final bar = Path()
          ..moveTo(-7, -26)
          ..lineTo(7, -26)
          ..lineTo(3, 6)
          ..lineTo(-3, 6)
          ..close();
        final dot = Path()
          ..addOval(Rect.fromCircle(center: const Offset(0, 16), radius: 5));
        for (final part in [bar, dot]) {
          canvas
            ..drawPath(part, _solid(_a(accentColor, alpha)))
            ..drawPath(part, _pen(line, 3.5));
        }

      case RingFxKind.star:
        final star = Path();
        for (var i = 0; i < 10; i++) {
          final r = i.isEven ? 13.0 : 5.5;
          final a = -math.pi / 2 + i * math.pi / 5;
          final p = Offset(r * math.cos(a), r * math.sin(a));
          if (i == 0) {
            star.moveTo(p.dx, p.dy);
          } else {
            star.lineTo(p.dx, p.dy);
          }
        }
        star.close();
        canvas
          ..drawPath(star, _solid(_a(_starYellow, alpha)))
          ..drawPath(star, _pen(line, 3));

      case RingFxKind.bell:
        // A dome sitting on a short stem, which stands on the head.
        final dome = Path()
          ..moveTo(-24, -6)
          ..quadraticBezierTo(-24, -36, 0, -36)
          ..quadraticBezierTo(24, -36, 24, -6)
          ..close();
        canvas
          ..drawLine(Offset.zero, const Offset(0, 14), _pen(line, 7))
          ..drawPath(dome, _solid(_a(_gold, alpha)))
          ..drawPath(dome, _pen(line, 5))
          ..drawCircle(const Offset(0, -38), 4.5, _solid(line))
          ..drawLine(
            const Offset(-12, -26),
            const Offset(-8, -30),
            _pen(_a(_white, alpha * 0.9), 3.5),
          );

      case RingFxKind.hammer:
        // Pivots at the top of the head and swings up between the bells.
        canvas
          ..drawLine(Offset.zero, const Offset(0, -40), _pen(line, 5))
          ..drawCircle(const Offset(0, -44), 7, _solid(_a(_gold, alpha)))
          ..drawCircle(const Offset(0, -44), 7, _pen(line, 4));

      case RingFxKind.bolt:
        final bolt = Path()
          ..moveTo(4, -24)
          ..lineTo(-10, 2)
          ..lineTo(0, 2)
          ..lineTo(-6, 24)
          ..lineTo(12, -6)
          ..lineTo(2, -6)
          ..lineTo(10, -24)
          ..close();
        canvas
          ..drawPath(bolt, _solid(_a(_starYellow, alpha)))
          ..drawPath(bolt, _pen(line, 3.5));

      case RingFxKind.siren:
        // Beams sweeping round behind a red dome.
        final sweep = fx.phase * 2 * math.pi;
        for (final offset in const [0.0, math.pi]) {
          final a = sweep + offset;
          final beam = Path()
            ..moveTo(0, -14)
            ..lineTo(
              130 * math.cos(a - 0.22),
              -14 + 130 * math.sin(a - 0.22) * 0.45,
            )
            ..lineTo(
              130 * math.cos(a + 0.22),
              -14 + 130 * math.sin(a + 0.22) * 0.45,
            )
            ..close();
          canvas.drawPath(beam, _solid(_a(accentColor, alpha * 0.28)));
        }
        final dome = Path()
          ..moveTo(-20, 0)
          ..lineTo(-20, -14)
          ..arcToPoint(
            const Offset(20, -14),
            radius: const Radius.circular(20),
          )
          ..lineTo(20, 0)
          ..close();
        final glow = 0.75 + 0.25 * math.cos(sweep);
        canvas
          ..drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(-28, -2, 56, 14),
              const Radius.circular(4),
            ),
            _solid(line),
          )
          ..drawPath(dome, _solid(_a(accentColor, alpha * glow)))
          ..drawPath(dome, _pen(line, 4.5))
          ..drawLine(
            const Offset(-9, -18),
            const Offset(-9, -8),
            _pen(_a(_white, alpha * 0.9), 4),
          );

      case RingFxKind.speedLines:
        // Three lines trailing below where the head is heading.
        final pen = _pen(_a(line, 0.8), 5);
        const lines = [(-22.0, 18.0), (0.0, 28.0), (22.0, 18.0)];
        for (final (dx, len) in lines) {
          canvas.drawLine(Offset(dx, 0), Offset(dx, len), pen);
        }

      case RingFxKind.teeth:
        // Drawn over a white mouth: a line along the bite and a few gaps
        // between the teeth, bent the same way the mouth is.
        final w = fx.extent.dx;
        final h = fx.extent.dy;
        final bend = fx.phase;
        double bent(double u) => bend * 4 * (u - 0.5) * (u - 0.5);
        final pen = _pen(line, 3.5);
        final bite = Path()..moveTo(-w / 2 + 3, bent(0.05));
        for (var i = 1; i <= 10; i++) {
          final u = 0.05 + 0.9 * i / 10;
          bite.lineTo(-w / 2 + w * u, bent(u));
        }
        canvas.drawPath(bite, pen);
        for (final u in const [0.25, 0.5, 0.75]) {
          final x = -w / 2 + w * u;
          canvas.drawLine(
            Offset(x, -h / 2 + bent(u) + 2),
            Offset(x, h / 2 + bent(u) - 2),
            pen,
          );
        }

      case RingFxKind.pulseRing:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 184, height: 184),
            const Radius.circular(70),
          ),
          _pen(_a(accentColor, alpha), 6),
        );

      case RingFxKind.blush:
        for (final side in const [-1.0, 1.0]) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(side * 48, 24),
              width: 24,
              height: 13,
            ),
            _solid(_a(_blushPink, alpha)),
          );
        }
    }
    canvas.restore();
  }

  /// A drop with its point up and its round end [r] across at the bottom.
  Path _dropPath(double r, {double stretch = 1}) => Path()
    ..moveTo(0, -r * 1.9 * stretch)
    ..quadraticBezierTo(r * 1.05, -r * 0.4, r, r * 0.4)
    ..arcToPoint(Offset(-r, r * 0.4), radius: Radius.circular(r))
    ..quadraticBezierTo(-r * 1.05, -r * 0.4, 0, -r * 1.9 * stretch)
    ..close();

  @override
  bool shouldRepaint(covariant RingingFacePainter oldDelegate) =>
      oldDelegate.frame != frame ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.strokeColor != strokeColor ||
      oldDelegate.inkColor != inkColor ||
      oldDelegate.accentColor != accentColor;
}
