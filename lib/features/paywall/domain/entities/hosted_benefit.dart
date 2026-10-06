import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';

/// Hosted push allowance a day. The relay enforces it (`tier/caps.ts`); the
/// copy reads it through the `hosted_p4_daily` placeholder.
const int hostedP4Daily = 1000;

/// Hosted history window in days, read by the copy as `hosted_history_days`.
const int hostedHistoryDays = 90;

/// Where a benefit is written out.
enum HostedSurface {
  paywallStraight,
  paywallCompare,
  paywallOneJob,
  askSheet,
  endingNotice,
  endedNotice,
  proLaterReminder,
  homeDay0Card,
}

enum HostedBenefitId { topics, pushes, history, widgets, appIcons }

/// One thing Hosted gives, with the string keys each surface reads.
///
/// To move a benefit out of Hosted, delete its entry from
/// [HostedBenefit.all]. Every surface then drops it.
class HostedBenefit {
  const HostedBenefit({
    required this.id,
    required this.shortKey,
    required this.compareLabelKey,
    required this.compareFreeKey,
    required this.compareHostedKey,
    required this.loseKey,
    required this.phraseKey,
    this.hostedValue,
    this.freeValue,
  });

  final HostedBenefitId id;

  /// Hosted number, where the benefit has one. Null means "no limit" or not
  /// a number.
  final int? hostedValue;

  /// The matching free number, read from [AccountCaps.free].
  final int? freeValue;

  /// A full line for the paywall, the ask sheet and `one_job`.
  final String shortKey;

  /// Compare table: row label, free cell, Hosted cell.
  final String compareLabelKey;
  final String compareFreeKey;
  final String compareHostedKey;

  /// "What you lose" line for the ending and ended notices.
  final String loseKey;

  /// A short noun phrase for running text, such as the reminder body.
  final String phraseKey;

  static final List<HostedBenefit> all = List.unmodifiable([
    HostedBenefit(
      id: HostedBenefitId.topics,
      freeValue: AccountCaps.free.criticalTopics,
      shortKey: LocaleKeys.hosted_benefits_topics_short,
      compareLabelKey: LocaleKeys.hosted_benefits_topics_compare_label,
      compareFreeKey: LocaleKeys.hosted_benefits_topics_compare_free,
      compareHostedKey: LocaleKeys.hosted_benefits_topics_compare_hosted,
      loseKey: LocaleKeys.hosted_benefits_topics_lose,
      phraseKey: LocaleKeys.hosted_benefits_topics_phrase,
    ),
    HostedBenefit(
      id: HostedBenefitId.pushes,
      hostedValue: hostedP4Daily,
      freeValue: AccountCaps.free.p4Daily,
      shortKey: LocaleKeys.hosted_benefits_pushes_short,
      compareLabelKey: LocaleKeys.hosted_benefits_pushes_compare_label,
      compareFreeKey: LocaleKeys.hosted_benefits_pushes_compare_free,
      compareHostedKey: LocaleKeys.hosted_benefits_pushes_compare_hosted,
      loseKey: LocaleKeys.hosted_benefits_pushes_lose,
      phraseKey: LocaleKeys.hosted_benefits_pushes_phrase,
    ),
    HostedBenefit(
      id: HostedBenefitId.history,
      hostedValue: hostedHistoryDays,
      freeValue: AccountCaps.free.historyDays,
      shortKey: LocaleKeys.hosted_benefits_history_short,
      compareLabelKey: LocaleKeys.hosted_benefits_history_compare_label,
      compareFreeKey: LocaleKeys.hosted_benefits_history_compare_free,
      compareHostedKey: LocaleKeys.hosted_benefits_history_compare_hosted,
      loseKey: LocaleKeys.hosted_benefits_history_lose,
      phraseKey: LocaleKeys.hosted_benefits_history_phrase,
    ),
    const HostedBenefit(
      id: HostedBenefitId.widgets,
      shortKey: LocaleKeys.hosted_benefits_widgets_short,
      compareLabelKey: LocaleKeys.hosted_benefits_widgets_compare_label,
      compareFreeKey: LocaleKeys.hosted_benefits_widgets_compare_free,
      compareHostedKey: LocaleKeys.hosted_benefits_widgets_compare_hosted,
      loseKey: LocaleKeys.hosted_benefits_widgets_lose,
      phraseKey: LocaleKeys.hosted_benefits_widgets_phrase,
    ),
    const HostedBenefit(
      id: HostedBenefitId.appIcons,
      shortKey: LocaleKeys.hosted_benefits_app_icons_short,
      compareLabelKey: LocaleKeys.hosted_benefits_app_icons_compare_label,
      compareFreeKey: LocaleKeys.hosted_benefits_app_icons_compare_free,
      compareHostedKey: LocaleKeys.hosted_benefits_app_icons_compare_hosted,
      loseKey: LocaleKeys.hosted_benefits_app_icons_lose,
      phraseKey: LocaleKeys.hosted_benefits_app_icons_phrase,
    ),
  ]);

