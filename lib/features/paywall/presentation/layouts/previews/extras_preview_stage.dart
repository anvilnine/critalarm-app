import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:flutter/material.dart';

// What the scenes of the widgets, app icons and weekly check previews
// share: the tile they sit on and the press of a drawn finger. Their clock
// is the kit's `PaywallPreviewClock`.

/// How far a pressed thing is squeezed at second [t], from 0 (at rest) to 1
/// (fully down), for a press that lands at [at]. It goes down fast and
/// springs back.
double pressAt(double t, double at) {
  if (t < at - 0.03 || t > at + 0.36) return 0;
  if (t <= at + 0.03) return phase(t, at - 0.03, at + 0.03);
  return 1 - AppCurves.easeSpring.transform(phase(t, at + 0.03, at + 0.36));
}

/// The drawn finger over a tap that lands at [at]: it closes in on the
/// spot, then lets go. `size` is its width against its resting width and
/// `opacity` is 0 whenever no finger is down.
({double size, double opacity}) tapAt(double t, double at) {
  if (t <= at - 0.26 || t >= at + 0.22) return (size: 1, opacity: 0);
  if (t <= at) {
    final p = AppCurves.easeOut.transform(phase(t, at - 0.26, at));
    return (size: 1.8 - 0.8 * p, opacity: p);
  }
  final p = phase(t, at, at + 0.22);
  return (size: 1 - 0.2 * p, opacity: 1 - p);
}

/// The corner of a preview tile whose short side is [edge].
double extrasPreviewRadius(double edge) => math.min(Radii.lg, edge * 0.28);

/// The tile a preview is drawn on. It clips to its corners, and its words
/// keep the size they were drawn at: a preview is a picture, so it does not
/// grow with the text size.
class ExtrasPreviewTile extends StatelessWidget {
  const ExtrasPreviewTile({
    required this.size,
    required this.child,
    this.color,
    super.key,
  });

  final Size size;
  final Widget child;

  /// The tile's surface. Null draws no tile, for a preview that fills its
  /// own box.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(
      extrasPreviewRadius(size.shortestSide),
    );
    return RepaintBoundary(
      child: MediaQuery.withNoTextScaling(
        child: ClipRRect(
          borderRadius: radius,
          child: color == null
              ? child
              : ColoredBox(
                  color: color!,
                  child: SizedBox.fromSize(size: size, child: child),
                ),
        ),
      ),
    );
  }
}

/// The drawn finger: a soft disc with a light edge, [diameter] wide at rest.
class ExtrasPreviewTap extends StatelessWidget {
  const ExtrasPreviewTap({
    required this.tap,
    required this.diameter,
    super.key,
  });

  final ({double size, double opacity}) tap;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    if (tap.opacity <= 0) return const SizedBox.shrink();
    final colors = context.appColors;
    final d = diameter * tap.size;
    return IgnorePointer(
      child: Opacity(
        opacity: tap.opacity,
        child: Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.inkFixed.withValues(alpha: 0.3),
            border: Border.all(
              color: colors.onHighlight.withValues(alpha: 0.85),
              width: math.max(1, diameter * 0.07),
            ),
          ),
        ),
      ),
    );
  }
}
