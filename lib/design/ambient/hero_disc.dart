import 'package:flutter/material.dart';

/// Paints the disc and the ring behind the hero scene's face.
///
/// Two concentric circles about [centre]: a filled disc and, around it, a
/// thin ring. Each scales on its own about the same centre, so the two breathe
/// out of step. The painter draws past its own box on purpose: the disc is
/// bigger than the scene and runs under the list sheet.
class HeroDiscPainter extends CustomPainter {
  const HeroDiscPainter({
    required this.centre,
    required this.discDiameter,
    required this.ringDiameter,
    required this.discColor,
    required this.ringColor,
    this.discScale = 1,
    this.ringScale = 1,
    this.ringWidth = 3,
  });

  /// Where both circles are centred, in the painter's own coordinates.
  final Offset centre;

  /// Diameter of the disc at scale 1.
  final double discDiameter;

  /// Diameter of the ring at scale 1.
  final double ringDiameter;

  final Color discColor;
  final Color ringColor;

  /// 1 at rest.
  final double discScale;

  /// 1 at rest.
  final double ringScale;

  /// Stroke width of the ring.
  final double ringWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawCircle(
        centre,
        discDiameter / 2 * discScale,
        Paint()..color = discColor,
      )
      ..drawCircle(
        centre,
        ringDiameter / 2 * ringScale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringWidth
          ..color = ringColor,
      );
  }

  @override
  bool shouldRepaint(HeroDiscPainter old) =>
      old.centre != centre ||
      old.discDiameter != discDiameter ||
      old.ringDiameter != ringDiameter ||
      old.discColor != discColor ||
      old.ringColor != ringColor ||
      old.discScale != discScale ||
      old.ringScale != ringScale ||
      old.ringWidth != ringWidth;
}

/// The disc and ring as a widget, in a repaint boundary of its own so a
/// breath repaints these two circles and nothing else.
///
/// It fills the box it is given and paints past it. Put it first in a
/// [Stack], behind everything.
class HeroDisc extends StatelessWidget {
  const HeroDisc({required this.painter, super.key});

  final HeroDiscPainter painter;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: painter, size: Size.infinite),
      ),
    ),
  );
}
