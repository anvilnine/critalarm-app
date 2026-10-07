import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
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
