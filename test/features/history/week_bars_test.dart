import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/design/faces/face_meaning.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/history/domain/entities/history_entry.dart';
import 'package:critalarm/features/history/domain/week_bars.dart';
import 'package:flutter_test/flutter_test.dart';

HistoryEntry _entry(
  DateTime startedAt, {
  IncidentState state = IncidentState.acked,
  Duration? ring = const Duration(seconds: 10),
}) => HistoryEntry(
  id: 'i${startedAt.microsecondsSinceEpoch}',
  topic: 'prod-db',
  startedAt: startedAt,
  state: state,
  ringDuration: ring,
);

void main() {
  // Thursday 8 October 2026, mid afternoon, local clock.
  final now = DateTime(2026, 10, 8, 15, 30);

  WeekBars build(
    List<HistoryEntry> entries, {
    int shownDays = 90,
    bool hasMore = false,
    DateTime? oldestLoaded,
  }) => buildWeekBars(
    entries: entries,
    now: now,
    shownDays: shownDays,
    hasMore: hasMore,
    oldestLoaded: oldestLoaded,
  );

  group('the seven days', () {
    test('an empty list is seven quiet days ending today', () {
      final week = build(const []);
      expect(week.days, hasLength(7));
      expect(week.days.first.day, DateTime(2026, 10, 2));
      expect(week.days.last.day, DateTime(2026, 10, 8));
      expect(week.days.last.isToday, isTrue);
      expect(week.days.where((d) => d.isToday), hasLength(1));
      expect(week.days.every((d) => d.alarms == 0 && !d.isHidden), isTrue);
      expect(week.alarms, 0);
      expect(week.unanswered, 0);
      expect(week.longestAnswered, isNull);
      expect(week.mayBeShort, isFalse);
    });

    test('one alarm lands on its own day', () {
      final week = build([_entry(DateTime(2026, 10, 6, 3, 12))]);
      expect(week.alarms, 1);
      expect(week.days[4].day, DateTime(2026, 10, 6));
      expect(week.days[4].alarms, 1);
      expect(week.days.where((d) => d.alarms > 0), hasLength(1));
      expect(week.longestAnswered, const Duration(seconds: 10));
    });

    test('a full week counts every day and keeps the longest answer', () {
      final week = build([
        for (var i = 0; i < 7; i++)
          _entry(
            DateTime(2026, 10, 8 - i, 9),
            ring: Duration(seconds: 5 + i),
          ),
        _entry(DateTime(2026, 10, 8, 1), ring: const Duration(seconds: 3)),
      ]);
      expect(week.alarms, 8);
      expect(week.days.last.alarms, 2);
      expect(week.days.take(6).every((d) => d.alarms == 1), isTrue);
      expect(week.longestAnswered, const Duration(seconds: 11));
    });

    test('an alarm older than the week is not counted', () {
      final week = build([
        _entry(DateTime(2026, 10, 1, 23, 59)),
        _entry(DateTime(2026, 10, 2, 0, 1)),
      ]);
      expect(week.alarms, 1);
      expect(week.days.first.alarms, 1);
    });

    test('an alarm from tomorrow is not counted', () {
      expect(build([_entry(DateTime(2026, 10, 9, 0, 5))]).alarms, 0);
    });
  });

  group('a window shorter than a week', () {
    test('days the plan does not reach have no bar and count for nothing', () {
      final week = build([
        _entry(DateTime(2026, 10, 8, 8)),
        _entry(DateTime(2026, 10, 6, 8)),
        _entry(DateTime(2026, 10, 4, 8)),
      ], shownDays: 3);
      expect(week.visibleDays, 3);
      expect(week.days.map((d) => d.isHidden), [
        true,
        true,
        true,
        true,
        false,
        false,
        false,
      ]);
      expect(week.alarms, 2);
      expect(week.days[2].alarms, 0);
    });

    test('a window of a month shows all seven', () {
      final week = build(const [], shownDays: 30);
      expect(week.visibleDays, 7);
      expect(week.days.any((d) => d.isHidden), isFalse);
    });

    test('a window of no days hides the whole chart', () {
      final week = build([_entry(DateTime(2026, 10, 8, 8))], shownDays: 0);
      expect(week.days.every((d) => d.isHidden), isTrue);
      expect(week.alarms, 0);
    });
  });

  group('answered and not answered', () {
    test('an alarm nobody answered marks its day and the week', () {
      final week = build([
        _entry(DateTime(2026, 10, 5, 3), state: IncidentState.expired),
        _entry(DateTime(2026, 10, 7, 3)),
      ]);
      expect(week.unanswered, 1);
      expect(week.days[3].unanswered, 1);
      expect(week.days[5].unanswered, 0);
      expect(week.face, needsLookFace);
    });

    test('an unanswered ring does not set the longest answered time', () {
      final week = build([
        _entry(
          DateTime(2026, 10, 5, 3),
          state: IncidentState.expired,
          ring: const Duration(minutes: 10),
        ),
        _entry(DateTime(2026, 10, 7, 3), ring: const Duration(seconds: 11)),
      ]);
      expect(week.longestAnswered, const Duration(seconds: 11));
    });

    test('a week with no answered alarm has no longest', () {
      final week = build([
        _entry(DateTime(2026, 10, 5, 3), state: IncidentState.expired),
      ]);
      expect(week.longestAnswered, isNull);
    });

    test('a closed alarm counts as answered', () {
      final week = build([
        _entry(
          DateTime(2026, 10, 7, 3),
          state: IncidentState.closed,
          ring: const Duration(seconds: 44),
        ),
      ]);
      expect(week.unanswered, 0);
      expect(week.longestAnswered, const Duration(seconds: 44));
    });

    test('an answered alarm with no ring time is skipped for the longest', () {
      final week = build([_entry(DateTime(2026, 10, 7, 3), ring: null)]);
      expect(week.alarms, 1);
      expect(week.longestAnswered, isNull);
    });

    test('a ringing alarm counts as not answered', () {
      final week = build([
        _entry(DateTime(2026, 10, 8, 15), state: IncidentState.open),
      ]);
      expect(week.unanswered, 1);
      expect(week.days.last.unanswered, 1);
    });
  });

  group('the face', () {
    test('a quiet week is calm', () {
      expect(build(const []).face, FaceState.calm);
    });

    test('a week of answered alarms wears the answered face', () {
      expect(
        build([_entry(DateTime(2026, 10, 7, 3))]).face,
        FaceState.acked,
      );
    });

    test('a not answered alarm never gets a glad face', () {
      final face = build([
        _entry(DateTime(2026, 10, 7, 3)),
        _entry(DateTime(2026, 10, 6, 3), state: IncidentState.expired),
      ]).face;
      expect(face, isNot(FaceState.happy));
      expect(face, isNot(FaceState.acked));
      expect(face, isNot(FaceState.calm));
    });
  });

  group('marks', () {
    test('acked and closed are answered, expired is not, open rings', () {
      expect(historyMarkFor(IncidentState.acked), HistoryMark.answered);
      expect(historyMarkFor(IncidentState.closed), HistoryMark.answered);
      expect(historyMarkFor(IncidentState.expired), HistoryMark.notAnswered);
      expect(historyMarkFor(IncidentState.open), HistoryMark.ringing);
    });
  });

  group('a count that may be short', () {
    test('another page whose oldest alarm is inside the week may be short', () {
      final week = build(
        [_entry(DateTime(2026, 10, 7, 3))],
        hasMore: true,
        oldestLoaded: DateTime(2026, 10, 4, 3),
      );
      expect(week.mayBeShort, isTrue);
    });

    test('another page that starts before the week cannot hide any', () {
      final week = build(
        [_entry(DateTime(2026, 10, 7, 3))],
        hasMore: true,
        oldestLoaded: DateTime(2026, 9, 20, 3),
      );
      expect(week.mayBeShort, isFalse);
    });

    test('nothing more to read is exact', () {
      final week = build(
        [_entry(DateTime(2026, 10, 7, 3))],
        oldestLoaded: DateTime(2026, 10, 7, 3),
      );
      expect(week.mayBeShort, isFalse);
    });

    test('the first day of a short window counts as inside it', () {
      final week = build(
        const [],
        shownDays: 3,
        hasMore: true,
        oldestLoaded: DateTime(2026, 10, 6, 23),
      );
      expect(week.mayBeShort, isTrue);
    });
  });

  group('daylight saving', () {
    // Whatever zone the test runs in, days are counted on the calendar. These
    // dates sit on the US and EU clock changes, where a day is 23 or 25 hours.
    for (final (label, date) in [
      ('US spring', DateTime(2026, 3, 8, 12)),
      ('US autumn', DateTime(2026, 11, 1, 12)),
      ('EU spring', DateTime(2026, 3, 29, 12)),
      ('EU autumn', DateTime(2026, 10, 25, 12)),
    ]) {
      test('$label: seven different calendar days in a row', () {
        final week = buildWeekBars(
          entries: [_entry(date.subtract(const Duration(days: 3)))],
          now: date,
          shownDays: 90,
        );
        for (var i = 0; i < 7; i++) {
          final expected = DateTime(date.year, date.month, date.day - (6 - i));
          expect(week.days[i].day, expected);
        }
        expect(week.alarms, 1);
        expect(week.days[3].alarms, 1);
      });
    }

    test('a late evening alarm stays on its own day', () {
      final week = buildWeekBars(
        entries: [_entry(DateTime(2026, 3, 8, 23, 50))],
        now: DateTime(2026, 3, 9, 0, 10),
        shownDays: 90,
      );
      expect(week.days[5].day, DateTime(2026, 3, 8));
      expect(week.days[5].alarms, 1);
      expect(week.days[6].alarms, 0);
    });
  });
}
