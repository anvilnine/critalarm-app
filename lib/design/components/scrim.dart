import 'package:flutter/material.dart';

/// Dims the screen and, when [hole] is set, cuts a rounded window out of the
/// scrim with an optional [ring] around its edge.
///
/// Shared by the Feature Guide spotlight (which animates [hole] between
/// targets) and, without a hole, as the modal barrier behind dialogs and
/// sheets.
class AppScrim extends StatelessWidget {
  const AppScrim({
    this.hole,
    this.scrim = const Color(0x73000000), // rgba(0,0,0,.45)
    this.ring,
    this.holeRadius = 16,
    super.key,
  });

  /// The spot to keep clear. Null dims the whole screen.
  final Rect? hole;

  /// The dim colour drawn over the screen.
  final Color scrim;

  /// Stroke drawn around the hole. Null draws no ring.
  final Color? ring;

  /// Corner radius of the hole.
  final double holeRadius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: AppScrimPainter(
        hole: hole,
        scrim: scrim,
        ring: ring,
        holeRadius: holeRadius,
      ),
    );
  }
}

/// Paints the [AppScrim] barrier.
class AppScrimPainter extends CustomPainter {
  const AppScrimPainter({
    required this.hole,
    required this.scrim,
    required this.ring,
    required this.holeRadius,
  });

  final Rect? hole;
  final Color scrim;
  final Color? ring;
  final double holeRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Path()..addRect(Offset.zero & size);
    final rect = hole;
    if (rect == null || rect.isEmpty) {
      canvas.drawPath(screen, Paint()..color = scrim);
      return;
    }
    final cut = RRect.fromRectAndRadius(rect, Radius.circular(holeRadius));
    canvas.drawPath(
      Path.combine(PathOperation.difference, screen, Path()..addRRect(cut)),
      Paint()..color = scrim,
    );
    final ringColor = ring;
    if (ringColor != null) {
      canvas.drawRRect(
        cut,
        Paint()
          ..color = ringColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(AppScrimPainter old) =>
      old.hole != hole ||
      old.scrim != scrim ||
      old.ring != ring ||
      old.holeRadius != holeRadius;
}
