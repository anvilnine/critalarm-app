import 'dart:math' as math;

import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_outro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks_rules.dart';
import 'package:flutter/painting.dart';

// The rules of the success outro that need no widget, so each one has a
// test. `paywall_outro.dart` has the contract and `paywall_thanks.dart`
// the host that plays it.

/// The second the end state's own clock reads when the host's clock reads
/// [t].
///
/// The end state is built at [PaywallOutro.uncover], and until then it
/// reads [pickUp], so a caller never gets a second before it. From there it
/// runs at the host's pace, [pickUp] seconds ahead of the outro's own
/// clock.
double paywallThanksSecondAfterOutro(
  double t, {
  required PaywallOutro outro,
  required double pickUp,
}) => t < outro.uncover ? pickUp : pickUp + (t - outro.uncover);

/// The second the end state's mascot takes over from the outro's: the end
/// state draws none before it. It is the end state's own second at the
/// swap, and the second `PaywallThanks.mascotAt` is asked about.
double paywallThanksMascotFrom({
  required PaywallOutro outro,
  required double pickUp,
}) => pickUp + outro.seconds - outro.uncover;

/// The host's second at which the end state rests, when it plays after
/// [outro]: its own length [thanksSeconds] less what it already played
/// before it was picked up. Never before the swap, so a tap lands on a
/// frame with the outro gone and the mascot drawn.
double paywallThanksRestAfterOutro({
  required PaywallOutro outro,
  required double pickUp,
  required double thanksSeconds,
}) => math.max(outro.seconds, thanksSeconds - pickUp + outro.uncover);

/// The beats of an end state, as the host's clock hears them after
/// [outro]: later by what the outro took, and none that were over before
/// it was picked up. A beat that is heard and would land inside the
/// purchase cue is dropped, as the cue owns that time.
List<PaywallThanksBeat> paywallThanksBeatsAfterOutro(
  List<PaywallThanksBeat> beats, {
  required PaywallOutro outro,
  required double pickUp,
}) => [
  for (final beat in beats)
    if (beat.at >= pickUp)
      if (!beat.isHeard ||
          beat.at - pickUp + outro.uncover >= paywallBoughtCueSeconds)
        if (beat.cue case final cue?)
          PaywallThanksBeat(beat.at - pickUp + outro.uncover, cue)
        else
          PaywallThanksBeat.tap(beat.at - pickUp + outro.uncover, beat.haptic),
];

/// Whether an outro plays for this purchase.
///
/// Only a confirmed purchase gets one ([kind] is `purchase`), and only
/// when motion is allowed ([isStill] false), this build has the outro and
/// a thanks is set to hand over to. A restore, a product already held, a
/// reduce-motion phone and a still all go straight to what they do
/// without an outro.
bool paywallOutroPlays({
  required PaywallThanksKind? kind,
  required bool isStill,
  required bool isOutroBuilt,
  required bool isThanksBuilt,
}) =>
    kind == PaywallThanksKind.purchase &&
    !isStill &&
    isOutroBuilt &&
    isThanksBuilt;

/// How much larger than the mascot's box the patch is, and how round.
const double paywallOutroPatchGrowth = 1.06;
const double paywallOutroPatchRound = 0.74;

/// The rounded box that hides the layout's own mascot in the picture the
/// outro starts from. It is painted in the colour of one pixel beside the
/// mascot, so the one the outro draws is the only one.
RRect paywallOutroPatch(Rect mascot) => RRect.fromRectAndRadius(
  Rect.fromCenter(
    center: mascot.center,
    width: mascot.width * paywallOutroPatchGrowth,
    height: mascot.height * paywallOutroPatchGrowth,
  ),
  Radius.circular(mascot.width * paywallOutroPatchRound),
);

/// How far left of the mascot's box the patch's colour is read, in points.
const double paywallOutroSampleGap = 7;

/// Where the patch's colour is read from: [paywallOutroSampleGap] points
/// left of [mascot], at its mid height, kept inside a screen that starts
/// at zero.
Offset paywallOutroSamplePoint(Rect mascot) => Offset(
  (mascot.left - paywallOutroSampleGap).clamp(1.0, double.infinity),
  mascot.center.dy,
);
