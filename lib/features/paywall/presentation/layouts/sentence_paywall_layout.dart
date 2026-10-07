import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/features/paywall/presentation/layouts/sentence/sentence_composition.dart';
import 'package:flutter/material.dart';

/// One sentence. Under the kit's stage, the headline is a sentence in
/// display type whose underlined ending rolls like a counter to the
/// benefit on the stage: "Hosted gives you" and then each thing it gives.
///
/// The sentence carries the benefits, so there are no check lines. One
/// quiet row under it names every benefit, and a tap on a name puts that
/// benefit on the stage. A swipe across the stage or the sentence rolls to
/// the next ending or the one before.
///
/// The stage, the mascot, the loop and the hand are the kit's
/// (`kit/paywall_hero.dart`). A product with one benefit has no ending to
/// roll and draws the kit's own composition.
class SentencePaywallLayout extends StatelessWidget {
  const SentencePaywallLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return PaywallFrame(
      // The mascot stands in the top left, so the cross takes the right.
      closeOnLeft: false,
      restAt: heroEntranceSeconds,
      builder: (context, scope) => scope.benefits.length < 2
          ? HeroComposition(scope: scope)
          : SentenceComposition(scope: scope),
    );
  }
}
