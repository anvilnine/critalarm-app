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
}
