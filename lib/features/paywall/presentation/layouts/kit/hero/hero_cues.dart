import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_motion.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_turns.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_cue_rules.dart';

// What the approved entrance sounds like: the mascot lands, the card
// slides in. The seconds are read off the entrance's own curves.

/// How far through the entrance the mascot first stands at its full size
/// in its place, 0 to 1: the moment it lands, before it settles.
///
/// A pop and a slide go past their place and come back, and pass it 38
/// percent of the way through their move. A drop first touches a little
/// over a third of the way through its fall. A peek lands at the end of
/// its second move.
double heroLandsAt(HeroEntranceStyle style) => switch (style) {
  HeroEntranceStyle.pop || HeroEntranceStyle.slide => 0.08 + 0.52 * 0.38,
  HeroEntranceStyle.drop => 0.08 + 0.62 / 2.75,
  HeroEntranceStyle.peek => 0.46 + 0.3 * 0.38,
};

/// The cue of a mascot landing in [style]: a drop bounces, the rest pop.
PaywallCue heroLandingCue(HeroEntranceStyle style) =>
    style == HeroEntranceStyle.drop ? PaywallCue.drop : PaywallCue.pop;

/// How far through the entrance the card starts in from the side.
const double heroCardStartsAt = 0.42;

/// The clock second the mascot lands, after a layout's own [prelude].
double heroLandingSecond(HeroEntranceStyle style, {double prelude = 0}) =>
    prelude + heroLandsAt(style) * heroEntranceSeconds;

/// The mascot's landing as a beat, after a layout's own [prelude].
PaywallCueBeat heroLandingBeat(
  HeroEntranceStyle style, {
  double prelude = 0,
}) => PaywallCueBeat(
  heroLandingSecond(style, prelude: prelude),
  heroLandingCue(style),
);

/// The beats of the approved entrance, in order, after a layout's own
/// [prelude]: the mascot lands, and with [cardSlides] the card comes in
/// from the side.
List<PaywallCueBeat> heroEntranceCues(
  HeroMotion motion, {
  double prelude = 0,
  bool cardSlides = true,
}) {
  final beats = [
    heroLandingBeat(motion.entrance, prelude: prelude),
    if (cardSlides)
      PaywallCueBeat(
        prelude + heroCardStartsAt * heroEntranceSeconds,
        PaywallCue.whoosh,
      ),
  ]..sort((a, b) => a.at.compareTo(b.at));
  return beats;
}