  /// Placeholders every benefit string may use. One map for every surface,
  /// so a number is edited in one place.
  static Map<String, String> get args => {
    'hosted_p4_daily': _thousands(hostedP4Daily),
    'hosted_history_days': '$hostedHistoryDays',
    'free_critical_topics': '${AccountCaps.free.criticalTopics}',
    'free_p4_daily': '${AccountCaps.free.p4Daily}',
    'free_history_days': '${AccountCaps.free.historyDays}',
  };

  /// The key this surface shows for this benefit, or null when the surface
  /// has no text for it.
  String? keyFor(HostedSurface surface) => switch (surface) {
    HostedSurface.paywallStraight ||
    HostedSurface.paywallOneJob ||
    HostedSurface.askSheet => shortKey,
    HostedSurface.paywallCompare => compareLabelKey,
    HostedSurface.endingNotice || HostedSurface.endedNotice => loseKey,
    HostedSurface.proLaterReminder || HostedSurface.homeDay0Card => phraseKey,
  };

  static String _thousands(int n) {
    final digits = '$n';
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return out.toString();
  }
}

/// Whether [surface] has text for [benefit]. Real only when the key is
/// present and the English string for it exists in [strings], a flat map of
/// dotted key to text.
bool hostedBenefitHasText(
  HostedBenefit benefit,
  HostedSurface surface,
  Map<String, String> strings,
) {
  final key = benefit.keyFor(surface);
  if (key == null) return false;
  final text = strings[key];
  return text != null && text.trim().isNotEmpty;
}

/// The text [surface] shows for each benefit, in list order.
List<String> hostedBenefitLines(HostedSurface surface) => [
  for (final b in HostedBenefit.all)
    if (b.keyFor(surface) case final key?)
      key.tr(namedArgs: HostedBenefit.args),
];

/// Joins benefit phrases into running text: one item "a", two "a and b",
/// three or more "a, b, c and d" (no comma before [and]). [and] is the
/// translated word, so this stays pure.
String joinBenefitPhrases(List<String> phrases, {required String and}) {
  if (phrases.length < 2) return phrases.join();
  final head = phrases.sublist(0, phrases.length - 1).join(', ');
  return '$head $and ${phrases.last}';
}

/// [hostedBenefitLines] for [surface] as one running-text list. Pass [only]
/// to name a subset of benefits, kept in list order.
String hostedBenefitSentence(
  HostedSurface surface, {
  Set<HostedBenefitId>? only,
}) => joinBenefitPhrases(
  [
    for (final b in HostedBenefit.all)
      if (only == null || only.contains(b.id))
        if (b.keyFor(surface) case final key?)
          key.tr(namedArgs: HostedBenefit.args),
  ],
  and: LocaleKeys.hosted_benefits_and.tr(),
);

/// A bulleted block of [hostedBenefitLines], one "• line" per row.
String hostedBenefitBullets(HostedSurface surface) =>
    hostedBenefitLines(surface).map((l) => '\u2022 $l').join('\n');
