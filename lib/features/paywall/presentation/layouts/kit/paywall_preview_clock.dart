import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:flutter/widgets.dart';

// The one clock every preview reads. A preview says which second it rests
// on and how to turn a second into a frame, and draws that frame.

/// The second a preview draws.
///
/// - [isStill]: nothing may move, so it is [restAt].
/// - No [playFrom]: the preview follows [clock] as it is.
/// - With [playFrom]: the preview's own part starts when [clock] reaches
///   that second. [turnStart] is where that part begins in the preview's
///   loop, zero unless the preview shares a loop and waits for a turn in
///   it. Until then it holds the first frame of its part.
double paywallPreviewSecond({
  required double clock,
  required bool isStill,
  required double restAt,
  double? playFrom,
  double turnStart = 0,
}) {
  if (isStill) return restAt;
  if (playFrom == null) return clock;
  return turnStart + (clock < playFrom ? 0 : clock - playFrom);
}

/// Tells the preview under it when to play. `PaywallPreview` puts it there
/// from its `playFrom`, and [PaywallPreviewClock] reads it.
class PaywallPreviewPlay extends InheritedWidget {
  const PaywallPreviewPlay({
    required this.playFrom,
    required super.child,
    super.key,
  });

  /// The clock second the preview's own part starts at. Null follows the
  /// clock as it is.
  final double? playFrom;

  static double? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PaywallPreviewPlay>()
      ?.playFrom;

  @override
  bool updateShouldNotify(PaywallPreviewPlay oldWidget) =>
      playFrom != oldWidget.playFrom;
}

/// Rebuilds [builder] with the frame [frameAt] gives for the clock.
///
/// The clock is the layout's when a paywall frame is above, so every
/// preview on a screen keeps one time, and the widget's own when there is
/// none (the gallery). With reduce motion on, or under a `PaywallStill`,
/// the frame is the one at [restAt], whatever second the layout rests on,
/// and no ticker of its own runs.
///
/// A frame equal to the last one is not redrawn, so a preview whose frames
/// compare equal costs nothing while it rests. A preview that draws
/// straight from the second uses [PaywallPreviewClock.seconds].
class PaywallPreviewClock<F> extends StatelessWidget {
  const PaywallPreviewClock({
    required this.restAt,
    required this.frameAt,
    required this.builder,
    this.turnStart = 0,
    super.key,
  });

  /// Hands [builder] the second itself.
  static PaywallPreviewClock<double> seconds({
    required double restAt,
    required Widget Function(BuildContext context, double t) builder,
    Key? key,
  }) => PaywallPreviewClock<double>(
    key: key,
    restAt: restAt,
    frameAt: _second,
    builder: builder,
  );

  static double _second(double t) => t;

  /// The second the preview rests on when nothing may move.
  final double restAt;

  /// Where this preview's own part starts in its loop. Only read when the
  /// preview was given a `playFrom`.
  final double turnStart;

  /// The frame at a second. Pure.
  final F Function(double t) frameAt;

  final Widget Function(BuildContext context, F frame) builder;

  @override
  Widget build(BuildContext context) {
    final clock = PaywallLayoutScope.maybeOf(context)?.clock;
    final playFrom = PaywallPreviewPlay.of(context);
    return clock == null
        ? _OwnClock<F>(preview: this, playFrom: playFrom)
        : _LayoutClock<F>(preview: this, clock: clock, playFrom: playFrom);
  }

  F _frame({required double clock, required bool isStill, double? playFrom}) =>
      frameAt(
        paywallPreviewSecond(
          clock: clock,
          isStill: isStill,
          restAt: restAt,
          playFrom: playFrom,
          turnStart: turnStart,
        ),
      );
}

class _LayoutClock<F> extends StatefulWidget {
  const _LayoutClock({
    required this.preview,
    required this.clock,
    required this.playFrom,
  });

  final PaywallPreviewClock<F> preview;
  final PaywallClock clock;
  final double? playFrom;

  @override
  State<_LayoutClock<F>> createState() => _LayoutClockState<F>();
}

class _LayoutClockState<F> extends State<_LayoutClock<F>> {
  bool _isStill = false;
  late F _frame;

  F _read() => widget.preview._frame(
    clock: widget.clock.value,
    isStill: _isStill || widget.clock.isStill,
    playFrom: widget.playFrom,
  );

  void _onTick() {
    final next = _read();
    if (next == _frame) return;
    setState(() => _frame = next);
  }

  @override
  void initState() {
    super.initState();
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
  Widget build(BuildContext context) => widget.preview.builder(context, _frame);
}

class _OwnClock<F> extends StatefulWidget {
  const _OwnClock({required this.preview, required this.playFrom});

  final PaywallPreviewClock<F> preview;
  final double? playFrom;

  @override
  State<_OwnClock<F>> createState() => _OwnClockState<F>();
}

class _OwnClockState<F> extends PaywallClockState<_OwnClock<F>> {
  F? _frame;

  @override
  double get restAt => widget.preview.restAt;

  F _read() => widget.preview._frame(
    clock: t,
    isStill: isStill,
    playFrom: widget.playFrom,
  );

  @override
  void onTick() {
    final next = _read();
    if (next == _frame) return;
    setState(() => _frame = next);
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frame = _read();
    return widget.preview.builder(context, frame);
  }
}
