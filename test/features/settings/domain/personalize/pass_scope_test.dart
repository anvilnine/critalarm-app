import 'dart:async';

import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/lock_tap_rule.dart';
import 'package:critalarm/design/tokens/pass_tones.dart';
import 'package:critalarm/features/challenges/domain/challenge_choices.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_assignments.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_choices.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_id.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_rule.dart';
import 'package:critalarm/features/settings/domain/personalize/challenge_shelf_rules.dart';
import 'package:critalarm/features/settings/domain/personalize/pass_scope.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Looks extends Mock implements AlarmStyleChoices {}

class _Challenges extends Mock implements ChallengeChoices {}

const _open = FeatureDecision.open();
const _locked = FeatureDecision.locked(Holding.pro);

const _topic = TopicScope('Uptime Kuma');

/// The look `alarmStyleFor` draws for `scope`.
AlarmStyleId _inUse(
  AlarmStyleAssignments saved,
  PassScope scope, {
  FeatureDecision decision = _open,
  bool isPlanRead = true,
  bool isOwnLookReady = false,
}) => alarmStyleFor(
  saved: saved,
  topicName: scope.topic,
  decision: decision,
  isPlanRead: isPlanRead,
  wasOpenWhenLastSure: false,
  isOwnLookReady: isOwnLookReady,
);

