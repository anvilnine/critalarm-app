import 'package:critalarm/features/challenges/domain/challenge_incident.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/challenges/domain/hold_to_skip.dart';
import 'package:critalarm/features/challenges/domain/type_topic_name_match.dart';
import 'package:critalarm/features/challenges/presentation/challenge.dart';
import 'package:critalarm/features/challenges/presentation/type_topic_name_challenge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('topicNameMatches', () {
    bool match(String typed, [String topic = 'prod-db']) =>
        topicNameMatches(typed: typed, topic: topic);

    test('the name as written', () => expect(match('prod-db'), isTrue));
    test('capitals do not matter', () {
      expect(match('Prod-DB'), isTrue);
      expect(match('prod-db', 'Prod-DB'), isTrue);
    });
    test('spaces before and after do not matter', () {
      expect(match('  prod-db '), isTrue);
      expect(match('prod-db\n'), isTrue);
    });
    test('a space inside does', () => expect(match('prod -db'), isFalse));
    test('a missing hyphen does', () => expect(match('proddb'), isFalse));
    test('part of the name does not pass', () {
      expect(match('prod'), isFalse);
      expect(match('prod-db-2'), isFalse);
    });
    test('nothing typed does not pass', () {
      expect(match(''), isFalse);
      expect(match('   '), isFalse);
    });
    test('an empty topic name is never matched', () {
      expect(match('', ''), isFalse);
      expect(match(' ', '  '), isFalse);
    });
    test('a name of the full 64 characters', () {
      final name = '${'a' * 31}--${'B_' * 15}9';
      expect(name.length, 64);
      expect(match(name, name), isTrue);
      expect(match(' ${name.toUpperCase()} ', name), isTrue);
      expect(match(name.substring(0, 63), name), isFalse);
    });
    test('two hyphens and an underscore are typed as they are', () {
      expect(match('db--eu_1', 'db--eu_1'), isTrue);
      // What iOS smart dashes would make of it does not pass, which is
      // why the field turns them off.
      expect(match('db\u2014eu_1', 'db--eu_1'), isFalse);
      expect(match('db-eu_1', 'db--eu_1'), isFalse);
      expect(match('db--eu-1', 'db--eu_1'), isFalse);
    });
    test('the shown name steps down in size and never below 17', () {
      expect(topicNameFontSize('prod-db'), 24);
      expect(topicNameFontSize('a' * 20), 24);
      expect(topicNameFontSize('a' * 21), 20);
      expect(topicNameFontSize('a' * 41), 17);
      expect(topicNameFontSize('a' * 64), 17);
    });
    test('letters outside ASCII', () {
      expect(match('ÉCOLE', 'école'), isTrue);
    });
  });

  group('the hold', () {
    test('is ten seconds', () => expect(holdToSkip.inSeconds, 10));

    test('progress runs from 0 to 1 and stays inside', () {
      expect(holdProgress(Duration.zero), 0);
      expect(holdProgress(const Duration(seconds: -1)), 0);
      expect(holdProgress(const Duration(seconds: 5)), 0.5);
      expect(holdProgress(const Duration(seconds: 10)), 1);
      expect(holdProgress(const Duration(seconds: 30)), 1);
    });

    test('the count goes 10 down to 1, then 0', () {
      expect(holdSecondsLeft(Duration.zero), 10);
      expect(holdSecondsLeft(const Duration(milliseconds: 1)), 10);
      expect(holdSecondsLeft(const Duration(seconds: 1)), 9);
      expect(holdSecondsLeft(const Duration(milliseconds: 9001)), 1);
      expect(holdSecondsLeft(const Duration(milliseconds: 9999)), 1);
      expect(holdSecondsLeft(const Duration(seconds: 10)), 0);
    });

    test('done only at the full ten seconds', () {
      expect(holdIsDone(const Duration(milliseconds: 9999)), isFalse);
      expect(holdIsDone(const Duration(seconds: 10)), isTrue);
    });
  });

  group('ChallengeKind', () {
    test('ids are the ones saved on phones', () {
      expect(ChallengeKind.typeTopicName.id, 'type_topic_name');
    });

    test('ids are unique and read back', () {
      final ids = ChallengeKind.values.map((kind) => kind.id).toSet();
      expect(ids.length, ChallengeKind.values.length);
      for (final kind in ChallengeKind.values) {
        expect(ChallengeKind.fromId(kind.id), kind);
      }
    });

    test('nothing, and an id from a newer build, read as none', () {
      expect(ChallengeKind.fromId(null), isNull);
      expect(ChallengeKind.fromId(''), isNull);
      expect(ChallengeKind.fromId('push_ups'), isNull);
    });
  });

  group('the registry', () {
    test('has one challenge for every kind, each once', () {
      expect(
        challenges.map((challenge) => challenge.kind).toList(),
        ChallengeKind.values,
      );
      for (final kind in ChallengeKind.values) {
        expect(challengeOf(kind)?.kind, kind);
      }
      expect(challengeOf(null), isNull);
    });

    test('every challenge names itself and its prompt', () {
      for (final challenge in challenges) {
        expect(challenge.nameKey, startsWith('challenges.'));
        expect(challenge.promptKey, startsWith('challenges.'));
      }
    });

    test('type the topic name runs for any topic with a name', () {
      final challenge = challengeOf(ChallengeKind.typeTopicName)!;
      expect(
        challenge.canRunFor(const ChallengeIncident(topic: 'prod-db')),
        isTrue,
      );
      expect(
        challenge.canRunFor(const ChallengeIncident(topic: '  ')),
        isFalse,
      );
    });
  });
}
