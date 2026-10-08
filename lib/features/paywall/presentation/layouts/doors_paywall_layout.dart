import 'package:critalarm/features/paywall/presentation/layouts/doors/doors_composition.dart';
import 'package:critalarm/features/paywall/presentation/layouts/doors/doors_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// One open door on the app's own canvas. The doorway is full of light
/// with rays turning in it, the benefit playing stands in it, and the
/// mascot is in front, holding the door.
///
/// The door stands shut on the first frame. It gives a little, then
/// swings open on its hinge while the mascot looks up over the foot of
/// the stage and comes all the way. From there it is the Hero composition
/// around a doorway: the previews take turns in it, each one turning over
/// like a door, and the door itself opens a step wider for each benefit.
/// The stage, the lines and the pips answer the hand as they do there.
///
/// Every part but the door is the kit's (`kit/paywall_hero.dart`). On a
/// stage too small for a doorway the door is left out and the approved
/// stage is drawn. A product with one benefit draws the kit's own
/// composition.
class DoorsPaywallLayout extends StatelessWidget {
  const DoorsPaywallLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return PaywallFrame(
      // The door opens to the left, so the cross takes the right.
      closeOnLeft: false,
      restAt: DoorsTimeline.restAt,
      builder: (context, scope) {
        final headline = switch (doorsHeadlineFor(
          isHosted: scope.isHosted,
          source: scope.source,
        )) {
          DoorsHeadline.hosted => LocaleKeys.paywall_doors_headline_hosted,
          DoorsHeadline.pro => LocaleKeys.paywall_doors_headline_pro,
          DoorsHeadline.keepOpen => LocaleKeys.paywall_doors_headline_ending,
          DoorsHeadline.openAgain => LocaleKeys.paywall_doors_headline_ended,
        }.tr();
        return scope.benefits.length < 2
            ? HeroComposition(
                scope: scope,
                headline: headline,
                motion: doorsMotion,
              )
            : DoorsComposition(scope: scope, headline: headline);
      },
    );
  }
}
