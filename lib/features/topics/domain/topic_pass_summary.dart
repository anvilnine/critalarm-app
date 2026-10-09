import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/own_sound_rule.dart';
import 'package:critalarm/core/sound/sound_assignments.dart';
import 'package:critalarm/design/tokens/pass_tones.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/settings/domain/personalize/pass_summary.dart';
import 'package:critalarm/features/settings/domain/personalize/personalize_rules.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter/foundation.dart';

// What each card of the Topic screen's pass stack says, with nothing drawn.
// Pure, so it is unit tested and the widget only draws what it is handed.

/// One card of the stack.
@immutable
class TopicPassItem {
  const TopicPassItem({
    required this.pass,
    required this.value,
    required this.isOn,
    required this.feature,
    required this.hasTag,
  });

  final PassId pass;

  /// The words the card shows as its value, before they are translated.
  final PassValue value;

  /// Whether the setting is a saved choice, which decides the value colour.
  final bool isOn;

  /// The plan feature the card sells, or null when it sells none. The widget
  /// asks the access layer about it; nothing here reads a plan.
  final AppFeature? feature;

  /// Whether the card carries the plan word. True only for a feature that is
  /// locked while the plan is read, and only on a card that carries a tag.
  /// A tag never changes what a tap does.
  final bool hasTag;
}

/// The cards of the stack, in order.
@immutable
class TopicPassSummary {
  const TopicPassSummary({required this.cards, required this.sound});

  /// Look, Sound, Wake-up challenge and Tokens, or the first three on an
  /// example topic.
  final List<TopicPassItem> cards;

  /// The sound that rings for the topic, or null when none is known yet or
  /// its id names no sound on this phone. The Sound card's bars read its
  /// peaks.
  final AlarmSound? sound;

  TopicPassItem of(PassId pass) =>
      cards.firstWhere((card) => card.pass == pass);

  bool has(PassId pass) => cards.any((card) => card.pass == pass);
}

/// What the Topic screen's four cards show.
///
/// - [lookNameKey] is the name of the look that rings for this topic
///   (`AlarmStyleGate.styleFor(topic)`, so a locked plan's stand-in look),
///   and [lookIsStandard] says whether it is the standard one. A topic that
///   follows the phone reads the phone's look.
/// - The sound is the topic's own choice in [assignments], else the phone's
///   default, run through [OwnSoundRule] while [ownSoundsLocked] and then
///   found in the sound lists with [soundStripFor]. Until [assignments] are
///   read ([areSoundsLoaded] false) the value is empty rather than a guess.
/// - [challengeKind] is the challenge saved for the topic. While
///   [challengesLocked] the card says Off, because no challenge runs without
///   the plan, and the saved choice comes back with it.
/// - [isPlanRead] gates the plan tag: a plan that has not been read draws
///   none.
/// - [tokenCount] is how many tokens the topic has, or null until the list
///   has loaded, which draws an empty value.
/// - An [isExample] topic has no tokens on the server, so it has no Tokens
///   card.
TopicPassSummary topicPassSummaryFor({
  required String topic,
  required bool isExample,
  required String lookNameKey,
  required bool lookIsStandard,
  required bool areSoundsLoaded,
  required SoundAssignments? assignments,
  required List<AlarmSound> builtInSounds,
  required List<AlarmSound> userSounds,
  required List<AlarmSound> otherSounds,
  required bool ownSoundsLocked,
  required ChallengeKind? challengeKind,
  required bool challengesLocked,
  required bool isPlanRead,
  required int? tokenCount,
}) {
  final sound = _ringingSound(
    topic: topic,
    assignments: assignments,
    builtInSounds: builtInSounds,
    userSounds: userSounds,
    otherSounds: otherSounds,
    ownSoundsLocked: ownSoundsLocked,
  );
  final PassValue soundValue;
  if (!areSoundsLoaded) {
    soundValue = const PassValueText('');
  } else if (sound == null || sound.name.isEmpty) {
    soundValue = const PassValueKey(
      LocaleKeys.personalize_passes_root_sound_unknown,
    );
  } else {
    soundValue = PassValueText(sound.name);
  }
  final challenge = challengesLocked ? null : challengeKind;
  return TopicPassSummary(
    sound: sound,
    cards: [
      TopicPassItem(
        pass: PassId.look,
        value: PassValueKey(lookNameKey),
        isOn: !lookIsStandard,
        feature: AppFeature.alarmScreenStyles,
        hasTag: false,
      ),
      TopicPassItem(
        pass: PassId.sound,
        value: soundValue,
        isOn: true,
        feature: AppFeature.ownSounds,
        hasTag: false,
      ),
      TopicPassItem(
        pass: PassId.challenge,
        value: PassValueKey(
          challenge == null
              ? LocaleKeys.challenges_off
              : challengeNameKeyOf(challenge),
        ),
        isOn: challenge != null,
        feature: AppFeature.wakeUpChallenges,
        hasTag: challengesLocked && isPlanRead,
      ),
      if (!isExample)
        TopicPassItem(
          pass: PassId.tokens,
          value: PassValueText(tokenCount == null ? '' : '$tokenCount'),
          isOn: true,
          feature: null,
          hasTag: false,
        ),
    ],
  );
}

AlarmSound? _ringingSound({
  required String topic,
  required SoundAssignments? assignments,
  required List<AlarmSound> builtInSounds,
  required List<AlarmSound> userSounds,
  required List<AlarmSound> otherSounds,
  required bool ownSoundsLocked,
}) {
  if (assignments == null) return null;
  final ringingId = OwnSoundRule.ringingSoundId(
    saved: assignments,
    ownSoundsLocked: ownSoundsLocked,
    topicName: topic,
  );
  // The id that rings is already resolved, so the strip only has to find it.
  return soundStripFor(
    builtIn: builtInSounds,
    userSounds: userSounds,
    others: otherSounds,
    defaultId: ringingId,
    ownSoundsLocked: ownSoundsLocked,
  ).current;
}
