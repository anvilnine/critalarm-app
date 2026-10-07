import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/features/paywall/presentation/layouts/wipe/wipe_composition.dart';
import 'package:critalarm/features/paywall/presentation/layouts/wipe/wipe_rules.dart';
import 'package:flutter/material.dart';

/// Before and after. The stage is one scene drawn twice and split by a
/// divider: Free on the left with the colour taken out and the mascot
/// doubtful, the product on the right, playing. The mascot stands on the
/// line, so one half of its face is each.
///
/// The screen opens all Free, then the divider sweeps in from the right
/// with the colour behind it and settles on the mascot. A sideways drag
/// moves it to compare. A benefit is chosen by a tap on its line, and a
/// tap on the stage plays the current one again.
///
/// The stage, the mascot, the loop, the lines and the hand are the kit's
/// (`kit/paywall_hero.dart`). A product with one benefit draws the kit's
/// own composition.
class WipePaywallLayout extends StatelessWidget {
  const WipePaywallLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return PaywallFrame(
      // Free takes the left of the stage, so the cross takes the right.
      closeOnLeft: false,
      restAt: wipeRestSeconds,
      builder: (context, scope) => scope.benefits.length < 2
          ? HeroComposition(scope: scope)
          : WipeComposition(scope: scope),
    );
  }
}
