import 'dart:ui' as ui;

import 'package:critalarm/features/paywall/presentation/outros/break_lift/break_lift_timeline.dart';
import 'package:critalarm/features/paywall/presentation/outros/break_lift_ring/break_lift_ring_painters.dart';
import 'package:critalarm/features/paywall/presentation/outros/break_pieces.dart';
import 'package:flutter/material.dart';

export 'package:critalarm/features/paywall/presentation/outros/break_lift_ring/break_lift_ring_painters.dart'
    show BreakLiftRingColors;

typedef _T = BreakLiftTimeline;

/// What is drawn under Crit once the wall has broken: the night the wall
/// breaks into, coming through it, the stars sliding by, one soft
/// glow under him while he rises, and the pieces drifting off and fading.
/// Nothing here flashes or steps.
class BreakLiftPainter extends CustomPainter {
  const BreakLiftPainter({
    required this.t,
    required this.pieces,
    required this.colors,
    required this.crit,
    this.wall,
  });

  final double t;
  final List<BreakPiece> pieces;
  final BreakLiftRingColors colors;
  final ui.Image? wall;

  /// The box Crit fills now, which the trail hangs from.
  final Rect crit;

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
    _glow(canvas, size);
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
    final paint = Paint();
    for (var i = 0; i < _T.stars.length; i++) {
      final star = _T.stars[i];
      paint.color = colors.cream.withValues(alpha: star.alpha * night);
      canvas.drawCircle(_T.starAt(i, t, size), star.edge / 2, paint);
    }
  }

  /// One soft glow of his yellow under him, fading to nothing on every
  /// side. It is a round gradient stretched to the glow's width and height.
  void _glow(Canvas canvas, Size size) {
    final alpha = _T.trailAlpha(t);
    final w = _T.trailWidth(t, size);
    final h = _T.trailLength(t, size);
    if (alpha <= 0.002 || w <= 1 || h <= 1) return;
    final centre = Offset(
      crit.center.dx,
      crit.bottom - crit.height * 0.1 + h * 0.4,
    );
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..scale(w / 2, h / 2)
      ..drawCircle(
        Offset.zero,
        1,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset.zero,
            1,
            [
              colors.yellow.withValues(alpha: alpha),
              colors.yellow.withValues(alpha: 0),
            ],
          ),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(BreakLiftPainter old) =>
      old.t != t || old.wall != wall || old.pieces != pieces;
}
