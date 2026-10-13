import 'dart:math' as math;
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

/// A cloud: one pill with three round bumps on top. Every cloud in an
/// outro is drawn by this.
void paintOutroCloud(
  Canvas canvas,
  Offset centre,
  double width,
  double height,
  Color color,
) {
  final paint = Paint()..color = color;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
        centre.dx - width / 2,
        centre.dy - height * 0.1,
        width,
        height * 0.6,
      ),
      Radius.circular(height * 0.3),
    ),
    paint,
  );
  for (final (dx, r) in const [(-0.27, 0.36), (-0.02, 0.5), (0.26, 0.38)]) {
    canvas.drawCircle(
      Offset(centre.dx + dx * width, centre.dy - height * 0.06),
      r * height,
      paint,
    );
  }
}

/// A four-point star with soft waists, [radius] from the middle to a tip.
void paintOutroStar(Canvas canvas, Offset centre, double radius, Color color) {
  final path = Path();
  for (var i = 0; i < 8; i++) {
    final angle = i / 8 * math.pi * 2;
    final reach = i.isOdd ? radius * 0.34 : radius;
    final point = Offset(
      centre.dx + math.cos(angle) * reach,
      centre.dy + math.sin(angle) * reach,
    );
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  canvas.drawPath(path..close(), Paint()..color = color);
}
