import 'package:critalarm/core/format/when_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 9, 9, 30);

  String label(DateTime at, {DateTime? from}) =>
      formatWhen(at: at, now: from ?? now, yesterday: 'Yesterday');

  test('today is the time alone, in 24 hours', () {
    expect(label(DateTime(2026, 10, 9, 2, 41)), '02:41');
    expect(label(DateTime(2026, 10, 9, 18, 5)), '18:05');
  });

  test('midnight and the last minute of the day are both today', () {
    expect(label(DateTime(2026, 10, 9)), '00:00');
    expect(label(DateTime(2026, 10, 9, 23, 59)), '23:59');
  });

  test('the day before is the word the caller passed', () {
    expect(label(DateTime(2026, 10, 8, 23, 59)), 'Yesterday');
    expect(label(DateTime(2026, 10, 8)), 'Yesterday');
  });

  test('an earlier day this year is the day and the month', () {
    expect(label(DateTime(2026, 10, 7, 12)), '7 Oct');
    expect(label(DateTime(2026, 1, 2)), '2 Jan');
  });

  test('another year adds the year', () {
    expect(label(DateTime(2025, 12, 31, 23, 59)), '31 Dec 2025');
    expect(
      label(DateTime(2026, 12, 31), from: DateTime(2027, 1, 2)),
      '31 Dec 2026',
    );
  });

  test('yesterday across New Year is still the word', () {
    expect(
      label(DateTime(2026, 12, 31, 22), from: DateTime(2027, 1, 1, 8)),
      'Yesterday',
    );
  });

  test('a moment after now counts as today', () {
    expect(label(DateTime(2026, 10, 9, 23)), '23:00');
    expect(label(DateTime(2026, 10, 10, 1)), '01:00');
  });

  test('a UTC moment is read in the phone time', () {
    final local = DateTime(2026, 10, 9, 2, 41);
    expect(label(local.toUtc()), '02:41');
  });

  group('formatWhenWithTime', () {
    String stamp(DateTime at, {DateTime? from}) =>
        formatWhenWithTime(at: at, now: from ?? now, yesterday: 'Yesterday');

    test('today is the time alone', () {
      expect(stamp(DateTime(2026, 10, 9, 6, 25)), '06:25');
      expect(stamp(DateTime(2026, 10, 9)), '00:00');
    });

    test('the day before keeps the time, so same-day rows stay in order', () {
      expect(stamp(DateTime(2026, 10, 8, 0, 45)), 'Yesterday 00:45');
      expect(stamp(DateTime(2026, 10, 8, 0, 44)), 'Yesterday 00:44');
      expect(stamp(DateTime(2026, 10, 8, 23, 59)), 'Yesterday 23:59');
    });

    test('an earlier day this year is the day, the month and the time', () {
      expect(stamp(DateTime(2026, 10, 7, 12, 3)), '7 Oct 12:03');
      expect(stamp(DateTime(2026, 1, 2, 0, 45)), '2 Jan 00:45');
    });

    test('another year adds the year before the time', () {
      expect(stamp(DateTime(2025, 10, 8, 0, 45)), '8 Oct 2025 00:45');
      expect(
        stamp(DateTime(2026, 12, 30, 9, 5), from: DateTime(2027, 1, 2)),
        '30 Dec 2026 09:05',
      );
    });

    test('yesterday across New Year is still the word', () {
      expect(
        stamp(DateTime(2026, 12, 31, 22, 10), from: DateTime(2027, 1, 1, 8)),
        'Yesterday 22:10',
      );
    });

    test('a moment after now counts as today', () {
      expect(stamp(DateTime(2026, 10, 10, 1)), '01:00');
    });

    test('a UTC moment is read in the phone time', () {
      final local = DateTime(2026, 10, 8, 0, 45);
      expect(stamp(local.toUtc()), 'Yesterday 00:45');
    });
  });
}
