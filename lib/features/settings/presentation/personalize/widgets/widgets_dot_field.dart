import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The distance between two dots of the home screen's grid.
const double kWidgetsDotSpacing = 22;

/// The radius of one dot.
const double kWidgetsDotRadius = 1.4;

/// How far from an edge the dots take to fade in.
const double kWidgetsDotFade = 48;

/// The faint dot grid of a home screen, behind the drawn widgets.
///
/// [color] is the page's text colour; the grid draws it at low alpha. The dots
/// fade out toward the top and bottom edge, and toward the sides when
/// [fadesSides] is set (a column narrower than the display), so the grid never
/// ends in a hard line.
class WidgetsDotField extends StatelessWidget {
  const WidgetsDotField({
    required this.color,
    this.fadesSides = false,
    super.key,
  });

  final Color color;
  final bool fadesSides;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _DotPainter(color: color, fadesSides: fadesSides),
      size: Size.infinite,
    ),
  );
}

/// How strong a dot is at ([x], [y]) in a field [size] big, from 0 to 1: 1 in
/// the middle, falling to 0 at the edges that fade.
double _dotStrengthAt(
  double x,
  double y,
  Size size, {
  required bool fadesSides,
}) {
  var strength = math.min(
    (y / kWidgetsDotFade).clamp(0.0, 1.0),
    ((size.height - y) / kWidgetsDotFade).clamp(0.0, 1.0),
  );
  if (fadesSides) {
    strength = math.min(
      strength,
      math.min(
        (x / kWidgetsDotFade).clamp(0.0, 1.0),
        ((size.width - x) / kWidgetsDotFade).clamp(0.0, 1.0),
      ),
    );
  }
  return strength;
}

class _DotPainter extends CustomPainter {
  const _DotPainter({required this.color, required this.fadesSides});

  final Color color;
  final bool fadesSides;

  /// The alpha of a dot at full strength.
  static const double _alpha = 0.14;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (
      var y = kWidgetsDotSpacing / 2;
      y < size.height;
      y += kWidgetsDotSpacing
    ) {
      for (
        var x = kWidgetsDotSpacing / 2;
        x < size.width;
        x += kWidgetsDotSpacing
      ) {
        final strength = _dotStrengthAt(x, y, size, fadesSides: fadesSides);
        if (strength <= 0) continue;
        paint.color = color.withValues(alpha: _alpha * strength);
        canvas.drawCircle(Offset(x, y), kWidgetsDotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) =>
      old.color != color || old.fadesSides != fadesSides;
}