void main() {
  late _Looks looks;
  late _Challenges challenges;

  setUp(() {
    looks = _Looks();
    challenges = _Challenges();
    when(() => looks.setDefault(any())).thenAnswer((_) async {});
    when(() => looks.setTopicStyle(any(), any())).thenAnswer((_) async {});
    when(() => challenges.setChoice(any(), any())).thenAnswer((_) async {});
    when(
      () => challenges.setDefaultForNewTopics(any()),
    ).thenAnswer((_) async {});
  });

  group('passScopeFromQuery', () {
    test('a missing topic is the whole phone', () {
      expect(passScopeFromQuery(null), const EverywhereScope());
      expect(passScopeFromQuery(null).isTopic, isFalse);
      expect(passScopeFromQuery(null).topic, isNull);
    });

    test('an empty topic is the whole phone', () {
      expect(passScopeFromQuery(''), const EverywhereScope());
    });

    test('a name is a topic scope', () {
      final scope = passScopeFromQuery('backups');
      expect(scope, const TopicScope('backups'));
      expect(scope.isTopic, isTrue);
      expect(scope.topic, 'backups');
    });

    test('a name keeps its spaces and case', () {
      expect(passScopeFromQuery(' Prod DB ').topic, ' Prod DB ');
    });

    test('a name that needed encoding comes back as it was', () {
      const name = 'ops & dev/prod? 100%';
      final location = passLocationFor('/look', const TopicScope(name));
      expect(location, startsWith('/look?topic='));
      expect(location, isNot(contains(' ')));
      final read = Uri.parse(location).queryParameters['topic'];
      expect(read, name);
      expect(passScopeFromQuery(read), const TopicScope(name));
    });

    test('the whole phone has no query', () {
      expect(passLocationFor('/look', const EverywhereScope()), '/look');
      expect(
        passLocationFor('/challenge', const TopicScope('a')),
        '/challenge?topic=a',
      );
    });
  });

  group('passLabelFor', () {
    test('the whole phone keeps the plain labels', () {
      const scope = EverywhereScope();
      expect(
        passLabelFor(PassId.look, scope),
        const PassLabel(LocaleKeys.alarm_styles_strip_title),
      );
      expect(
        passLabelFor(PassId.challenge, scope),
        const PassLabel(LocaleKeys.challenges_strip_title),
      );
      expect(
        passLabelFor(PassId.sound, scope),
        const PassLabel(LocaleKeys.personalize_sound_title),
      );
    });

    test('a topic names itself on Look, Sound and Challenge', () {
      expect(
        passLabelFor(PassId.look, _topic),
        const PassLabel(LocaleKeys.personalize_passes_look_topic_label, {
          'topic': 'Uptime Kuma',
        }),
      );
      expect(
        passLabelFor(PassId.challenge, _topic),
        const PassLabel(LocaleKeys.personalize_passes_challenge_topic_label, {
          'topic': 'Uptime Kuma',
        }),
      );
      expect(
        passLabelFor(PassId.sound, _topic),
        const PassLabel(LocaleKeys.personalize_passes_sound_topic_label, {
          'topic': 'Uptime Kuma',
        }),
      );
    });

    test('the passes with no topic version keep their label', () {
      expect(
        passLabelFor(PassId.widgets, _topic),
        const PassLabel(LocaleKeys.personalize_widgets_row),
      );
      expect(
        passLabelFor(PassId.appIcon, _topic),
        const PassLabel(LocaleKeys.personalize_app_icon_row),
      );
    });
  });

  group('the look in use per scope', () {
    const phoneMinimal = AlarmStyleAssignments(defaultStyleId: 'minimal');

    test('a topic that follows the phone shows the phone look', () {
      expect(_inUse(phoneMinimal, _topic), AlarmStyleId.minimal);
      expect(topicHasOwnLook(_topic, phoneMinimal), isFalse);
    });

    test('a topic with its own free look shows Standard', () {
      final saved = phoneMinimal.withTopicStyle('Uptime Kuma', 'standard');
      expect(_inUse(saved, _topic), AlarmStyleId.standard);
      // A topic pinned to Standard still has a look of its own.
      expect(topicHasOwnLook(_topic, saved), isTrue);
    });

    test('a topic with its own paid look shows it while the plan is held', () {
      final saved = phoneMinimal.withTopicStyle('Uptime Kuma', 'terminal');
      expect(_inUse(saved, _topic), AlarmStyleId.terminal);
      expect(_inUse(saved, const EverywhereScope()), AlarmStyleId.minimal);
      expect(topicHasOwnLook(_topic, saved), isTrue);
    });

    test('a locked topic look shows the stand-in once the plan is read', () {
      final saved = phoneMinimal.withTopicStyle('Uptime Kuma', 'terminal');
      expect(
        _inUse(saved, _topic, decision: _locked),
        AlarmStyleId.standard,
      );
      // What is saved is untouched: it returns with the plan.
      expect(saved.perTopic['Uptime Kuma'], 'terminal');
    });

    test('the own look without a photo shows Standard', () {
      final saved = phoneMinimal.withTopicStyle('Uptime Kuma', 'own');
      expect(_inUse(saved, _topic), AlarmStyleId.standard);
      expect(
        _inUse(saved, _topic, isOwnLookReady: true),
        AlarmStyleId.own,
      );
    });

    test('another topic is not touched by this topic', () {
      final saved = phoneMinimal.withTopicStyle('Uptime Kuma', 'terminal');
      expect(_inUse(saved, const TopicScope('Other')), AlarmStyleId.minimal);
      expect(topicHasOwnLook(const TopicScope('Other'), saved), isFalse);
    });

    test('the whole phone never has "Same as phone"', () {
      final saved = phoneMinimal.withTopicStyle('Uptime Kuma', 'terminal');
      expect(topicHasOwnLook(const EverywhereScope(), saved), isFalse);
    });
  });

  group('writing the look', () {
    test('a topic scope calls the topic setter', () async {
      await saveLook(_topic, looks, 'terminal');
      verify(() => looks.setTopicStyle('Uptime Kuma', 'terminal')).called(1);
      verifyNever(() => looks.setDefault(any()));
    });

    test('the whole phone calls the default setter', () async {
      await saveLook(const EverywhereScope(), looks, 'terminal');
      verify(() => looks.setDefault('terminal')).called(1);
      verifyNever(() => looks.setTopicStyle(any(), any()));
    });

    test('"Same as phone" passes null for the topic', () async {
      await followPhoneLook(_topic, looks);
      verify(() => looks.setTopicStyle('Uptime Kuma', null)).called(1);
      verifyNever(() => looks.setDefault(any()));
    });

    test('"Same as phone" does nothing for the whole phone', () async {
      await followPhoneLook(const EverywhereScope(), looks);
      verifyNever(() => looks.setTopicStyle(any(), any()));
      verifyNever(() => looks.setDefault(any()));
    });

    test('a free look is saved without asking the lock rule', () async {
      var asked = 0;
      final used = await useLook(
        scope: _topic,
        choices: looks,
        id: AlarmStyleId.standard,
        mayKeep: () async {
          asked++;
          return false;
        },
      );
      expect(used, isTrue);
      expect(asked, 0);
      verify(() => looks.setTopicStyle('Uptime Kuma', 'standard')).called(1);
    });

    test('a locked look writes nothing before the lock rule says go', () async {
      final answer = Completer<void>();
      final future = useLook(
        scope: _topic,
        choices: looks,
        id: AlarmStyleId.terminal,
        mayKeep: () async {
          await answer.future;
          return true;
        },
      );
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => looks.setTopicStyle(any(), any()));
      answer.complete();
      expect(await future, isTrue);
      verify(() => looks.setTopicStyle('Uptime Kuma', 'terminal')).called(1);
    });

    test('a locked look the lock rule refuses is not written', () async {
      final used = await useLook(
        scope: _topic,
        choices: looks,
        id: AlarmStyleId.terminal,
        mayKeep: () async => false,
      );
      expect(used, isFalse);
      verifyNever(() => looks.setTopicStyle(any(), any()));
      verifyNever(() => looks.setDefault(any()));
    });

    test('the whole phone writes the default once the rule says go', () async {
      final used = await useLook(
        scope: const EverywhereScope(),
        choices: looks,
        id: AlarmStyleId.critPanic,
        mayKeep: () async => true,
      );
      expect(used, isTrue);
      verify(() => looks.setDefault('crit_panic')).called(1);
      verifyNever(() => looks.setTopicStyle(any(), any()));
    });

    test('a page that has gone writes nothing', () async {
      final used = await useLook(
        scope: _topic,
        choices: looks,
        id: AlarmStyleId.terminal,
        mayKeep: () async => true,
        afterGo: () => false,
      );
      expect(used, isFalse);
      verifyNever(() => looks.setTopicStyle(any(), any()));
    });

    test('a photo held in memory is saved by its own write', () async {
      var wrote = 0;
      final used = await useLook(
        scope: _topic,
        choices: looks,
        id: AlarmStyleId.own,
        mayKeep: () async => true,
        write: () async => wrote++,
      );
      expect(used, isTrue);
      expect(wrote, 1);
      verifyNever(() => looks.setTopicStyle(any(), any()));
    });
  });

  group('the challenge per scope', () {
    test('a topic reads its own choice and the phone reads the default', () {
      when(() => challenges.choiceFor('Uptime Kuma')).thenReturn(
        ChallengeKind.shake,
      );
      when(
        () => challenges.defaultForNewTopics,
      ).thenReturn(ChallengeKind.opsMath);
      expect(challengeSavedFor(_topic, challenges), ChallengeKind.shake);
      expect(
        challengeSavedFor(const EverywhereScope(), challenges),
        ChallengeKind.opsMath,
      );
    });

    test('a topic with no choice reads none, whatever the default is', () {
      when(() => challenges.choiceFor(any())).thenReturn(null);
      when(
        () => challenges.defaultForNewTopics,
      ).thenReturn(ChallengeKind.opsMath);
      expect(challengeSavedFor(_topic, challenges), isNull);
    });

    test('a saved choice reads Off while challenges are locked', () {
      const saved = ChallengeKind.shake;
      expect(shelfChosenFor(saved: saved, decision: _locked), isNull);
      expect(shelfChosenFor(saved: saved, decision: _open), saved);
    });

    test('saving writes the topic, or the default for new topics', () async {
      await saveChallenge(_topic, challenges, ChallengeKind.shake);
      verify(
        () => challenges.setChoice('Uptime Kuma', ChallengeKind.shake),
      ).called(1);
      verifyNever(() => challenges.setDefaultForNewTopics(any()));

      await saveChallenge(
        const EverywhereScope(),
        challenges,
        ChallengeKind.opsMath,
      );
      verify(
        () => challenges.setDefaultForNewTopics(ChallengeKind.opsMath),
      ).called(1);
    });

    test('"No challenge" for a topic writes null and needs no plan', () async {
      expect(shelfOffTapAnswer(), isA<DoIt>());
      await saveChallenge(_topic, challenges, null);
      verify(() => challenges.setChoice('Uptime Kuma', null)).called(1);
      verifyNever(() => challenges.setDefaultForNewTopics(any()));
    });

    test('picking a challenge asks the plan, in both scopes', () {
      // The scope changes where the pick is saved, not whether it is asked.
      expect(
        shelfTapFor(tap: ShelfTap.pick, decision: _locked, isPlanRead: true),
        isA<OpenPaywall>(),
      );
      expect(
        shelfTapFor(tap: ShelfTap.pick, decision: _open, isPlanRead: true),
        isA<DoIt>(),
      );
    });
  });
}
