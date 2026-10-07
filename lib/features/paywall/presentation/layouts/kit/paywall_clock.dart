import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// The clock a layout animates from: one number, seconds since it appeared.
// A layout works out every position, fade and face from that number, so its
// resting frame is simply the frame at `restAt`.

/// How far through the window from [start] to [end] the clock [t] is, from
/// 0 to 1. Before the window it is 0 and after it 1. A window with no
/// length steps from 0 to 1 at [start].
double phase(double t, double start, double end) {
  if (end <= start) return t >= end ? 1 : 0;
  return ((t - start) / (end - start)).clamp(0.0, 1.0);
}

/// Where [t] is inside a loop [period] seconds long, from 0 up to [period].
/// A period of zero or less answers 0.
double loopT(double t, double period) {
  if (period <= 0) return 0;
  final local = t % period;
  return local < 0 ? local + period : local;
}

/// The clock as item [index] of a staggered row sees it: seconds since that
/// item started, and 0 until it does. The first item starts at [start] and
/// each one after it [each] seconds later.
///
/// Feed it to [phase]: `phase(stagger(i, t, each: 0.08), 0, 0.4)`.
double stagger(int index, double t, {double each = 0.08, double start = 0}) {
  final local = t - start - index * each;
  return local < 0 ? 0 : local;
}

/// Tells every clock below it to hold still on its resting frame. The
/// capture tool and a thumbnail use it.
class PaywallStill extends InheritedWidget {
  const PaywallStill({required super.child, this.isStill = true, super.key});

  final bool isStill;

  /// Whether the clocks under [context] should hold still.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PaywallStill>()?.isStill ??
      false;

  @override
  bool updateShouldNotify(PaywallStill oldWidget) =>
      isStill != oldWidget.isStill;
}

/// A `State` that knows how many seconds its widget has been on screen.
///
/// Read [t] in `build`. The widget is rebuilt every frame while the clock
/// runs.
///
/// - With reduce motion on, or inside a [PaywallStill], [t] is [restAt] and
///   no ticker runs. The resting frame must be complete: nothing half way.
/// - While the route is not on top the clock stops, and carries on from the
///   same second when the route is back.
abstract class PaywallClockState<T extends StatefulWidget> extends State<T>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  /// Seconds run before the ticker last started.
  double _banked = 0;
  double _seconds = 0;
  bool _isStill = false;
  bool _isOnTop = true;

  /// The second a still layout rests on: after its entrance, on the frame
  /// that says the most.
  double get restAt;

  /// Seconds since the widget appeared, or [restAt] when holding still.
  double get t => _isStill ? restAt : _seconds;

  /// True when nothing may move: reduce motion, or a [PaywallStill] above.
  bool get isStill => _isStill;

  /// Called on every tick. Rebuilds by default. Override it to tell a
  /// listener instead and save the rebuild.
  @protected
  void onTick() => setState(() {});

  /// Starts the clock again from zero, to replay an entrance.
  void restart() {
    _banked = 0;
    _seconds = 0;
    if (_ticker.isActive) {
      _ticker.stop();
      unawaited(_ticker.start());
    }
    if (mounted) onTick();
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _seconds = _banked + elapsed.inMicroseconds / 1e6;
      onTick();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isStill =
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
        PaywallStill.of(context);
    _isOnTop = ModalRoute.of(context)?.isCurrent ?? true;
    final shouldRun = !_isStill && _isOnTop;
    // The ticker is stopped, not just ignored: a frame callback that does
    // nothing still wakes the engine every frame.
    if (!shouldRun && _ticker.isActive) {
      _banked = _seconds;
      _ticker.stop();
    } else if (shouldRun && !_ticker.isActive) {
      unawaited(_ticker.start());
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

/// The frame's own clock, as a layout reads it through its scope. Listen to
/// it with [PaywallClockBuilder] to redraw one part every frame without a
/// `State` of your own.
abstract interface class PaywallClock implements ValueListenable<double> {
  /// Seconds since the layout appeared, or its resting second when still.
  @override
  double get value;

  /// True when nothing may move.
  bool get isStill;

  /// Starts again from zero, to replay an entrance.
  void restart();
}

/// Rebuilds [builder] with the clock's seconds on every frame it runs.
class PaywallClockBuilder extends StatelessWidget {
  const PaywallClockBuilder({
    required this.clock,
    required this.builder,
    this.child,
    super.key,
  });

  final PaywallClock clock;
  final Widget Function(BuildContext context, double t, Widget? child) builder;

  /// A part that does not change with the clock, built once.
  final Widget? child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: clock,
    builder: builder,
    child: child,
  );
}
