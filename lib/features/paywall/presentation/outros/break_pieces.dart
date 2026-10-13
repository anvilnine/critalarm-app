import 'dart:ui' as ui;

import 'package:critalarm/features/paywall/presentation/outros/outro_parts.dart';
import 'package:flutter/painting.dart';

// The broken wall, shared by the two outros that break the paywall: one
// triangle of it, and how it is drawn.

/// One triangle of the broken wall.
class BreakPiece {
  const BreakPiece({
    required this.a,
    required this.b,
    required this.c,
    required this.centre,
    required this.reach,
    required this.velocity,
    required this.spin,
    required this.depth,
  });

  final Offset a;
  final Offset b;
  final Offset c;
  final Offset centre;

  /// How far its centre is from where the wall breaks, in screen units.
  final double reach;

  /// Screen points a second, outward from the break.
  final Offset velocity;

  /// Radians a second.
  final double spin;

  /// 0 to 1: how near the viewer it flies, so how much it grows.
  final double depth;
}

/// The outline of [piece] where it started.
Path breakPiecePath(BreakPiece piece) => Path()
  ..moveTo(piece.a.dx, piece.a.dy)
  ..lineTo(piece.b.dx, piece.b.dy)
  ..lineTo(piece.c.dx, piece.c.dy)
  ..close();

/// Draws [piece] moved by [shift] from where it started, turned by [turn]
/// and grown by [scale] about its middle, with a soft shadow and an ink
/// edge. It shows the part of [wall] it cut out, or [ground] with none.
/// [alpha] below one draws the whole piece, shadow and edge too, as one
/// see-through shape.
void paintBreakPiece(
  Canvas canvas,
  Size size,
  BreakPiece piece, {
  required Offset shift,
  required double turn,
  required double scale,
  required Color ground,
  required Color edge,
  ui.Image? wall,
  double alpha = 1,
}) {
  final at = piece.centre + shift;
  canvas
    ..save()
    ..translate(at.dx, at.dy)
    ..rotate(turn)
    ..scale(scale)
    ..translate(-piece.centre.dx, -piece.centre.dy);
  final path = breakPiecePath(piece);
  if (alpha < 1) {
    canvas.saveLayer(
      path.getBounds().inflate(24),
      Paint()..color = const Color(0xFF000000).withValues(alpha: alpha),
    );
  }
  canvas
    ..drawPath(
      path.shift(const Offset(0, 8)),
      Paint()
        ..color = edge.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    )
    ..drawPath(path, Paint()..color = ground)
    ..save()
    ..clipPath(path);
  paintOutroWall(
    canvas,
    Offset.zero & size,
    wall: wall,
    ground: ground,
  );
  canvas
    ..restore()
    ..drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 / scale
        ..strokeJoin = StrokeJoin.round
        ..color = edge,
    );
  if (alpha < 1) canvas.restore();
  canvas.restore();
}
