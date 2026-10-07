import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:flutter/material.dart';

// What the three limit previews (topics, pushes, history) share: one loop,
// the clock they read it from, and the tile they sit on.

/// Seconds in one loop of the limit previews. The three share it and each
/// plays in its own part of it, so side by side they take turns:
/// topics first, then pushes, then history.
const double limitsPreviewPeriod = 9;

/// The second every limit preview rests on. Each loop starts on its
/// finished picture, so the still frame is the frame at zero.
const double limitsPreviewRestAt = 0;

/// Below this shortest side a limit preview draws its one part alone.
const double limitsPreviewSmallEdge = 88;

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

/// Rebuilds [builder] with the frame [frameAt] gives for the clock.
///
/// The clock is the layout's when a paywall frame is above, and the
/// widget's own when there is none (the gallery). A frame equal to the last
/// one is not redrawn, so a preview costs nothing while it rests.
///
/// With reduce motion on, or under a `PaywallStill`, the frame is the one
/// at [limitsPreviewRestAt] whatever the layout's clock reads.
class LimitsPreviewClock<F> extends StatelessWidget {
  const LimitsPreviewClock({
    required this.frameAt,
    required this.builder,
    super.key,
  });

  /// The frame at a clock second. Pure, and equal frames compare equal.
  final F Function(double t) frameAt;

  final Widget Function(BuildContext context, F frame) builder;

  @override
  Widget build(BuildContext context) {
    final clock = context
        .dependOnInheritedWidgetOfExactType<PaywallLayoutScopeProvider>()
        ?.scope
        .clock;
    return clock == null
        ? _OwnClock<F>(frameAt: frameAt, builder: builder)
        : _LayoutClock<F>(clock: clock, frameAt: frameAt, builder: builder);
  }
}

class _LayoutClock<F> extends StatefulWidget {
  const _LayoutClock({
    required this.clock,
    required this.frameAt,
    required this.builder,
  });

  final PaywallClock clock;
  final F Function(double t) frameAt;
  final Widget Function(BuildContext context, F frame) builder;

  @override
  State<_LayoutClock<F>> createState() => _LayoutClockState<F>();
}

class _LayoutClockState<F> extends State<_LayoutClock<F>> {
  bool _isStill = false;
  late F _frame;

  F _read() => widget.frameAt(
    _isStill || widget.clock.isStill ? limitsPreviewRestAt : widget.clock.value,
  );

  void _onTick() {
    final next = _read();
    if (next == _frame) return;
    setState(() => _frame = next);
  }

  @override
  void initState() {
    super.initState();
    _frame = _read();
    widget.clock.addListener(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isStill =
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
        PaywallStill.of(context);
    _frame = _read();
  }

  @override
  void didUpdateWidget(_LayoutClock<F> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clock != widget.clock) {
      oldWidget.clock.removeListener(_onTick);
      widget.clock.addListener(_onTick);
    }
    _frame = _read();
  }

  @override
  void dispose() {
    widget.clock.removeListener(_onTick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _frame);
}

class _OwnClock<F> extends StatefulWidget {
  const _OwnClock({required this.frameAt, required this.builder});

  final F Function(double t) frameAt;
  final Widget Function(BuildContext context, F frame) builder;

  @override
  State<_OwnClock<F>> createState() => _OwnClockState<F>();
}

class _OwnClockState<F> extends PaywallClockState<_OwnClock<F>> {
  F? _frame;

  @override
  double get restAt => limitsPreviewRestAt;

  @override
  void onTick() {
    final next = widget.frameAt(t);
    if (next == _frame) return;
    setState(() => _frame = next);
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frame = widget.frameAt(t);
    return widget.builder(context, frame);
  }
}

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
