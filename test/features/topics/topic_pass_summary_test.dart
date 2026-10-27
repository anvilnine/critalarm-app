import 'package:critalarm/core/access/app_feature.dart';
import 'package:critalarm/core/sound/alarm_sound.dart';
import 'package:critalarm/core/sound/sound_assignments.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/settings/domain/personalize/pass_summary.dart';
import 'package:critalarm/features/topics/domain/topic_pass_summary.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';

AlarmSound _sound(String id, String name, AlarmSoundSource source) =>
    AlarmSound(
      id: id,
      name: name,
      source: source,
      path: '/sounds/$id',
      duration: const Duration(seconds: 3),
    );

final AlarmSound _classic = _sound(
  'classic_siren',
  'Classic siren',
  AlarmSoundSource.bundled,
);
final AlarmSound _piano = _sound('piano', 'Piano', AlarmSoundSource.bundled);
final AlarmSound _mine = _sound('user_1', 'My voice', AlarmSoundSource.user);

TopicPassSummary _summary({
  bool isExample = false,
  String lookNameKey = LocaleKeys.alarm_styles_standard,
  bool lookIsStandard = true,
  bool areSoundsLoaded = true,
  SoundAssignments? assignments,
  bool ownSoundsLocked = false,
  ChallengeKind? challengeKind,
  bool challengesLocked = false,
  bool isPlanRead = true,
  int? tokenCount,
}) => topicPassSummaryFor(
  topic: 'prod-db',
  isExample: isExample,
  lookNameKey: lookNameKey,
  lookIsStandard: lookIsStandard,
  areSoundsLoaded: areSoundsLoaded,
  assignments:
      assignments ?? const SoundAssignments(defaultSoundId: 'classic_siren'),
  builtInSounds: [_classic, _piano],
  userSounds: [_mine],
  otherSounds: const [],
  ownSoundsLocked: ownSoundsLocked,
  challengeKind: challengeKind,
  challengesLocked: challengesLocked,
  isPlanRead: isPlanRead,
  tokenCount: tokenCount,
);

