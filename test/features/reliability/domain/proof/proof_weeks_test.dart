import 'package:critalarm/features/reliability/domain/proof/proof_entry.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_weeks.dart';
import 'package:flutter_test/flutter_test.dart';

ProofEntry _week(DateTime monday, {DateTime? rang, DateTime? failed}) =>
    ProofEntry(weekStart: monday, rangAt: rang, failedAt: failed);

void main() {
  group('proofWeekStart', () {
    test('a Wednesday goes back to its Monday at 00:00', () {
      // 2026-10-07 is a Wednesday.
      expect(
        proofWeekStart(DateTime(2026, 10, 7, 15, 30)),
        DateTime(2026, 10, 5),
      );
    });

    test('a Monday at 00:00 is its own week start', () {
      expect(proofWeekStart(DateTime(2026, 10, 5)), DateTime(2026, 10, 5));
    });

    test('a Sunday at 23:59 still belongs to the week before', () {
      expect(
        proofWeekStart(DateTime(2026, 10, 11, 23, 59, 59)),
        DateTime(2026, 10, 5),
      );
    });

    test('the next second is the next week', () {
      expect(proofWeekStart(DateTime(2026, 10, 12)), DateTime(2026, 10, 12));
    });

    test('across a year end', () {
      // 2027-01-01 is a Friday. Its Monday is in 2026.
      expect(proofWeekStart(DateTime(2027, 1, 1, 9)), DateTime(2026, 12, 28));
      // 2024-01-01 is a Monday.
      expect(
        proofWeekStart(DateTime(2024, 1, 1, 0, 0, 1)),
        DateTime(2024),
      );
      expect(
        proofWeekStart(DateTime(2023, 12, 31, 23)),
        DateTime(2023, 12, 25),
      );
    });

    test('across a clock change, both ways, the week is still midnight and '
        'seven calendar days', () {
      // United States: 2026-03-08 spring forward, 2026-11-01 fall back.
      // Europe: 2026-03-29 and 2026-10-25. The test runs in the machine's
      // zone, so the check is on dates, which hold in any zone.
      for (final day in [
        DateTime(2026, 3, 8, 12),
        DateTime(2026, 3, 9, 12),
        DateTime(2026, 3, 29, 12),
        DateTime(2026, 10, 25, 12),
        DateTime(2026, 11, 1, 12),
        DateTime(2026, 11, 2, 12),
      ]) {
        final start = proofWeekStart(day);
        expect(start.weekday, DateTime.monday, reason: '$day');
        expect(
          [start.hour, start.minute, start.second],
          [0, 0, 0],
          reason: '$day',
        );
        expect(
          proofWeekStart(DateTime(start.year, start.month, start.day + 7)),
          DateTime(start.year, start.month, start.day + 7),
          reason: '$day',
        );
        expect(day.difference(start).inDays, inInclusiveRange(0, 6));
      }
      expect(proofWeekStart(DateTime(2026, 3, 8, 12)), DateTime(2026, 3, 2));
      expect(proofWeekStart(DateTime(2026, 11, 1, 12)), DateTime(2026, 10, 26));
    });

    test('a UTC time is read in local time', () {
      final at = DateTime.utc(2026, 10, 7, 12);
      expect(proofWeekStart(at), proofWeekStart(at.toLocal()));
    });
  });

  group('proofWeeksFor', () {
    final now = DateTime(2026, 10, 7, 9); // Wednesday

    test('an empty log is eight weeks of none, this week last', () {
      final weeks = proofWeeksFor(const [], now);
      expect(weeks, hasLength(8));
      expect(weeks.every((w) => w.mark == ProofMark.none), isTrue);
      expect(weeks.last.monday, DateTime(2026, 10, 5));
      expect(weeks.first.monday, DateTime(2026, 8, 17));
      for (var i = 1; i < weeks.length; i++) {
        expect(
          weeks[i].monday,
          DateTime(
            weeks[i - 1].monday.year,
            weeks[i - 1].monday.month,
            weeks[i - 1].monday.day + 7,
          ),
        );
      }
    });

    test('one entry this week marks the last week', () {
      final weeks = proofWeeksFor([
        _week(DateTime(2026, 10, 5), rang: DateTime(2026, 10, 6, 8)),
      ], now);
      expect(weeks.last.mark, ProofMark.rang);
      expect(weeks.take(7).every((w) => w.mark == ProofMark.none), isTrue);
      expect(proofRangCount(weeks), 1);
    });

    test('rang beats failed, failed beats none', () {
      final weeks = proofWeeksFor([
        _week(
          DateTime(2026, 9, 28),
          rang: DateTime(2026, 9, 29),
          failed: DateTime(2026, 9, 30),
        ),
        _week(DateTime(2026, 9, 21), failed: DateTime(2026, 9, 22)),
      ], now);
      expect(weeks[6].mark, ProofMark.rang);
      expect(weeks[5].mark, ProofMark.failed);
    });

    test('an entry from nine weeks ago is dropped', () {
      final weeks = proofWeeksFor([
        _week(DateTime(2026, 8, 3), rang: DateTime(2026, 8, 4)),
      ], now);
      expect(proofRangCount(weeks), 0);
      // Eight weeks back is the first drawn week.
      final edge = proofWeeksFor([
        _week(DateTime(2026, 8, 17), rang: DateTime(2026, 8, 18)),
      ], now);
      expect(edge.first.mark, ProofMark.rang);
    });

    test('a week after this one is ignored', () {
      final weeks = proofWeeksFor([
        _week(DateTime(2026, 10, 12), rang: DateTime(2026, 10, 13)),
      ], now);
      expect(proofRangCount(weeks), 0);
      expect(weeks.last.monday, DateTime(2026, 10, 5));
    });

    test('a time after now, from a clock set back, counts for nothing', () {
      final weeks = proofWeeksFor([
        _week(DateTime(2026, 10, 5), rang: DateTime(2026, 10, 9, 8)),
      ], now);
      expect(weeks.last.mark, ProofMark.none);
      // A failed time that already passed still shows.
      final failed = proofWeeksFor([
        _week(
          DateTime(2026, 10, 5),
          rang: DateTime(2026, 10, 9, 8),
          failed: DateTime(2026, 10, 6),
        ),
      ], now);
      expect(failed.last.mark, ProofMark.failed);
    });

    test('a clock set back by weeks draws the stored weeks as none, not as '
        'this week', () {
      final stored = [
        _week(DateTime(2026, 10, 5), rang: DateTime(2026, 10, 6)),
        _week(DateTime(2026, 10, 12), rang: DateTime(2026, 10, 13)),
      ];
      final back = DateTime(2026, 9, 2, 9);
      final weeks = proofWeeksFor(stored, back);
      expect(weeks.last.monday, DateTime(2026, 8, 31));
      expect(proofRangCount(weeks), 0);
    });

    test('count is honoured', () {
      expect(proofWeeksFor(const [], now, count: 3), hasLength(3));
    });
  });

  group('proofMerge', () {
    final monday = DateTime(2026, 10, 5);

    test('into an empty log adds one entry', () {
      final log = proofMerge(
        const [],
        ProofEntry.rang(DateTime(2026, 10, 7, 9)),
      );
      expect(log, hasLength(1));
      expect(log.single.weekStart, monday);
    });

    test('rang beats failed', () {
      var log = proofMerge(
        const [],
        ProofEntry.failed(DateTime(2026, 10, 6, 8)),
      );
      log = proofMerge(log, ProofEntry.rang(DateTime(2026, 10, 7, 9)));
      expect(log, hasLength(1));
      expect(
        proofWeeksFor(log, DateTime(2026, 10, 8)).last.mark,
        ProofMark.rang,
      );
    });

    test('failed does not overwrite rang', () {
      var log = proofMerge(const [], ProofEntry.rang(DateTime(2026, 10, 6, 8)));
      log = proofMerge(log, ProofEntry.failed(DateTime(2026, 10, 7, 9)));
      expect(log, hasLength(1));
      expect(log.single.rangAt, DateTime(2026, 10, 6, 8));
      expect(
        proofWeeksFor(log, DateTime(2026, 10, 8)).last.mark,
        ProofMark.rang,
      );
    });

    test('the same kind twice in a week keeps the later time', () {
      var log = proofMerge(const [], ProofEntry.rang(DateTime(2026, 10, 7, 9)));
      log = proofMerge(log, ProofEntry.rang(DateTime(2026, 10, 6, 9)));
      expect(log.single.rangAt, DateTime(2026, 10, 7, 9));
      log = proofMerge(log, ProofEntry.rang(DateTime(2026, 10, 8, 9)));
      expect(log.single.rangAt, DateTime(2026, 10, 8, 9));
    });

    test('keeps the log oldest first', () {
      var log = proofMerge(const [], ProofEntry.rang(DateTime(2026, 10, 7)));
      log = proofMerge(log, ProofEntry.rang(DateTime(2026, 9, 23)));
      log = proofMerge(log, ProofEntry.rang(DateTime(2026, 9, 30)));
      expect(log.map((e) => e.key), ['2026-09-21', '2026-09-28', '2026-10-05']);
    });

    test('is cut to the newest 12 weeks', () {
      var log = <ProofEntry>[];
      for (var i = 0; i < 15; i++) {
        log = proofMerge(
          log,
          ProofEntry.rang(DateTime(2026, 1, 5 + 7 * i, 9)),
        );
      }
      expect(log, hasLength(12));
      expect(log.first.weekStart, DateTime(2026, 1, 26));
      expect(log.last.weekStart, DateTime(2026, 4, 13));
    });

    test('does not change the list it was given', () {
      final before = proofMerge(
        const [],
        ProofEntry.rang(DateTime(2026, 10, 7)),
      );
      proofMerge(before, ProofEntry.failed(DateTime(2026, 10, 8)));
      expect(before.single.failedAt, isNull);
    });
  });

  group('proofNewestRangAt', () {
    test('is null for an empty log and for a log with no rang', () {
      expect(proofNewestRangAt(const []), isNull);
      expect(
        proofNewestRangAt([ProofEntry.failed(DateTime(2026, 10, 7))]),
        isNull,
      );
    });

    test('is the latest rang across weeks', () {
      final log = [
        ProofEntry.rang(DateTime(2026, 9, 30, 9)),
        ProofEntry.rang(DateTime(2026, 10, 7, 9)),
        ProofEntry.failed(DateTime(2026, 10, 14, 9)),
      ];
      expect(proofNewestRangAt(log), DateTime(2026, 10, 7, 9));
    });

    test('with now, leaves out a time after it', () {
      final log = [
        ProofEntry.rang(DateTime(2026, 9, 30, 9)),
        ProofEntry.rang(DateTime(2026, 10, 7, 9)),
      ];
      expect(
        proofNewestRangAt(log, now: DateTime(2026, 10)),
        DateTime(2026, 9, 30, 9),
      );
    });
  });
}
