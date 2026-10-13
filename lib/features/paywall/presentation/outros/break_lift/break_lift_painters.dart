import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:critalarm/features/paywall/presentation/outros/break_lift/break_lift_timeline.dart';
import 'package:critalarm/features/paywall/presentation/outros/break_lift_ring/break_lift_ring_painters.dart';
import 'package:critalarm/features/paywall/presentation/outros/break_pieces.dart';
import 'package:critalarm/features/paywall/presentation/outros/outro_parts.dart';
import 'package:flutter/material.dart';

export 'package:critalarm/features/paywall/presentation/outros/break_lift_ring/break_lift_ring_painters.dart'
    show BreakLiftRingColors;

typedef _T = BreakLiftTimeline;

/// What is drawn under Crit once the wall has broken: the night coming
/// through it, the stars and three layers of cloud falling past at their
/// own rates as he rises, one rocket plume under him, and the pieces
/// drifting off and fading. Nothing here flashes or steps.
class BreakLiftPainter extends CustomPainter {
  const BreakLiftPainter({
    required this.t,
    required this.pieces,
    required this.colors,
    required this.crit,
    required this.lean,
    this.wall,
  });

  final double t;
  final List<BreakPiece> pieces;
  final BreakLiftRingColors colors;
  final ui.Image? wall;

  /// The box Crit fills now, which the plume hangs from.
  final Rect crit;

  /// How far he leans now, in radians.
  final double lean;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final night = _T.night(t);
    canvas.drawRect(
      rect,
      Paint()
        ..color = _T.backdrop(t, ground: colors.ground, night: colors.night),
    );
    _stars(canvas, size, night);
    _clouds(canvas, size, BreakLiftLayer.far, 0.1);
    _clouds(canvas, size, BreakLiftLayer.mid, 0.17);
    _plume(canvas, size);
    _clouds(canvas, size, BreakLiftLayer.near, 0.26);
    final k = size.shortestSide / _T.reference.width;
    for (final piece in pieces) {
      final f = _T.flightOf(piece, t, k: k);
      if (f.alpha <= 0) continue;
      paintBreakPiece(
        canvas,
        size,
        piece,
        shift: f.shift,
        turn: f.turn,
        scale: f.scale,
        ground: colors.ground,
        edge: colors.edge,
        wall: wall,
        alpha: f.alpha,
      );
    }
  }

  void _stars(Canvas canvas, Size size, double night) {
    if (night <= 0) return;
    for (var i = 0; i < _T.stars.length; i++) {
      final star = _T.stars[i];
      paintOutroStar(
        canvas,
        _T.starAt(i, t, size),
        star.edge,
        colors.cream.withValues(alpha: star.alpha * night),
      );
    }
  }

  /// One layer of cloud, the near ones lightest. Its tone is the night
  /// lifted a little towards the cream, so it shows on the night in both
  /// themes without being white.
  void _clouds(Canvas canvas, Size size, BreakLiftLayer layer, double lift) {
    final alpha = _T.cloudAlpha(t);
    if (alpha <= 0) return;
    final color = Color.lerp(
      colors.night,
      colors.cream,
      lift,
    )!.withValues(alpha: alpha);
    final k = size.shortestSide == 0
        ? 1.0
        : math.min(
            size.width / _T.reference.width,
            size.height / _T.reference.height,
          );
    final list = _T.clouds(layer);
    for (var i = 0; i < list.length; i++) {
      final box = _T.cloudBox(layer, i, t, size);
      if (box.bottom < 0 || box.top > size.height) continue;
      final width = list[i].width * k;
      paintOutroCloud(
        canvas,
        _T.cloudAt(layer, i, t, size),
        width,
        width * _T.cloudRatio,
        color,
      );
    }
  }

  /// One rocket plume under him: a tapered flame of his yellow round a
  /// paler core, soft on every edge and fading to nothing along its
  /// length. It leans with him and its tip sways on the clock.
  void _plume(Canvas canvas, Size size) {
    final alpha = _T.plumeAlpha(t);
    final length = _T.plumeLength(t, size);
    final width = _T.plumeWidth(t, size);
    if (alpha <= 0.002 || length <= 1 || width <= 1) return;
    final sway = _T.plumeSway(t, size);
    final k = size.shortestSide / _T.reference.width;
    final core = Color.lerp(colors.yellow, colors.cream, 0.6)!;
    Path flame(double w, double l, double tip) => Path()
      ..moveTo(-w / 2, 0)
      ..quadraticBezierTo(-w * 0.5, l * 0.5, tip, l)
      ..quadraticBezierTo(w * 0.5, l * 0.5, w / 2, 0)
      ..close();
    Paint paint(Color color, double a, double l, double blur) => Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, l), [
        color.withValues(alpha: a),
        color.withValues(alpha: 0),
      ])
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur * k);
    canvas
      ..save()
      ..translate(
        crit.center.dx - math.sin(lean) * crit.height * 0.36,
        crit.center.dy + math.cos(lean) * crit.height * 0.36,
      )
      ..rotate(lean)
      ..drawPath(
        flame(width, length, sway),
        paint(colors.yellow, alpha * 0.8, length, 9),
      )
      ..drawPath(
        flame(width * 0.5, length * 0.62, sway * 0.6),
        paint(core, alpha, length * 0.62, 5),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(BreakLiftPainter old) =>
      old.t != t || old.wall != wall || old.pieces != pieces;
}
