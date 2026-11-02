import 'package:critalarm/core/format/clock_format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
    await initializeDateFormatting('ja');
  });

  final morning = DateTime(2026, 11, 2, 7, 5, 9);
  final evening = DateTime(2026, 11, 2, 19, 5, 9);
  final midnight = DateTime(2026, 11, 2);
  final noon = DateTime(2026, 11, 2, 12);

  group('24-hour clock', () {
    test('is the padded HH:mm the app always printed', () {
      expect(formatClock(morning, is24Hour: true), '07:05');
      expect(formatClock(evening, is24Hour: true), '19:05');
    });

    test('zero is 00:00', () {
      expect(formatClock(midnight, is24Hour: true), '00:00');
      expect(
        formatClock(midnight, is24Hour: true, withSeconds: true),
        '00:00:00',
      );
    });

    test('seconds are added on request', () {
      expect(
        formatClock(evening, is24Hour: true, withSeconds: true),
        '19:05:09',
      );
    });

    test('reads the same in de and ja, with the hour padded', () {
      for (final locale in ['en', 'de', 'ja']) {
        expect(formatClock(morning, is24Hour: true, locale: locale), '07:05');
        expect(
          formatClock(midnight, is24Hour: true, locale: locale),
          '00:00',
        );
        expect(
          formatClock(
            evening,
            is24Hour: true,
            withSeconds: true,
            locale: locale,
          ),
          '19:05:09',
        );
      }
    });
  });

  group('12-hour clock', () {
    test('English has the hour unpadded and AM or PM', () {
      expect(
        formatClock(morning, is24Hour: false, locale: 'en'),
        matches(RegExp(r'^7:05\s(AM)$')),
      );
      expect(
        formatClock(evening, is24Hour: false, locale: 'en'),
        matches(RegExp(r'^7:05\s(PM)$')),
      );
    });

    test('midnight is 12 AM and noon is 12 PM', () {
      expect(
        formatClock(midnight, is24Hour: false, locale: 'en'),
        matches(RegExp(r'^12:00\sAM$')),
      );
      expect(
        formatClock(noon, is24Hour: false, locale: 'en'),
        matches(RegExp(r'^12:00\sPM$')),
      );
    });

    test('seconds are added on request', () {
      expect(
        formatClock(
          evening,
          is24Hour: false,
          withSeconds: true,
          locale: 'en',
        ),
        matches(RegExp(r'^7:05:09\sPM$')),
      );
    });

    test('German gets a 12-hour form, not its own 24-hour one', () {
      expect(
        formatClock(evening, is24Hour: false, locale: 'de'),
        matches(RegExp(r'^7:05\sPM$')),
      );
    });

    test('Japanese writes the half of the day first', () {
      expect(formatClock(evening, is24Hour: false, locale: 'ja'), '午後7:05');
      expect(formatClock(morning, is24Hour: false, locale: 'ja'), '午前7:05');
    });

    test('Japanese counts the hour from 0 at midnight and noon', () {
      expect(formatClock(midnight, is24Hour: false, locale: 'ja'), '午前0:00');
      expect(formatClock(noon, is24Hour: false, locale: 'ja'), '午後0:00');
      expect(
        formatClock(
          midnight.add(const Duration(minutes: 5, seconds: 9)),
          is24Hour: false,
          withSeconds: true,
          locale: 'ja',
        ),
        '午前0:05:09',
      );
    });
  });

  group('minutes from midnight', () {
    test('zero and the last minute of the day', () {
      expect(formatMinuteOfDay(0, is24Hour: true), '00:00');
      expect(formatMinuteOfDay(1439, is24Hour: true), '23:59');
    });

    test('the quiet hours defaults', () {
      expect(formatMinuteOfDay(22 * 60, is24Hour: true), '22:00');
      expect(formatMinuteOfDay(7 * 60, is24Hour: true), '07:00');
      expect(
        formatMinuteOfDay(22 * 60, is24Hour: false, locale: 'en'),
        matches(RegExp(r'^10:00\sPM$')),
      );
    });

    test('a value past a day wraps', () {
      expect(formatMinuteOfDay(1500, is24Hour: true), '01:00');
    });
  });
}
