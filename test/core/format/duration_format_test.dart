import 'package:critalarm/core/format/duration_format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
    await initializeDateFormatting('ja');
  });

  test('zero is 0:00', () {
    expect(formatMinutesSeconds(Duration.zero), '0:00');
  });

  test('seconds are padded to two digits', () {
    expect(formatMinutesSeconds(const Duration(seconds: 7)), '0:07');
    expect(formatMinutesSeconds(const Duration(seconds: 59)), '0:59');
  });

  test('minutes roll over at 60 seconds', () {
    expect(formatMinutesSeconds(const Duration(seconds: 60)), '1:00');
    expect(
      formatMinutesSeconds(const Duration(minutes: 3, seconds: 7)),
      '3:07',
    );
  });

  test('milliseconds are dropped, not rounded', () {
    expect(
      formatMinutesSeconds(const Duration(seconds: 12, milliseconds: 999)),
      '0:12',
    );
  });

  test('minutes keep counting past an hour', () {
    expect(formatMinutesSeconds(const Duration(hours: 1)), '60:00');
    expect(
      formatMinutesSeconds(const Duration(hours: 1, minutes: 1, seconds: 5)),
      '61:05',
    );
  });

  test('a negative length reads as zero', () {
    expect(formatMinutesSeconds(const Duration(seconds: -5)), '0:00');
  });

  test('de and ja read the same', () {
    for (final locale in ['en', 'de', 'ja']) {
      expect(
        formatMinutesSeconds(
          const Duration(minutes: 3, seconds: 7),
          locale: locale,
        ),
        '3:07',
      );
      expect(formatMinutesSeconds(Duration.zero, locale: locale), '0:00');
      expect(
        formatMinutesSeconds(
          const Duration(hours: 1, seconds: 5),
          locale: locale,
        ),
        '60:05',
      );
    }
  });
}
