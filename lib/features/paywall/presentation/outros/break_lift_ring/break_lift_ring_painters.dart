import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:critalarm/features/paywall/presentation/outros/break_lift_ring/break_lift_ring_timeline.dart';
import 'package:critalarm/features/paywall/presentation/outros/outro_parts.dart';
import 'package:flutter/material.dart';

typedef _T = BreakLiftRingTimeline;

/// The colours the outro draws with, all from the app's tokens.
@immutable
class BreakLiftRingColors {
  const BreakLiftRingColors({
    required this.paper,
    required this.line,
    required this.edge,
    required this.night,
    required this.cream,
    required this.yellow,
    required this.cobalt,
    required this.onCobalt,
    required this.ground,
  });

  /// The white the wall breaks into, and the flashes.
  final Color paper;

  /// The focus lines.
  final Color line;

  /// The ink edge of a piece.
  final Color edge;
  final Color night;
  final Color cream;
  final Color yellow;
  final Color cobalt;
  final Color onCobalt;

  /// The end state's colour, which a piece shows when there is no picture.
  final Color ground;
}

double _unit(Size size) => math.min(
  size.width / _T.reference.width,
  size.height / _T.reference.height,
);

/// The wall, the cracks, then the pieces flying out over the focus lines.
class BreakPainter extends CustomPainter {
  const BreakPainter({
    required this.t,
    required this.pieces,
    required this.colors,
    required this.focus,
    this.wall,
  });

  final double t;
  final List<BreakPiece> pieces;
  final BreakLiftRingColors colors;
  final ui.Image? wall;

