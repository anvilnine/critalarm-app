import 'package:critalarm/features/search/domain/query_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A Tuesday, so the weekday forms below are not accidentally right.
  final now = DateTime(2026, 9, 15, 10, 30);

  group('QueryDate.parse', () {
    test('reads today and yesterday, with the time stripped off', () {
      expect(QueryDate.parse('today', now: now), DateTime(2026, 9, 15));
      expect(QueryDate.parse('Yesterday', now: now), DateTime(2026, 9, 14));
    });

    test('reads an ISO date with either separator', () {
      expect(QueryDate.parse('2026-09-14', now: now), DateTime(2026, 9, 14));
      expect(QueryDate.parse('2026/9/4', now: now), DateTime(2026, 9, 4));
    });

    test('reads a month name before the day', () {
      expect(QueryDate.parse('sep 14', now: now), DateTime(2026, 9, 14));
      expect(QueryDate.parse('sept 14th', now: now), DateTime(2026, 9, 14));
      expect(
        QueryDate.parse('September 14, 2025', now: now),
        DateTime(2025, 9, 14),
      );
    });

    test('reads a month name after the day', () {
      expect(QueryDate.parse('14 sep', now: now), DateTime(2026, 9, 14));
      expect(
        QueryDate.parse('2nd august 2024', now: now),
        DateTime(2024, 8, 2),
      );
    });

    test('picks last year when this year would be in the future', () {
      // History only looks back, so "dec 25" in September means last December.
      expect(QueryDate.parse('dec 25', now: now), DateTime(2025, 12, 25));
    });

    test('picks this year for a date that has already passed', () {
      expect(QueryDate.parse('jan 3', now: now), DateTime(2026, 1, 3));
    });

    test('takes today itself as this year, not last', () {
      expect(QueryDate.parse('sep 15', now: now), DateTime(2026, 9, 15));
    });

    test('rejects a day that does not exist', () {
      expect(QueryDate.parse('feb 31', now: now), isNull);
      expect(QueryDate.parse('2026-02-30', now: now), isNull);
      expect(QueryDate.parse('2026-13-01', now: now), isNull);
    });

    test('rejects bare numeric dates, which are ambiguous', () {
      // 9/14 and 14/9 cannot be told apart without guessing a locale, and a
      // wrong guess silently shows the wrong alarms.
      expect(QueryDate.parse('9/14', now: now), isNull);
      expect(QueryDate.parse('14/9', now: now), isNull);
    });

    test('returns null for anything that is not a date', () {
      expect(QueryDate.parse('', now: now), isNull);
      expect(QueryDate.parse('prod-db', now: now), isNull);
      expect(QueryDate.parse('topic 12', now: now), isNull);
      expect(QueryDate.parse('september', now: now), isNull);
    });
  });
}
