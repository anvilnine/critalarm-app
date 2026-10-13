import 'package:critalarm/features/paywall/domain/leaving_numbers.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _now = DateTime(2026, 10, 13, 12);

LeavingAlarm _alarm(String id, DateTime at, {bool acked = false}) =>
    LeavingAlarm(id: id, openedAt: at, isAcked: acked);

/// [n] alarms at midday on different days, [acked] of them answered.
List<LeavingAlarm> _alarms(int n, {int acked = 0}) => [
  for (var i = 0; i < n; i++)
    _alarm('a$i', _now.subtract(Duration(days: 1 + i % 80)), acked: i < acked),
];

LeavingFacts _facts({
  int rang = 0,
  int answered = 0,
  int nights = 0,
  int critical = 0,
  int days = 30,
}) => LeavingFacts(
  rang: rang,
  answered: answered,
  nights: nights,
  criticalTopics: critical,
  historyDaysHeld: days,
);

void main() {
  group('leavingFactsFrom', () {
    test('counts what rang and what was answered', () {
      final facts = leavingFactsFrom(
        alarms: _alarms(12, acked: 11),
        now: _now,
        criticalTopics: 3,
        oldestOpenedAt: _now.subtract(const Duration(days: 80)),
      );
      expect(facts.rang, 12);
      expect(facts.answered, 11);
      expect(facts.criticalTopics, 3);
    });

    test('the window is the last 90 days, the edge counts', () {
      final facts = leavingFactsFrom(
        alarms: [
          _alarm('edge', _now.subtract(const Duration(days: 90))),
          _alarm(
            'old',
            _now.subtract(const Duration(days: 90, minutes: 1)),
          ),
          _alarm('new', _now.subtract(const Duration(hours: 2))),
        ],
        now: _now,
        criticalTopics: 0,
        oldestOpenedAt: null,
      );
      expect(facts.rang, 2);
    });

    test('setup tests are left out', () {
      final facts = leavingFactsFrom(
        alarms: [
          _alarm('setup', _now.subtract(const Duration(days: 3)), acked: true),
          _alarm('own', _now.subtract(const Duration(days: 2)), acked: true),
        ],
        now: _now,
        criticalTopics: 0,
        oldestOpenedAt: null,
        excludedIds: const {'setup'},
      );
      expect(facts.rang, 1);
      expect(facts.answered, 1);
    });

    test(
      'a night is a date with a row from 00:00 up to but not including 06:00',
      () {
        final facts = leavingFactsFrom(
          alarms: [
            _alarm('a', DateTime(2026, 10, 12, 23, 41)), // evening, not a night
            _alarm('b', DateTime(2026, 10, 13)), // night of the 13th
            _alarm('c', DateTime(2026, 10, 13, 5, 59)), // same night
            _alarm('d', DateTime(2026, 10, 13, 6)), // morning, not a night
            _alarm('e', DateTime(2026, 10, 11, 3, 30)), // night of the 11th
          ],
          now: _now,
          criticalTopics: 0,
          oldestOpenedAt: null,
        );
        expect(facts.nights, 2);
      },
    );

    test('history days held come from the oldest row', () {
      LeavingFacts held(DateTime? oldest) => leavingFactsFrom(
        alarms: const [],
        now: _now,
        criticalTopics: 0,
        oldestOpenedAt: oldest,
      );
      expect(held(null).historyDaysHeld, 0);
      expect(
        held(_now.subtract(const Duration(days: 40))).historyDaysHeld,
        40,
      );
      expect(
        held(_now.add(const Duration(days: 2))).historyDaysHeld,
        0,
        reason: 'a row from the future is not history',
      );
    });
  });

  group('leavingSlipFor floors', () {
    test('nothing clears: no rows, Wipe', () {
      final slip = leavingSlipFor(
        _facts(rang: 9, answered: 9, nights: 2, critical: 2),
      );
      expect(slip.rows, isEmpty);
      expect(slip.strongest, isNull);
      expect(slip.showsReceipt, isFalse);
    });

    test('each floor on its own, one row is still Wipe', () {
      final cases = <LeavingRow, LeavingFacts>{
        LeavingRow.rang: _facts(rang: 10),
        LeavingRow.nights: _facts(nights: 3),
        LeavingRow.criticalTopics: _facts(critical: 3),
        LeavingRow.answered: _facts(rang: 10, answered: 10),
      };
      for (final entry in cases.entries) {
        final slip = leavingSlipFor(entry.value);
        expect(
          slip.rows.map((r) => r.row),
          contains(entry.key),
          reason: '${entry.key}',
        );
      }
      expect(leavingSlipFor(_facts(rang: 10)).showsReceipt, isFalse);
      expect(leavingSlipFor(_facts(nights: 3)).showsReceipt, isFalse);
      expect(leavingSlipFor(_facts(critical: 3)).showsReceipt, isFalse);
    });

    test('one under the floor leaves the row off', () {
      expect(leavingSlipFor(_facts(rang: 9)).rows, isEmpty);
      expect(leavingSlipFor(_facts(nights: 2)).rows, isEmpty);
      expect(leavingSlipFor(_facts(critical: 2)).rows, isEmpty);
    });

    test('two rows make a receipt', () {
      final slip = leavingSlipFor(_facts(rang: 10, nights: 3));
      expect(slip.showsReceipt, isTrue);
      expect(slip.rows.length, 2);
    });

    test('rows come in the order of the slip, not of strength', () {
      final slip = leavingSlipFor(
        _facts(rang: 142, answered: 139, nights: 9, critical: 4),
      );
      expect(slip.rows.map((r) => r.row), [
        LeavingRow.rang,
        LeavingRow.answered,
        LeavingRow.nights,
        LeavingRow.criticalTopics,
      ]);
      expect(slip.rows.map((r) => r.value), [142, 139, 9, 4]);
    });
  });

  group('the answered rule', () {
    List<LeavingRow> rowsFor(int rang, int answered) => leavingSlipFor(
      _facts(rang: rang, answered: answered),
    ).rows.map((r) => r.row).toList();

    test('needs 10 answered and 80 percent of what rang', () {
      expect(rowsFor(100, 79), isNot(contains(LeavingRow.answered)));
      expect(rowsFor(100, 80), contains(LeavingRow.answered));
      // 10 of 12 is 83 percent.
      expect(rowsFor(12, 10), contains(LeavingRow.answered));
      // 10 of 13 is 77 percent.
      expect(rowsFor(13, 10), isNot(contains(LeavingRow.answered)));
      // 80 percent of 10 is 8, and 8 is under the floor of 10.
      expect(rowsFor(10, 8), isNot(contains(LeavingRow.answered)));
    });
  });

  group('the strongest row', () {
    test(
      'the first that cleared, in the order nights, rang, topics, answered',
      () {
        expect(
          leavingSlipFor(
            _facts(rang: 50, answered: 50, nights: 5, critical: 4),
          ).strongest,
          LeavingRow.nights,
        );
        expect(
          leavingSlipFor(
            _facts(rang: 50, answered: 50, nights: 2, critical: 4),
          ).strongest,
          LeavingRow.rang,
        );
        expect(
          leavingSlipFor(_facts(rang: 5, nights: 2, critical: 4)).strongest,
          LeavingRow.criticalTopics,
        );
      },
    );

    test(
      'answered is never the strongest, because rang clears first',
      () {
        // Answered needs 10 answered, so 10 rang, so the rang row cleared.
        for (var rang = 0; rang < 30; rang++) {
          for (var answered = 0; answered <= rang; answered++) {
            final slip = leavingSlipFor(
              _facts(rang: rang, answered: answered),
            );
            expect(slip.strongest, isNot(LeavingRow.answered));
          }
        }
      },
    );
  });

  group('LeavingFacts query', () {
    test('round trips', () {
      final facts = _facts(
        rang: 142,
        answered: 139,
        nights: 9,
        critical: 4,
        days: 61,
      );
      expect(facts.toQuery(), {
        'rang': '142',
        'ans': '139',
        'nights': '9',
        'crit': '4',
        'days': '61',
      });
      final back = LeavingFacts.fromQuery(facts.toQuery())!;
      expect(back.rang, 142);
      expect(back.answered, 139);
      expect(back.nights, 9);
      expect(back.criticalTopics, 4);
      expect(back.historyDaysHeld, 61);
    });

    test('a missing or junk field makes no facts at all', () {
      final good = _facts(rang: 1).toQuery();
      for (final key in good.keys) {
        expect(
          LeavingFacts.fromQuery({...good}..remove(key)),
          isNull,
          reason: key,
        );
        for (final junk in ['-4', 'abc', '', '1234567', '1.5']) {
          expect(
            LeavingFacts.fromQuery({...good, key: junk}),
            isNull,
            reason: '$key=$junk',
          );
        }
      }
    });
  });

  group('leavingCriticalLineFor', () {
    test('two or more, one, none', () {
      expect(leavingCriticalLineFor(4), LeavingCriticalLine.many);
      expect(leavingCriticalLineFor(2), LeavingCriticalLine.many);
      expect(leavingCriticalLineFor(1), LeavingCriticalLine.one);
      expect(leavingCriticalLineFor(0), LeavingCriticalLine.none);
    });

    test('a number below zero reads as none', () {
      expect(leavingCriticalLineFor(-3), LeavingCriticalLine.none);
    });
  });
}
