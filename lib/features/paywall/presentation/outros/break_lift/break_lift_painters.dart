import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:critalarm/features/paywall/presentation/outros/break_lift/break_lift_pieces.dart';
import 'package:critalarm/features/paywall/presentation/outros/break_lift/break_lift_timeline.dart';
import 'package:critalarm/features/paywall/presentation/outros/break_lift_ring/break_lift_ring_painters.dart';
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
    required this.batch,
    required this.colors,
    required this.crit,
    required this.lean,
    this.wall,
  });

  final double t;
  final List<BreakPiece> pieces;

  /// Draws the pieces. The owner keeps it between frames.
  final BreakLiftPieceBatch batch;
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
    batch.paint(
      canvas,
      size,
      t: t,
      pieces: pieces,
      wall: wall,
      ground: colors.ground,
      edge: colors.edge,
    );
  }

  void _stars(Canvas canvas, Size size, double night) {
    if (night <= 0) return;
    final paint = Paint();
    for (var i = 0; i < _T.stars.length; i++) {
      final star = _T.stars[i];
      final at = _T.starAt(i, t, size);
      if (at.dy < -star.edge || at.dy > size.height + star.edge) continue;
      paint.color = colors.cream.withValues(alpha: star.alpha * night);
      canvas.drawCircle(at, star.edge * 0.6, paint);
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

  /// One rocket plume under him: a soft teardrop of his yellow round a
  /// paler core, fading to nothing on every side and along its length. It
  /// is two round gradients stretched to the flame, so there is no blur to
  /// pay for. It leans with him and its tip sways on the clock.
  void _plume(Canvas canvas, Size size) {
    final alpha = _T.plumeAlpha(t);
    final length = _T.plumeLength(t, size);
    final width = _T.plumeWidth(t, size);
    if (alpha <= 0.002 || length <= 1 || width <= 1) return;
    final sway = _T.plumeSway(t, size);
    final core = Color.lerp(colors.yellow, colors.cream, 0.6)!;
    void glow(Color color, double a, double w, double l, double lean) {
      canvas
        ..save()
        ..translate(sway * lean, l * 0.5)
        ..scale(w / 2, l / 2)
        ..drawCircle(
          Offset.zero,
          1,
          Paint()
            ..shader = ui.Gradient.radial(
              Offset.zero,
              1,
              [
                color.withValues(alpha: a),
                color.withValues(alpha: a * 0.45),
                color.withValues(alpha: 0),
              ],
              const [0, 0.45, 1],
            ),
        )
        ..restore();
    }

    canvas
      ..save()
      ..translate(
        crit.center.dx - math.sin(lean) * crit.height * 0.36,
        crit.center.dy + math.cos(lean) * crit.height * 0.36,
      )
      ..rotate(lean);
    glow(colors.yellow, alpha * 0.85, width * 1.1, length * 1.05, 0.6);
    glow(core, alpha, width * 0.5, length * 0.62, 0.3);
    canvas.restore();
  }

  @override
  bool shouldRepaint(BreakLiftPainter old) =>
      old.t != t || old.wall != wall || old.pieces != pieces;
}
