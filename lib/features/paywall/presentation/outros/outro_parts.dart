import 'dart:ui' as ui;

import 'package:critalarm/design/design.dart';
import 'package:flutter/material.dart';

// Parts any success outro can use: Crit drawn from the face rig at a box,
// and the picture of the layout drawn edge to edge.

/// Crit drawn about [centre], leaning [angle] radians and squashed by
/// [squashX] and [squashY] about his middle. A direct child of a `Stack`.
class OutroCrit extends StatelessWidget {
  const OutroCrit({
    required this.centre,
    required this.size,
    required this.face,
    this.squashX = 1,
    this.squashY = 1,
    this.angle = 0,
    super.key,
  });

  final Offset centre;

  /// The edge of the square he is drawn in, before the squash.
  final double size;
  final FaceState face;
  final double squashX;
  final double squashY;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: centre.dx - size / 2,
      top: centre.dy - size / 2,
      width: size,
      height: size,
      child: Transform.rotate(
        angle: angle,
        child: Transform.scale(
          scaleX: squashX,
          scaleY: squashY,
          child: FaceWidget(
            state: face,
            shape: faceFor(face),
            size: size,
          ),
        ),
      ),
    );
  }
}

/// Draws [wall] over [rect], or fills [rect] with [ground] when there is
/// no picture. Clip the canvas first to draw part of it.
void paintOutroWall(
  Canvas canvas,
  Rect rect, {
  required ui.Image? wall,
  required Color ground,
}) {
  if (wall == null) {
    canvas.drawRect(rect, Paint()..color = ground);
    return;
  }
  canvas.drawImageRect(
    wall,
    Rect.fromLTWH(0, 0, wall.width.toDouble(), wall.height.toDouble()),
    rect,
    Paint()..filterQuality = FilterQuality.medium,
  );
}
