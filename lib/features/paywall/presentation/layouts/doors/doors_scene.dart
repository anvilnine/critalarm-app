import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/doors/doors_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:flutter/material.dart';

/// The corner of a door, in points.
const double _doorRadius = 5;

/// The colours of the doors on the ink wall, in the current theme.
@immutable
class DoorsColors {
  const DoorsColors({
    required this.door,
    required this.edge,
    required this.light,
    required this.air,
    required this.label,
  });

  factory DoorsColors.of(BuildContext context) {
    final c = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DoorsColors(
      door: Color.alphaBlend(c.onPanel.withValues(alpha: 0.15), c.panel),
      edge: Color.alphaBlend(c.onPanel.withValues(alpha: 0.3), c.panel),
      // The app's own canvas is what is behind the door, with the air the
      // approved stage has. The dark theme gets a glow of the yellow, so
      // its dark preview still reads.
      light: isDark
          ? Color.alphaBlend(c.yellow.withValues(alpha: 0.3), c.panel)
          : c.canvas,
      air: isDark
          ? HeroAtmosphereColors(
              disc: c.yellow.withValues(alpha: 0.1),
              soft: c.yellow.withValues(alpha: 0.1),
              strong: c.yellow.withValues(alpha: 0.22),
              light: c.onPanel.withValues(alpha: 0.12),
            )
          : HeroAtmosphereColors.of(context, PaywallTone.canvas),
      label: c.onPanelMuted,
    );
  }

  /// A shut door, and the leaf seen face on.
  final Color door;

  /// The leaf seen edge on.
  final Color edge;

  /// What shows through the open doorway, and the shapes drifting in it.
  final Color light;
  final HeroAtmosphereColors air;
  final Color label;
}

/// What stands behind the stage: the shut door with its one label, and
/// the light in the open doorway, with the stage's air drifting in it.
class DoorsWall extends StatelessWidget {
  const DoorsWall({
    required this.size,
    required this.geometry,
    required this.label,
    this.seconds = 0,
    this.entrance = 1,
    super.key,
  });

  /// The clock, for the drift of the shapes. Zero holds them at home.
  final double seconds;

  /// How far through the stage's entrance, 0 to 1.
  final double entrance;

  /// The stage's box.
  final Size size;
  final DoorsGeometry geometry;

  /// The one word on the shut door.
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = DoorsColors.of(context);
    final free = geometry.freeDoor;
    final doorway = geometry.doorway;
    final card = geometry.arrangement.card;
    return ExcludeSemantics(
      child: SizedBox.fromSize(
        size: size,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _WallPainter(
                  doorway: geometry.doorway,
                  freeDoor: free,
                  door: colors.door,
                  light: colors.light,
                ),
              ),
            ),
            Positioned.fromRect(
              rect: doorway,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(_doorRadius),
                ),
                child: CustomPaint(
                  painter: HeroAtmospherePainter(
                    focus: card.center - doorway.topLeft,
                    radius: card.width * 0.62,
                    seconds: seconds,
                    entrance: entrance,
                    showsShapes: true,
                    disc: colors.air.disc,
                    soft: colors.air.soft,
                    strong: colors.air.strong,
                    light: colors.air.light,
                  ),
                ),
              ),
            ),
            Positioned(
              left: free.left,
              width: free.width,
              top: free.top + Spacing.s3,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                // A word on a picture of a door: it keeps the door's size.
                textScaler: TextScaler.noScaling,
                style: AppTypography.label(
                  colors.label,
                  fontSize: 12,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WallPainter extends CustomPainter {
  const _WallPainter({
    required this.doorway,
    required this.freeDoor,
    required this.door,
    required this.light,
  });

  final Rect doorway;
  final Rect freeDoor;
  final Color door;
  final Color light;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = Radius.circular(_doorRadius);
    canvas
      ..drawRRect(
        RRect.fromRectAndCorners(freeDoor, topLeft: radius, topRight: radius),
        Paint()..color = door,
      )
      ..drawRRect(
        RRect.fromRectAndCorners(doorway, topLeft: radius, topRight: radius),
        Paint()..color = light,
      );
  }

  @override
  bool shouldRepaint(_WallPainter old) =>
      doorway != old.doorway ||
      freeDoor != old.freeDoor ||
      door != old.door ||
      light != old.light;
}

/// The right door's leaf, drawn over the stage. Shut, it covers the
/// doorway. Open, it is its own edge, square against the right of the
/// doorway. In between it swings away from the eye on its right hinge.
class DoorsLeaf extends StatelessWidget {
  const DoorsLeaf({
    required this.size,
    required this.doorway,
    required this.open,
    super.key,
  });

  /// The stage's box.
  final Size size;
  final Rect doorway;

  /// How far open, 0 to 1.
  final double open;

  @override
  Widget build(BuildContext context) {
    final colors = DoorsColors.of(context);
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: size,
          painter: _LeafPainter(
            doorway: doorway,
            open: open,
            door: colors.door,
            edge: colors.edge,
          ),
        ),
      ),
    );
  }
}

class _LeafPainter extends CustomPainter {
  const _LeafPainter({
    required this.doorway,
    required this.open,
    required this.door,
    required this.edge,
  });

  final Rect doorway;
  final double open;
  final Color door;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = doorsLeafShapeFor(
      open: open,
      width: doorway.width,
      height: doorway.height,
    );
    final hinge = doorway.right;
    final free = hinge - shape.width;
    final paint = Paint()
      ..color = Color.lerp(door, edge, math.sin(open * math.pi / 2))!;

    if (shape.taper == 0) {
      // Shut or fully open: a square door, with the doorway's corners.
      const radius = Radius.circular(_doorRadius);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(free, doorway.top, hinge, doorway.bottom),
          topLeft: open < 0.5 ? radius : Radius.zero,
          topRight: radius,
        ),
        paint,
      );
      return;
    }
    canvas.drawPath(
      Path()
        ..moveTo(hinge, doorway.top)
        ..lineTo(hinge, doorway.bottom)
        ..lineTo(free, doorway.bottom - shape.taper)
        ..lineTo(free, doorway.top + shape.taper)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(_LeafPainter old) =>
      open != old.open ||
      doorway != old.doorway ||
      door != old.door ||
      edge != old.edge;
}
