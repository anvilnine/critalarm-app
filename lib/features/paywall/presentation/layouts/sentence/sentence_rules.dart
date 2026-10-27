import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_cues.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_motion.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_cue_rules.dart';
import 'package:critalarm/gen/locale_keys.g.dart';

// The sentence as rules: which ending each benefit gives it, which short
// name stands for it in the roster, and where the two endings are while
// one rolls the other out. No widget is in here, so every rule has a test.

/// The string key of the ending [id] gives the sentence. Each one finishes
/// the stem ("Hosted gives you", "Pro gives you") as a noun phrase, so the
/// sentence is grammatical whichever is showing.
String sentenceTailKeyFor(PaywallBenefitId id) => switch (id) {
  PaywallBenefitId.topics => LocaleKeys.paywall_sentence_tails_topics,
  PaywallBenefitId.pushes => LocaleKeys.paywall_sentence_tails_pushes,
  PaywallBenefitId.history => LocaleKeys.paywall_sentence_tails_history,
  PaywallBenefitId.appIcons => LocaleKeys.paywall_sentence_tails_app_icons,
  PaywallBenefitId.wakeUpChallenges =>
    LocaleKeys.paywall_sentence_tails_wake_up_challenges,
  PaywallBenefitId.widgets => LocaleKeys.paywall_sentence_tails_widgets,
  PaywallBenefitId.reliabilityChecks =>
    LocaleKeys.paywall_sentence_tails_reliability_checks,
  PaywallBenefitId.customSounds =>
    LocaleKeys.paywall_sentence_tails_custom_sounds,
  PaywallBenefitId.customAlarmScreens =>
    LocaleKeys.paywall_sentence_tails_custom_alarm_screens,
};

/// The string key of the one or two words that stand for [id] in the quiet
/// roster under the sentence.
String sentenceNameKeyFor(PaywallBenefitId id) => switch (id) {
  PaywallBenefitId.topics => LocaleKeys.paywall_sentence_names_topics,
  PaywallBenefitId.pushes => LocaleKeys.paywall_sentence_names_pushes,
  PaywallBenefitId.history => LocaleKeys.paywall_sentence_names_history,
  PaywallBenefitId.appIcons => LocaleKeys.paywall_sentence_names_app_icons,
  PaywallBenefitId.wakeUpChallenges =>
    LocaleKeys.paywall_sentence_names_wake_up_challenges,
  PaywallBenefitId.widgets => LocaleKeys.paywall_sentence_names_widgets,
  PaywallBenefitId.reliabilityChecks =>
    LocaleKeys.paywall_sentence_names_reliability_checks,
  PaywallBenefitId.customSounds =>
    LocaleKeys.paywall_sentence_names_custom_sounds,
  PaywallBenefitId.customAlarmScreens =>
    LocaleKeys.paywall_sentence_names_custom_alarm_screens,
};

/// Where the two endings are while one rolls the other out, as shares of
/// the height of the box they roll in. 0 is in place, 1 is one whole box
/// below, -1 one whole box above.
class SentenceRoll {
  const SentenceRoll({required this.arriving, required this.leaving});

  /// At rest: the ending in place and nothing on its way out.
  static const SentenceRoll rest = SentenceRoll(arriving: 0, leaving: null);

  /// The ending of the turn on the stage.
  final double arriving;

  /// The ending of the turn before it, or null when it has gone.
  final double? leaving;
}

/// The roll when the stage's new picture is [enter] of the way in, 0 to 1.
///
/// It reads the same number the stage does, so the ending and the picture
/// change in the same instant. Like a counter it rolls upwards: the old
/// ending leaves over the top and the new one comes up from below. A swipe
/// back ([direction] of -1) rolls the other way. [isChange] is false when
/// there is no ending on its way out, or it is the same one playing again:
/// then nothing rolls.
SentenceRoll sentenceRollAt({
  required double enter,
  required int direction,
  required bool isChange,
}) {
  if (!isChange || enter >= 1) return SentenceRoll.rest;
  final p = enter.clamp(0, 1).toDouble();
  final way = direction < 0 ? -1.0 : 1.0;
  return SentenceRoll(arriving: way * (1 - p), leaving: -way * p);
}

/// How the stage moves under the sentence: rays turn behind the mascot, it
/// comes in from the side it stands on, and it hops as each new ending
/// rolls in, so the word and the mascot land together.
const HeroMotion sentenceMotion = HeroMotion(
  atmosphere: HeroAtmosphereStyle.rays,
  entrance: HeroEntranceStyle.slide,
  idle: HeroIdleStyle.benefitHop,
);

/// How far into its entrance the layout starts when an intro has just
/// handed over, in seconds. The intro ends on the mascot, so the mascot is
/// already in its place and only the preview and the words are left to
/// arrive.
const double sentenceIntroHeadStart = 0.6;

/// The loop's `prelude` for a layout that does or does not follow an
/// intro: a head start is a prelude under zero.
double sentencePreludeFor({required bool followsIntro}) =>
    followsIntro ? -sentenceIntroHeadStart : 0;

/// When the first ending rolls into the sentence, in seconds since the
/// entrance began: after the stem has started up, so the sentence is read
/// in order.
const double sentenceFirstRollStart = 0.5;
const double sentenceFirstRollEnd = 0.9;

/// Where the first ending is at [seconds] of the entrance: it comes up
/// from one box below, as every ending after it does, and is in place
/// from [sentenceFirstRollEnd] on. `shown` is how solid it is.
({double arriving, double shown}) sentenceFirstRollAt(double seconds) {
  final p = phase(seconds, sentenceFirstRollStart, sentenceFirstRollEnd);
  return (arriving: 1 - AppCurves.easeOut.transform(p), shown: p);
}

/// What the entrance sounds like, by clock second, for a loop with
/// [prelude]: the mascot slides in and lands, then the first ending rolls
/// into the sentence.
List<PaywallCueBeat> sentenceCues({required double prelude}) => [
  heroLandingBeat(sentenceMotion.entrance, prelude: prelude),
  PaywallCueBeat(prelude + sentenceFirstRollStart, PaywallCue.roll),
];
