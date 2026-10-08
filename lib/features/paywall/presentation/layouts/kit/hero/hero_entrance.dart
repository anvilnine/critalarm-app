import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:flutter/widgets.dart';

// The approved entrance, about a second long. The mascot pops up with a
// back-out and the card follows it in from the side (both read
// `HeroFrame.entrance`, or the `entrance` of a mascot drawn alone). The
// disc grows and the shapes drift in from further out (the atmosphere's
// `entrance`). The words rise into place one after another ([HeroRise]).
//
// A layout that plays a beat of its own first gives its length to the
// loop as `prelude`. Everything above then starts when that beat ends,
// and `HeroLoop.entranceEnd` is the frame's `restAt`.

/// How far through the entrance the clock is at [t], 0 to 1, for a part
/// drawn outside a loop. [after] is the length of a layout's own beat
/// before it.
double heroEntranceAt(double t, {double after = 0}) =>
    phase(t - after, 0, heroEntranceSeconds);

/// Brings one part of the words up into place during the entrance, each a
/// little after the one above it: [index] 0 goes first.
///
/// Wrap a headline, a line, a price, anything that is type. When nothing
/// may move it draws its child in place. [after] is the length of a
/// layout's own beat before the entrance (`HeroLoop.prelude`).
class HeroRise extends StatelessWidget {
  const HeroRise({
    required this.clock,
    required this.index,
    required this.child,
    this.after = 0,
    super.key,
  });

  final PaywallClock clock;
  final int index;
  final Widget child;
  final double after;

  @override
  Widget build(BuildContext context) => PaywallClockBuilder(
    clock: clock,
    builder: (context, t, child) {
      final p = AppCurves.easeOut.transform(
        phase(stagger(index, t - after, each: 0.06, start: 0.3), 0, 0.36),
      );
      return Opacity(
        opacity: p,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - p)),
          child: child,
        ),
      );
    },
    child: child,
  );
}
