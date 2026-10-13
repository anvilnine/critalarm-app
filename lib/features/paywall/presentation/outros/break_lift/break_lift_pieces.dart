import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:critalarm/features/paywall/presentation/outros/break_lift/break_lift_timeline.dart';
import 'package:flutter/painting.dart';

typedef _T = BreakLiftTimeline;

/// Draws every piece of the broken wall in two calls: one
/// `Canvas.drawVertices` that holds all the triangles with the wall picture
/// as its shader and the pieces' one alpha in the vertex colours, and one
/// `drawPath` that strokes all their outlines.
///
/// There is no layer, no clip, no blur and no picture draw per piece, so
/// the cost is the same for 56 pieces as for one. The typed lists and the
/// path are held here and reused every frame. The owner calls [dispose]
/// when it goes. There is no piece shadow in this outro: on its dark
/// ground it was all but invisible.
class BreakLiftPieceBatch {
  BreakLiftPieceBatch();

  static const int _count = 56;

  final Float32List _positions = Float32List(_count * 6);
  final Float32List _textureCoordinates = Float32List(_count * 6);
  final Int32List _colors = Int32List(_count * 3);
  final Path _edges = Path();
  final Paint _fill = Paint();
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeJoin = StrokeJoin.round;

  ui.ImageShader? _shader;
  ui.Image? _shaderImage;

  /// Draws the [pieces] flying at [t] on a canvas of [size]. [wall] is the
  /// picture each piece shows its part of, or null for [ground].
  void paint(
    Canvas canvas,
    Size size, {
    required double t,
    required List<BreakPiece> pieces,
    required ui.Image? wall,
    required Color ground,
    required Color edge,
  }) {
    final k = size.shortestSide / _T.reference.width;
    final alpha = _T.flightOf(pieces.first, t, k: k).alpha;
    // Under one step of eight bit alpha nothing shows, so nothing is drawn.
    if (alpha < 1 / 255) return;
    final scaleX = wall == null ? 0.0 : wall.width / size.width;
    final scaleY = wall == null ? 0.0 : wall.height / size.height;
    _edges.reset();
    var shown = 0;
    for (final piece in pieces.take(_count)) {
      final f = _T.flightOf(piece, t, k: k);
      final at = piece.centre + f.shift;
      final far = 200 * f.scale;
      if (at.dy - far > size.height ||
          at.dx + far < 0 ||
          at.dx - far > size.width) {
        continue;
      }
      final cos = math.cos(f.turn) * f.scale;
      final sin = math.sin(f.turn) * f.scale;
      final base = shown * 6;
      var first = true;
      var n = 0;
      for (final corner in [piece.a, piece.b, piece.c]) {
        final dx = corner.dx - piece.centre.dx;
        final dy = corner.dy - piece.centre.dy;
        final x = at.dx + dx * cos - dy * sin;
        final y = at.dy + dx * sin + dy * cos;
        _positions[base + n * 2] = x;
        _positions[base + n * 2 + 1] = y;
        _textureCoordinates[base + n * 2] = corner.dx * scaleX;
        _textureCoordinates[base + n * 2 + 1] = corner.dy * scaleY;
        if (first) {
          _edges.moveTo(x, y);
          first = false;
        } else {
          _edges.lineTo(x, y);
        }
        n++;
      }
      _edges.close();
      shown++;
    }
    if (shown == 0) return;

    // The picture times the alpha, or the ground at that alpha.
    final tint = wall == null
        ? ground.withValues(alpha: alpha).toARGB32()
        : const Color(0xFFFFFFFF).withValues(alpha: alpha).toARGB32();
    _colors.fillRange(0, shown * 3, tint);
    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      Float32List.sublistView(_positions, 0, shown * 6),
      textureCoordinates: wall == null
          ? null
          : Float32List.sublistView(_textureCoordinates, 0, shown * 6),
      colors: Int32List.sublistView(_colors, 0, shown * 3),
    );
    _fill.shader = wall == null ? null : _shaderFor(wall);
    canvas.drawVertices(
      vertices,
      wall == null ? ui.BlendMode.srcOver : ui.BlendMode.modulate,
      _fill,
    );
    vertices.dispose();
    canvas.drawPath(
      _edges,
      _stroke..color = edge.withValues(alpha: alpha),
    );
  }

  ui.ImageShader _shaderFor(ui.Image wall) {
    if (!identical(_shaderImage, wall)) {
      _shader?.dispose();
      _shader = ui.ImageShader(
        wall,
        ui.TileMode.clamp,
        ui.TileMode.clamp,
        Float64List.fromList(const [
          1,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          1,
        ]),
        filterQuality: FilterQuality.medium,
      );
      _shaderImage = wall;
    }
    return _shader!;
  }

  /// Lets go of the picture's shader.
  void dispose() {
    _shader?.dispose();
    _shader = null;
    _shaderImage = null;
  }
}
