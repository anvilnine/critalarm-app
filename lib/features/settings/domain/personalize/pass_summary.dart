import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/app_icon/app_icon.dart';
import 'package:critalarm/design/tokens/pass_tones.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter/foundation.dart';

// What each card of the Personalize root says, with nothing drawn. Pure, so it
// is unit tested and the screen only draws what it is handed.

/// The words a card shows as its value, before they are translated.
@immutable
sealed class PassValue {
  const PassValue();
}

/// A value that is a translation key.
final class PassValueKey extends PassValue {
  const PassValueKey(this.key);

  final String key;

  @override
  bool operator ==(Object other) => other is PassValueKey && other.key == key;

  @override
  int get hashCode => Object.hash(PassValueKey, key);

  @override
  String toString() => 'PassValueKey($key)';
}

/// A value that is already words, such as the name of a sound.
final class PassValueText extends PassValue {
  const PassValueText(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      other is PassValueText && other.text == text;

  @override
  int get hashCode => Object.hash(PassValueText, text);

  @override
  String toString() => 'PassValueText($text)';
}

/// One card of the root.
@immutable
class PassSummary {
  const PassSummary({
    required this.pass,
    required this.exists,
    required this.value,
    required this.isOn,
    required this.feature,
    required this.showsTag,
  });

  final PassId pass;

  /// Whether the phone has this pass at all. Widgets are absent where there
  /// are no home screen widgets, and App icon where the platform cannot
  /// change its icon.
  final bool exists;

  final PassValue value;

  /// Whether the setting is a saved choice, which decides the value colour.
  /// A challenge that is Off is not.
  final bool isOn;

  /// The plan feature the pass sells. The screen asks the access layer about
  /// it; nothing here reads a plan.
  final AppFeature feature;

  /// Whether the card carries the plan word while the feature is locked and
  /// the plan is read. Look and Sound do not: they are about what the person
  /// already has.
  final bool showsTag;
}

/// The five cards, in stack order, with those the phone lacks marked.
@immutable
class PersonalizeSummary {
  const PersonalizeSummary(this.passes);

  final List<PassSummary> passes;

  /// The cards the stack draws, in order.
  List<PassSummary> get present => [
    for (final pass in passes)
      if (pass.exists) pass,
  ];

  PassSummary of(PassId id) => passes.firstWhere((pass) => pass.pass == id);
}

/// The `LocaleKeys` key of a challenge's name.
String challengeNameKeyOf(ChallengeKind kind) => switch (kind) {
  ChallengeKind.typeTopicName => LocaleKeys.challenges_type_topic_name_name,
  ChallengeKind.typeAlertTitle => LocaleKeys.challenges_type_alert_title_name,
  ChallengeKind.opsMath => LocaleKeys.challenges_ops_math_name,
  ChallengeKind.scratchCard => LocaleKeys.challenges_scratch_card_name,
  ChallengeKind.shake => LocaleKeys.challenges_shake_name,
};

/// The `LocaleKeys` key of an app icon's name.
String appIconNameKeyOf(AppIcon icon) => switch (icon) {
  AppIcon.standard => LocaleKeys.settings_app_icon_default,
  AppIcon.crowned => LocaleKeys.settings_app_icon_crowned,
  AppIcon.shades => LocaleKeys.settings_app_icon_shades,
  AppIcon.shadesCrown => LocaleKeys.settings_app_icon_shades_crown,
};

/// What the Personalize root shows on each card.
///
/// - [lookNameKey] is the name of the look that rings now, and
///   [lookIsStandard] says whether it is the standard one.
/// - [soundName] is the name of the sound that rings now. The caller reads
///   it from the sound strip, which gives the sound standing in for an own
///   sound while own sounds are locked. Null when the sound's id names no
///   sound on this phone, or before it is loaded.
/// - [challengeKind] is the saved default for new topics. While challenges
///   are [challengesLocked] the card says Off, because no challenge runs
///   without the plan, and the saved choice comes back with it.
/// - [hasWidgets] is whether this phone has home screen widgets.
/// - [appIcon] is the icon showing now, or null where the platform cannot
///   change its icon.
PersonalizeSummary personalizeSummaryFor({
  required String lookNameKey,
  required bool lookIsStandard,
  required String? soundName,
  required ChallengeKind? challengeKind,
  required bool challengesLocked,
  required bool hasWidgets,
  required AppIcon? appIcon,
}) {
  final challenge = challengesLocked ? null : challengeKind;
  return PersonalizeSummary([
    PassSummary(
      pass: PassId.look,
      exists: true,
      value: PassValueKey(lookNameKey),
      isOn: !lookIsStandard,
      feature: AppFeature.alarmScreenStyles,
      showsTag: false,
    ),
    PassSummary(
      pass: PassId.sound,
      exists: true,
      value: soundName == null || soundName.isEmpty
          ? const PassValueKey(LocaleKeys.personalize_passes_root_sound_unknown)
          : PassValueText(soundName),
      isOn: true,
      feature: AppFeature.ownSounds,
      showsTag: false,
    ),
    PassSummary(
      pass: PassId.challenge,
      exists: true,
      value: PassValueKey(
        challenge == null
            ? LocaleKeys.challenges_off
            : challengeNameKeyOf(challenge),
      ),
      isOn: challenge != null,
      feature: AppFeature.wakeUpChallenges,
      showsTag: true,
    ),
    PassSummary(
      pass: PassId.widgets,
      exists: hasWidgets,
      value: const PassValueKey(
        LocaleKeys.personalize_passes_root_widgets_value,
      ),
      isOn: true,
      feature: AppFeature.widgets,
      showsTag: true,
    ),
    PassSummary(
      pass: PassId.appIcon,
      exists: appIcon != null,
      value: PassValueKey(
        appIconNameKeyOf(appIcon ?? AppIcon.standard),
      ),
      isOn: appIcon != null && appIcon != AppIcon.standard,
      feature: AppFeature.appIcons,
      showsTag: true,
    ),
  ]);
}
