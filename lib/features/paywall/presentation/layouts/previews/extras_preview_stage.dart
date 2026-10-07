import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:flutter/material.dart';

// What the widgets, app icons and weekly check previews share: where their
// clock comes from, the tile they sit on, and the press of a drawn finger.

/// A preview with a short side under this many points draws its simple
/// scene: one object and the thing that changes on it.
const double extrasPreviewFullEdge = 88;

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

/// Hands [builder] the second to draw.
///
/// Inside a paywall layout that is the layout's own clock, so every preview
/// on the screen keeps one time. Anywhere else (the gallery) the preview
/// runs a clock of its own. When nothing may move, the second is [restAt]:
/// the layout rests on its own frame, and a preview rests on this one.
class ExtrasPreviewClock extends StatelessWidget {
  const ExtrasPreviewClock({
    required this.restAt,
    required this.builder,
    super.key,
  });

  final double restAt;
  final Widget Function(BuildContext context, double t) builder;

  @override
  Widget build(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<PaywallLayoutScopeProvider>()
        ?.scope;
    if (scope == null) return _OwnClock(restAt: restAt, builder: builder);

    final isStill = context.reduceMotion || PaywallStill.of(context);
    return PaywallClockBuilder(
      clock: scope.clock,
      builder: (context, t, _) =>
          builder(context, isStill || scope.clock.isStill ? restAt : t),
    );
  }
}

class _OwnClock extends StatefulWidget {
  const _OwnClock({required this.restAt, required this.builder});

  final double restAt;
  final Widget Function(BuildContext context, double t) builder;

  @override
  State<_OwnClock> createState() => _OwnClockState();
}

class _OwnClockState extends PaywallClockState<_OwnClock> {
  @override
  double get restAt => widget.restAt;

  @override
  Widget build(BuildContext context) => widget.builder(context, t);
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
