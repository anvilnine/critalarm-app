import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:flutter/material.dart';

// What the three limit previews (topics, pushes, history) share: one loop
// and the tile they sit on. Their clock is the kit's `PaywallPreviewClock`.

/// Seconds in one loop of the limit previews. The three share it and each
/// plays in its own part of it, so side by side they take turns:
/// topics first, then pushes, then history.
const double limitsPreviewPeriod = 9;

/// The second every limit preview rests on. Each loop starts on its
/// finished picture, so the still frame is the frame at zero.
const double limitsPreviewRestAt = 0;

/// The smallest type a limit preview draws. A label that would be smaller
/// is left out or drawn as a bar.
const double limitsPreviewMinType = 9;

/// Straight lines between `(second, value)` points: the value at [t].
/// Before the first point it is the first value, after the last the last.
double limitsKeyframes(double t, List<(double, double)> points) {
  if (t <= points.first.$1) return points.first.$2;
  for (var i = 1; i < points.length; i++) {
    final (t1, v1) = points[i];
    if (t <= t1) {
      final (t0, v0) = points[i - 1];
      if (t1 <= t0) return v1;
      return v0 + (v1 - v0) * (t - t0) / (t1 - t0);
    }
  }
  return points.last.$2;
}

/// The corner radius of a limit preview's tile [size].
double limitsTileRadius(Size size) =>
    math.min(Radii.lg, size.shortestSide * 0.28);

/// The rounded tile a limit preview draws on, clipped to its corners.
class LimitsPreviewTile extends StatelessWidget {
  const LimitsPreviewTile({
    required this.size,
    required this.color,
    required this.child,
    super.key,
  });

  final Size size;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(limitsTileRadius(size)),
    child: ColoredBox(
      color: color,
      // A picture, drawn to fit its box: it does not follow the text size.
      child: MediaQuery.withNoTextScaling(
        child: SizedBox.fromSize(size: size, child: child),
      ),
    ),
  );
}
