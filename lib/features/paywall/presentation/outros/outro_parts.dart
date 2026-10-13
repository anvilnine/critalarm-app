import 'dart:math' as math;
import 'dart:ui';

// Shapes the success outros share. Each draws on a canvas it is handed and
// holds no time.

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
