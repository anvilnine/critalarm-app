import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/features/paywall/presentation/layouts/reel/reel_scene.dart';
import 'package:flutter/material.dart';

/// Stories. One scene per benefit fills everything above the buy block:
/// its own tone, one headline in display type, the mascot reacting and the
/// benefit's preview playing large. Story bars along the top say how many
/// scenes there are and fill as each one plays.
///
/// It shows one benefit at a time on purpose, so there is no list. A tap
/// on the right half goes on, a tap on the left goes back, a swipe does
/// the same, and a finger held down pauses the reel.
///
/// The pages push one another out, as stories do. The mascot comes in
/// from the side, as the pages do, and hops as each new page lands.
///
/// The stage, the mascot, the loop and the hand are the kit's
/// (`kit/paywall_hero.dart`). A product with one benefit has nothing to
/// page through and draws the kit's own composition.
class ReelPaywallLayout extends StatefulWidget {
  const ReelPaywallLayout({super.key});

  @override
  State<ReelPaywallLayout> createState() => _ReelPaywallLayoutState();
}

class _ReelPaywallLayoutState extends State<ReelPaywallLayout> {
  // The scenes change ground, and the frame's cross changes ink with them.
  final PaywallFrameController _frame = PaywallFrameController();

  @override
  void dispose() {
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PaywallFrame(
      controller: _frame,
      // The story bars start at the left, so the cross takes the right.
      closeOnLeft: false,
      restAt: heroEntranceSeconds,
      builder: (context, scope) => scope.benefits.length < 2
          ? HeroComposition(scope: scope)
          : ReelComposition(scope: scope, closeInk: _frame.closeInk),
    );
  }
}
