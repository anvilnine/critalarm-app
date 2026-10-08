import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/features/paywall/presentation/layouts/receipt/receipt_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/receipt/receipt_stage.dart';
import 'package:flutter/material.dart';

/// A printed slip of what you get.
///
/// The stage is a printer slot with a paper receipt hanging from it and
/// the mascot large beside it. In the entrance the slip prints out a line
/// at a time: one ticked line per benefit in the mono face, a dashed rule,
/// then the product's name and the price of the plan picked as the total.
/// The mascot nods at each line and is glad at the total. A rubber stamp
/// with the product's name lands at the end, at a slight angle, and
/// startles the mascot into a hop. That printed, stamped slip is the
/// resting frame.
///
/// The slip is the benefit list, so nothing is listed under it. A tap on
/// one of its lines makes the mascot react to that benefit and brings its
/// preview out from behind the paper, to stand whole beside it under the
/// mascot. A swipe across the stage does the same for the next or the
/// previous line.
///
/// The mascot, the loop, the hand, the pips and the air are the kit's
/// (`kit/paywall_hero.dart`). A product with one benefit has no list to
/// print and draws the kit's own composition.
class ReceiptPaywallLayout extends StatelessWidget {
  const ReceiptPaywallLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return PaywallFrame(
      // The slot and the paper hang on the left, so the cross takes the
      // right.
      closeOnLeft: false,
      entranceCue: PaywallEntranceCue.print,
      restAt: ReceiptTimeline.restAt,
      builder: (context, scope) => scope.benefits.length < 2
          ? HeroComposition(scope: scope)
          : ReceiptComposition(scope: scope),
    );
  }
}
