import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:flutter/material.dart';

/// The mascot on a stage, reacting to one benefit playing large beside it,
/// over a headline and the benefits as plain lines.
///
/// The stage is the one thing that moves. It takes every point of height
/// the words under it do not need, so the screen is full on any phone. The
/// line of the benefit playing is the strong one in the list.
///
/// It answers the hand. A swipe across the stage goes to the next benefit
/// or the previous one, a tap on a line puts that benefit on the stage,
/// and a tap on the stage plays the current one again. The chosen benefit
/// plays its turn, holds for a moment, and the loop goes on from there.
/// While a finger is down on the stage the loop waits.
///
/// Every part is the kit's (`kit/paywall_hero.dart`), put together by
/// [HeroComposition]. An id with no layout of its own draws this one.
class HeroPaywallLayout extends StatelessWidget {
  const HeroPaywallLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return PaywallFrame(
      // The mascot stands in the top left, so the cross takes the right.
      closeOnLeft: false,
      restAt: heroEntranceSeconds,
      builder: (context, scope) => HeroComposition(scope: scope),
    );
  }
}
