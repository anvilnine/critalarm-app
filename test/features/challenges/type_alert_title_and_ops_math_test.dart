import 'package:critalarm/features/challenges/domain/challenge_incident.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/challenges/domain/ops_math_question.dart';
import 'package:critalarm/features/challenges/domain/type_alert_title_match.dart';
import 'package:critalarm/features/challenges/presentation/challenge.dart';
import 'package:flutter_test/flutter_test.dart';

bool _title(String typed, String? title) =>
    alertTitleMatches(typed: typed, title: title);

void main() {
  group('alertTitleMatches', () {
    test('the first three words match', () {
      expect(_title('disk full on', 'Disk full on nas'), isTrue);
    });

    test('case, outer spaces and runs of spaces do not matter', () {
      expect(_title('  DISK   Full  ON ', 'disk full on nas'), isTrue);
    });

    test('punctuation at word edges does not matter, inside does', () {
      expect(_title('disk full on', 'Disk: full, (on) nas'), isTrue);
      expect(_title('disk full on', 'Disk: full, (on) nas'), isTrue);
      expect(_title('e.g full', 'e.g. full'), isTrue);
      expect(_title('node 1 down', 'node-1 down'), isFalse);
      expect(_title('node-1 down', 'node-1 down'), isTrue);
    });

    test('a title of one or two words asks for all of it', () {
      expect(_title('down', 'Down!'), isTrue);
      expect(_title('db down', 'DB down'), isTrue);
      expect(_title('db', 'DB down'), isFalse);
    });

    test('fewer, more or different words do not match', () {
      expect(_title('disk full', 'disk full on nas'), isFalse);
      expect(_title('disk full on nas', 'disk full on nas'), isFalse);
      expect(_title('disk full in', 'disk full on nas'), isFalse);
    });

    test('an empty answer, spaces and an empty title never match', () {
      expect(_title('', 'disk full'), isFalse);
      expect(_title('   ', 'disk full'), isFalse);
      expect(_title('', ''), isFalse);
      expect(_title('anything', ''), isFalse);
      expect(_title('anything', null), isFalse);
      expect(_title('', null), isFalse);
    });

    test('a title of only symbols has no words and never matches', () {
      expect(_title('', '--- !!!'), isFalse);
      expect(_title('---', '--- !!!'), isFalse);
      expect(alertTitleWordsToType('--- !!!'), isEmpty);
    });

    test('unicode letters and digits count, emoji at the edge do not', () {
      expect(_title('café down', 'Café down'), isTrue);
      expect(_title('сервер упал', 'СЕРВЕР упал'), isTrue);
      expect(_title('サーバー 停止', 'サーバー 停止'), isTrue);
      expect(_title('disk full on', '🔥 disk full on nas 🔥'), isTrue);
      expect(_title('disk full on', '🔥 Disk full on nas'), isTrue);
      expect(_title('503 on api', '503 on api'), isTrue);
    });

    test('a 200 character title asks for three words only', () {
      final title = 'alpha beta gamma ${'x' * 183}';
      expect(title.length, 200);
      expect(_title('alpha beta gamma', title), isTrue);
      expect(_title('alpha beta', title), isFalse);
      expect(_title(title, title), isFalse);
      expect(alertTitleWordsToType(title), ['alpha', 'beta', 'gamma']);
    });

    test('tabs and new lines count as spaces', () {
      expect(_title('disk full on', 'disk\tfull\non nas'), isTrue);
    });
  });

  group('alertTitleParts', () {
    test('joins back into the exact title, however long', () {
      for (final title in [
        'Disk full on nas',
        '  spaced   out  ',
        '🔥 one two three four',
        'x' * 200,
        '',
      ]) {
        expect(alertTitleParts(title).map((p) => p.text).join(), title);
      }
    });

    test('marks the first three real words', () {
      final asked = alertTitleParts(
        '- Disk full on nas',
      ).where((p) => p.isAsked).map((p) => p.text).toList();
      expect(asked, ['Disk', 'full', 'on']);
    });
  });

  group('opsMathQuestion', () {
    test('every seed gives one whole answer inside the stated range', () {
      final seen = <OpsMathKind>{};
      for (var seed = 0; seed < 5000; seed++) {
        final q = opsMathQuestion(seed);
        seen.add(q.kind);
        final (low, high) = switch (q.kind) {
          OpsMathKind.hexToDecimal => (16, 255),
          OpsMathKind.powerOfTwo => (1, 12),
          OpsMathKind.secondsInMinutes => (2, 90),
          OpsMathKind.secondsInHours => (1, 12),
          OpsMathKind.kilobytesInMegabytes => (2, 64),
        };
        expect(q.operand, inInclusiveRange(low, high), reason: 'seed $seed');
        expect(q.answer, greaterThan(0));
        switch (q.kind) {
          case OpsMathKind.hexToDecimal:
            expect(q.answer, lessThanOrEqualTo(0xFF));
            expect(int.parse(q.operandText.substring(2), radix: 16), q.answer);
          case OpsMathKind.powerOfTwo:
            expect(q.answer, lessThanOrEqualTo(4096));
          case OpsMathKind.secondsInMinutes:
            expect(q.answer, q.operand * 60);
          case OpsMathKind.secondsInHours:
            expect(q.answer, q.operand * 3600);
          case OpsMathKind.kilobytesInMegabytes:
            expect(q.answer, q.operand * 1024);
        }
      }
      expect(seen, OpsMathKind.values.toSet());
    });

    test('the same seed gives the same question', () {
      for (var seed = 0; seed < 200; seed++) {
        final a = opsMathQuestion(seed);
        final b = opsMathQuestion(seed);
        expect(a.kind, b.kind);
        expect(a.operand, b.operand);
      }
    });

    test('known answers', () {
      expect(OpsMathQuestion.sample.answer, 31);
      expect(OpsMathQuestion.sample.operandText, '0x1F');
      const power = OpsMathQuestion(kind: OpsMathKind.powerOfTwo, operand: 12);
      expect(power.answer, 4096);
      const hours = OpsMathQuestion(
        kind: OpsMathKind.secondsInHours,
        operand: 3,
      );
      expect(hours.answer, 10800);
    });
  });

  group('opsMathAnswerMatches', () {
    bool ok(String typed, [int answer = 31]) =>
        opsMathAnswerMatches(typed: typed, answer: answer);

    test('the right number matches', () {
      expect(ok('31'), isTrue);
      expect(ok(' 31 '), isTrue);
    });

    test('leading zeros do not matter', () {
      expect(ok('031'), isTrue);
      expect(ok('0031'), isTrue);
    });

    test('a minus sign, a plus sign or a point is not an answer', () {
      expect(ok('-31'), isFalse);
      expect(ok('+31'), isFalse);
      expect(ok('31.0'), isFalse);
      expect(ok('3 1'), isFalse);
    });

    test('empty, zero, letters and the wrong number do not match', () {
      expect(ok(''), isFalse);
      expect(ok('   '), isFalse);
      expect(ok('0'), isFalse);
      expect(ok('1F'), isFalse);
      expect(ok('30'), isFalse);
      expect(ok('310'), isFalse);
    });

    test('unicode digits and a huge number do not match or crash', () {
      expect(ok('٣١'), isFalse);
      expect(ok('9' * 40), isFalse);
      expect(ok('3️⃣1️⃣'), isFalse);
    });
  });

  group('the two challenges in the registry', () {
    const real = ChallengeIncident(
      topic: 'prod-db',
      alertTitle: 'Primary database down',
    );

    test('type the alert title runs only for a real title', () {
      final c = challengeOf(ChallengeKind.typeAlertTitle)!;
      expect(c.canRunFor(real), isTrue);
      expect(c.canRunFor(const ChallengeIncident(topic: 'prod-db')), isFalse);
      expect(
        c.canRunFor(const ChallengeIncident(topic: 'prod-db', alertTitle: '')),
        isFalse,
      );
      expect(
        c.canRunFor(
          const ChallengeIncident(topic: 'prod-db', alertTitle: ' - ! '),
        ),
        isFalse,
      );
    });

    test('ops math runs for any alarm', () {
      final c = challengeOf(ChallengeKind.opsMath)!;
      expect(c.canRunFor(real), isTrue);
      expect(c.canRunFor(const ChallengeIncident(topic: 'prod-db')), isTrue);
    });

    test('ids are the ones saved on phones', () {
      expect(ChallengeKind.typeAlertTitle.id, 'type_alert_title');
      expect(ChallengeKind.opsMath.id, 'ops_math');
    });
  });
}
