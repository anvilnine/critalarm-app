import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:flutter/widgets.dart';

/// How one part of the Proof layout comes on screen.
enum ProofEntranceKind {
  /// Fades in while settling down a few points. For words.
  rise,

  /// Slides in from the right while growing to size. For cards.
  fromRight,

  /// Grows from small with a little overshoot. For tiles.
  pop,
}

/// Brings [child] in once, starting [at] seconds on the clock. After the
/// entrance, and on a still clock, it draws [child] exactly as it is.
class ProofEntrance extends StatelessWidget {
  const ProofEntrance({
    required this.clock,
    required this.at,
    required this.child,
    this.kind = ProofEntranceKind.rise,
    this.seconds = 0.55,
    super.key,
  });

  final PaywallClock clock;
  final double at;
  final ProofEntranceKind kind;
  final double seconds;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PaywallClockBuilder(
      clock: clock,
      child: child,
      builder: (context, t, child) {
        final linear = phase(t, at, at + seconds);
        if (linear >= 1) return child!;
        final eased = AppCurves.easeOut.transform(linear);
        final fade = phase(t, at, at + seconds * 0.5);

        final Widget moved = switch (kind) {
          ProofEntranceKind.rise => Transform.translate(
            offset: Offset(0, -8 * (1 - eased)),
            child: child,
          ),
          ProofEntranceKind.fromRight => Transform.translate(
            offset: Offset(24 * (1 - eased), 0),
            child: Transform.scale(scale: 0.86 + 0.14 * eased, child: child),
          ),
          ProofEntranceKind.pop => Transform.scale(
            scale: 0.6 + 0.4 * AppCurves.easeSpring.transform(linear),
            child: child,
          ),
        };
        return Opacity(opacity: fade, child: moved);
      },
    );
  }
}
