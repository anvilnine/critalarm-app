import 'dart:ui' as ui;

import 'package:critalarm/features/paywall/presentation/outros/break_lift/break_lift_timeline.dart';
import 'package:critalarm/features/paywall/presentation/outros/break_lift_ring/break_lift_ring_painters.dart';
import 'package:critalarm/features/paywall/presentation/outros/break_pieces.dart';
import 'package:flutter/material.dart';

export 'package:critalarm/features/paywall/presentation/outros/break_lift_ring/break_lift_ring_painters.dart'
    show BreakLiftRingColors;

typedef _T = BreakLiftTimeline;

/// What is drawn under Crit once the wall has broken: the paper the wall
/// breaks into, the night coming through it, the stars sliding by, one soft
/// trail under him while he rises, and the pieces drifting off and fading.
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
    canvas
      ..drawRect(rect, Paint()..color = colors.paper)
      ..drawRect(
        rect,
        Paint()..color = colors.night.withValues(alpha: night),
      );
    _stars(canvas, size, night);
    _trail(canvas, size);
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

  void _trail(Canvas canvas, Size size) {
    final alpha = _T.trailAlpha(t);
    final length = _T.trailLength(t, size);
    if (alpha <= 0.002 || length <= 1) return;
    final top = crit.bottom - crit.height * 0.08;
    final half = crit.width * 0.2;
    canvas.drawPath(
      Path()
        ..moveTo(crit.center.dx - half, top)
        ..lineTo(crit.center.dx + half, top)
        ..lineTo(crit.center.dx + half * 0.3, top + length)
        ..lineTo(crit.center.dx - half * 0.3, top + length)
        ..close(),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, top),
          Offset(0, top + length),
          [
            colors.cream.withValues(alpha: alpha),
            colors.cream.withValues(alpha: 0),
          ],
        ),
    );
  }

  @override
  bool shouldRepaint(BreakLiftPainter old) =>
      old.t != t || old.wall != wall || old.pieces != pieces;
}