  /// Where the focus lines point from: Crit's middle.
  final Offset focus;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final k = _unit(size);
    if (t < _T.hit) {
      paintOutroWall(canvas, rect, wall: wall, ground: colors.ground);
      final reach = _T.crack(t) * 640 * k;
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = colors.edge;
      for (final piece in pieces) {
        if (piece.reach < reach) canvas.drawPath(_path(piece), stroke);
      }
      return;
    }
    canvas.drawRect(rect, Paint()..color = colors.paper);
    _focusLines(canvas, size, k);
    for (final piece in pieces) {
      _piece(canvas, size, piece, k);
    }
    final flash = _T.hitFlash(t);
    if (flash > 0) {
      canvas.drawRect(
        rect,
        Paint()..color = colors.paper.withValues(alpha: flash),
      );
    }
  }

  Path _path(BreakPiece p) => Path()
    ..moveTo(p.a.dx, p.a.dy)
    ..lineTo(p.b.dx, p.b.dy)
    ..lineTo(p.c.dx, p.c.dy)
    ..close();

  void _piece(Canvas canvas, Size size, BreakPiece piece, double k) {
    final f = _T.flightOf(piece, t, k: k);
    final at = piece.centre + f.shift;
    final far = 200 * f.scale;
    if (at.dy - far > size.height ||
        at.dx + far < 0 ||
        at.dx - far > size.width) {
      return;
    }
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..rotate(f.turn)
      ..scale(f.scale)
      ..translate(-piece.centre.dx, -piece.centre.dy);
    final path = _path(piece);
    canvas
      ..drawPath(
        path.shift(const Offset(0, 8)),
        Paint()
          ..color = colors.edge.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      )
      ..drawPath(path, Paint()..color = colors.ground)
      ..save()
      ..clipPath(path);
    paintOutroWall(
      canvas,
      Offset.zero & size,
      wall: wall,
      ground: colors.ground,
    );
    canvas
      ..restore()
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 / f.scale
          ..strokeJoin = StrokeJoin.round
          ..color = colors.edge,
      )
      ..restore();
  }

  void _focusLines(Canvas canvas, Size size, double k) {
    final step = (t / 0.07).floor();
    final paint = Paint()..color = colors.line;
    for (var i = 0; i < 64; i++) {
      final an = i / 64 * math.pi * 2 + _T.rnd(i + step) * 0.08;
      final r0 = (215 + _T.rnd(i * 3 + step) * 130) * k;
      final w = 0.012 + _T.rnd(i * 7 + step) * 0.03;
      Offset on(double angle, double r) =>
          focus + Offset(math.cos(angle) * r, math.sin(angle) * r);
      canvas.drawPath(
        Path()
          ..moveTo(on(an, r0).dx, on(an, r0).dy)
          ..lineTo(on(an - w, 1100 * k).dx, on(an - w, 1100 * k).dy)
          ..lineTo(on(an + w, 1100 * k).dx, on(an + w, 1100 * k).dy)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(BreakPainter old) =>
      old.t != t || old.wall != wall || old.pieces != pieces;
}

/// The night: stars, speed lines and the trail while he lifts, the rings,
/// the cobalt disc, and the cobalt that opens from him onto the end state.
class SkyPainter extends CustomPainter {
  const SkyPainter({
    required this.t,
    required this.colors,
    required this.crit,
  });

  final double t;
  final BreakLiftRingColors colors;

  /// Crit's middle, his size and his lean now.
  final ({Offset centre, double size, double angle}) crit;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final k = _unit(size);
    final sx = size.width / _T.reference.width;
    final sy = size.height / _T.reference.height;
    final mid = Offset(195 * sx, 330 * sy);
    final scene = _T.scene(t);
    if (scene == BreakLiftRingScene.flood) {
      final far = math.max(mid.dx, size.width - mid.dx);
      final high = math.max(mid.dy, size.height - mid.dy);
      final r = _T.flood(t) * math.sqrt(far * far + high * high) * 1.02;
      canvas.drawPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(rect.inflate(2))
          ..addOval(Rect.fromCircle(center: mid, radius: r)),
        Paint()..color = colors.cobalt,
      );
      return;
    }
    canvas.drawRect(rect, Paint()..color = colors.night);
    _stars(canvas, size);
    if (scene == BreakLiftRingScene.flight) {
      _flight(canvas, size, k, sx, sy);
    } else {
      _rings(canvas, size, mid, k);
    }
    final flash = _T.cutFlash(t);
    if (flash > 0) {
      canvas.drawRect(
        rect,
        Paint()..color = colors.paper.withValues(alpha: flash),
      );
    }
  }

  void _stars(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < 70; i++) {
      final j = i + 5 * 17;
      paint.color = colors.cream.withValues(
        alpha: 0.3 + _T.rnd(j + 2) * 0.7,
      );
      final r = 1 + _T.rnd(j + 4) * 2.2;
      canvas.drawRect(
        Rect.fromLTWH(
          _T.rnd(j) * size.width,
          _T.rnd(j + 1) * size.height,
          r,
          r,
        ),
        paint,
      );
    }
  }

  void _flight(Canvas canvas, Size size, double k, double sx, double sy) {
    final z = _T.zoom(t);
    final pivot = Offset(195 * sx, 422 * sy);
    canvas
      ..save()
      ..translate(pivot.dx, pivot.dy)
      ..scale(z)
      ..save()
      ..rotate(_T.flightLean(t))
      ..scale(k);
    final alpha = _T.speedAlpha(t);
    if (alpha > 0) {
      final paint = Paint();
      for (var i = 0; i < 34; i++) {
        final j = i + 31;
        final x = (_T.rnd(j) - 0.5) * 1100;
        final len = 90 + _T.rnd(j + 9) * 420;
        final w = 3 + _T.rnd(j + 5) * _T.rnd(j + 6) * 34;
        final y =
            ((_T.rnd(j + 3) * 1500 + t * -2600 * (0.55 + _T.rnd(j + 7) * 0.9)) %
                1500) -
            750 -
            len / 2;
        final q = _T.rnd(j + 11);
        final base = q < 0.8
            ? colors.cream
            : (q < 0.9 ? colors.yellow : colors.cobalt);
        paint.color = base.withValues(
          alpha: alpha * (q < 0.5 ? 0.9 : (q < 0.8 ? 0.34 : 0.8)),
        );
        canvas.drawRect(Rect.fromLTWH(x, y, w, len), paint);
      }
    }
    canvas.restore();
    final keep = _T.trail(t);
    if (keep > 0.02) {
      final at = (crit.centre - pivot) / z;
      canvas
        ..save()
        ..translate(at.dx, at.dy)
        ..rotate(crit.angle)
        ..scale(ui.lerpDouble(0.5, 1, keep)! * k, keep * k)
        ..drawPath(
          Path()
            ..moveTo(-58, 60)
            ..lineTo(58, 60)
            ..lineTo(20, 900)
            ..lineTo(-20, 900)
            ..close(),
          Paint()..color = colors.cream,
        )
        ..drawPath(
          Path()
            ..moveTo(-22, 60)
            ..lineTo(22, 60)
            ..lineTo(4, 560)
            ..lineTo(-4, 560)
            ..close(),
          Paint()..color = colors.yellow,
        )
        ..restore();
    }
    canvas.restore();
  }

  void _rings(Canvas canvas, Size size, Offset mid, double k) {
    for (var i = 0; i < _T.rings.length; i++) {
      final p = _T.ring(i, t);
      if (p == null) continue;
      _stroke(
        canvas,
        mid,
        crit.size * 0.5 + _T.fast(p) * 640 * k,
        ui.lerpDouble(30, 3, p)! * k,
        i == 1 ? colors.cream : colors.yellow,
        1 - p * p,
      );
    }
    if (t >= _T.cobalt - 0.0001) {
      final diag = math.sqrt(
        size.width * size.width + size.height * size.height,
      );
      canvas.drawCircle(
        mid,
        _T.disc(t) * diag,
        Paint()..color = colors.cobalt,
      );
      for (var i = 0; i < 2; i++) {
        final p = _T.pulse(i, t);
        if (p == null) continue;
        _stroke(
          canvas,
          mid,
          crit.size * 0.56 * (1 + 0.6 * _T.easeOut(p)),
          4,
          colors.onCobalt,
          0.7 * (1 - p),
        );
      }
    }
  }

  void _stroke(
    Canvas canvas,
    Offset at,
    double r,
    double w,
    Color color,
    double alpha,
  ) {
    if (r <= 0 || alpha <= 0) return;
    canvas.drawCircle(
      at,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..color = color.withValues(alpha: alpha.clamp(0, 1).toDouble()),
    );
  }

  @override
  bool shouldRepaint(SkyPainter old) => old.t != t;
}