void main() {
  test(
    'the cards come in the order Look, Sound, Wake-up challenge, Tokens',
    () {
      expect(_summary().cards.map((c) => c.pass), [
        PassId.look,
        PassId.sound,
        PassId.challenge,
        PassId.tokens,
      ]);
    },
  );

  group('look', () {
    test(
      'a topic that follows the phone reads the phone look, not a choice',
      () {
        final look = _summary().of(PassId.look);
        expect(
          look.value,
          const PassValueKey(LocaleKeys.alarm_styles_standard),
        );
        expect(look.isOn, isFalse);
      },
    );

    test('a topic with its own look says its name and counts as chosen', () {
      final look = _summary(
        lookNameKey: LocaleKeys.alarm_styles_terminal,
        lookIsStandard: false,
      ).of(PassId.look);
      expect(look.value, const PassValueKey(LocaleKeys.alarm_styles_terminal));
      expect(look.isOn, isTrue);
    });

    test('the look card sells the styles and never carries a tag', () {
      final look = _summary(
        lookNameKey: LocaleKeys.alarm_styles_terminal,
        lookIsStandard: false,
      ).of(PassId.look);
      expect(look.feature, AppFeature.alarmScreenStyles);
      expect(look.hasTag, isFalse);
    });

    test('a locked plan shows the stand-in look it was given', () {
      final look = _summary(
        challengesLocked: true,
      ).of(PassId.look);
      expect(look.value, const PassValueKey(LocaleKeys.alarm_styles_standard));
      expect(look.hasTag, isFalse);
    });
  });

  group('sound', () {
    test('the default sound rings for a topic with no choice of its own', () {
      final sound = _summary().of(PassId.sound);
      expect(sound.value, const PassValueText('Classic siren'));
      expect(_summary().sound, _classic);
    });

    test('the topic own sound wins over the default', () {
      final summary = _summary(
        assignments: const SoundAssignments(
          defaultSoundId: 'classic_siren',
          perTopic: {'prod-db': 'piano'},
        ),
      );
      expect(summary.of(PassId.sound).value, const PassValueText('Piano'));
      expect(summary.sound, _piano);
    });

    test('another topic choice does not leak in', () {
      final summary = _summary(
        assignments: const SoundAssignments(
          defaultSoundId: 'classic_siren',
          perTopic: {'other': 'piano'},
        ),
      );
      expect(summary.sound, _classic);
    });

    test('an own sound rings while own sounds are open', () {
      final summary = _summary(
        assignments: const SoundAssignments(
          defaultSoundId: 'classic_siren',
          perTopic: {'prod-db': 'user_1'},
        ),
      );
      expect(summary.of(PassId.sound).value, const PassValueText('My voice'));
    });

    test('a locked own sound shows the phone default standing in', () {
      final summary = _summary(
        ownSoundsLocked: true,
        assignments: const SoundAssignments(
          defaultSoundId: 'piano',
          perTopic: {'prod-db': 'user_1'},
        ),
      );
      expect(summary.of(PassId.sound).value, const PassValueText('Piano'));
    });

    test(
      'a locked own sound over an own default falls to the classic siren',
      () {
        final summary = _summary(
          ownSoundsLocked: true,
          assignments: const SoundAssignments(
            defaultSoundId: 'user_1',
            perTopic: {'prod-db': 'user_1'},
          ),
        );
        expect(
          summary.of(PassId.sound).value,
          const PassValueText('Classic siren'),
        );
      },
    );

    test('a locked plan keeps a bundled choice', () {
      final summary = _summary(
        ownSoundsLocked: true,
        assignments: const SoundAssignments(
          defaultSoundId: 'classic_siren',
          perTopic: {'prod-db': 'piano'},
        ),
      );
      expect(summary.of(PassId.sound).value, const PassValueText('Piano'));
    });

    test('a sound id the phone does not have reads as the default sound', () {
      final summary = _summary(
        assignments: const SoundAssignments(defaultSoundId: 'gone'),
      );
      expect(
        summary.of(PassId.sound).value,
        const PassValueKey(LocaleKeys.personalize_passes_root_sound_unknown),
      );
      expect(summary.sound, isNull);
    });

    test('before the sounds are read the value is empty, not a guess', () {
      expect(
        _summary(areSoundsLoaded: false).of(PassId.sound).value,
        const PassValueText(''),
      );
    });

    test('the sound card sells own sounds and carries no tag', () {
      final sound = _summary(ownSoundsLocked: true).of(PassId.sound);
      expect(sound.feature, AppFeature.ownSounds);
      expect(sound.hasTag, isFalse);
    });
  });

  group('wake-up challenge', () {
    test('no challenge reads Off and is not a saved choice', () {
      final challenge = _summary().of(PassId.challenge);
      expect(challenge.value, const PassValueKey(LocaleKeys.challenges_off));
      expect(challenge.isOn, isFalse);
      expect(challenge.hasTag, isFalse);
    });

    test('a challenge that is set says its name', () {
      final challenge = _summary(
        challengeKind: ChallengeKind.opsMath,
      ).of(PassId.challenge);
      expect(
        challenge.value,
        const PassValueKey(LocaleKeys.challenges_ops_math_name),
      );
      expect(challenge.isOn, isTrue);
    });

    test('locked challenges read Off even with a saved choice, and tag', () {
      final challenge = _summary(
        challengeKind: ChallengeKind.opsMath,
        challengesLocked: true,
      ).of(PassId.challenge);
      expect(challenge.value, const PassValueKey(LocaleKeys.challenges_off));
      expect(challenge.isOn, isFalse);
      expect(challenge.hasTag, isTrue);
      expect(challenge.feature, AppFeature.wakeUpChallenges);
    });

    test('a plan that is not read shows no tag', () {
      final challenge = _summary(
        challengesLocked: true,
        isPlanRead: false,
      ).of(PassId.challenge);
      expect(challenge.hasTag, isFalse);
    });
  });

  group('tokens', () {
    test('the value is empty until the list has loaded', () {
      expect(
        _summary().of(PassId.tokens).value,
        const PassValueText(''),
      );
    });

    test('the value is the count as text', () {
      expect(
        _summary(tokenCount: 1).of(PassId.tokens).value,
        const PassValueText('1'),
      );
      expect(
        _summary(tokenCount: 6).of(PassId.tokens).value,
        const PassValueText('6'),
      );
    });

    test('zero is a count, not an empty list that has not loaded', () {
      expect(
        _summary(tokenCount: 0).of(PassId.tokens).value,
        const PassValueText('0'),
      );
    });

    test('the card sells nothing and carries no tag', () {
      final tokens = _summary(tokenCount: 2).of(PassId.tokens);
      expect(tokens.feature, isNull);
      expect(tokens.hasTag, isFalse);
    });

    test('an example topic has the first three cards only', () {
      final summary = _summary(isExample: true, tokenCount: 2);
      expect(summary.cards.map((c) => c.pass), [
        PassId.look,
        PassId.sound,
        PassId.challenge,
      ]);
      expect(summary.has(PassId.tokens), isFalse);
    });
  });
}
