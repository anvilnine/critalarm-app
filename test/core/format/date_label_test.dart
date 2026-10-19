import 'dart:isolate';

import 'package:critalarm/core/format/date_label.dart';
import 'package:critalarm/core/format/when_label.dart';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  final at = DateTime(2026, 10, 19, 5, 3);

  setUpAll(() async {
    await initializeDateFormatting('de');
    await initializeDateFormatting('ja');
    await initializeDateFormatting('en');
    await initializeDateFormatting('en_GB');
  });

  void load(String locale) {
    Localization.load(
      Locale(locale),
      translations: Translations({
        'dart_format': {'locale': locale},
      }),
    );
  }

  tearDown(() => load('en'));

  test('date labels read the active bundle again after a language change', () {
    for (final locale in ['de', 'ja', 'en']) {
      load(locale);
      expect(
        DateLabel.dayMonth(at),
        locale == 'en' ? '19 Oct' : DateFormat.MMMd(locale).format(at),
      );
    }
  });

  for (final locale in ['de', 'ja']) {
    test('$locale relative labels use skeletons for earlier calendar days', () {
      load(locale);
      final now = DateTime(2026, 10, 21, 12);
      final lastYear = DateTime(2025, 10, 19, 5, 3);
      expect(
        formatWhen(at: at, now: now, yesterday: 'yesterday'),
        DateFormat.MMMd(locale).format(at),
      );
      expect(
        formatWhen(at: lastYear, now: now, yesterday: 'yesterday'),
        DateFormat.yMMMd(locale).format(lastYear),
      );
      expect(
        formatWhenWithTime(at: at, now: now, yesterday: 'yesterday'),
        DateFormat.MMMd(locale).add_Hm().format(at),
      );
      expect(
        formatWhenWithTime(at: lastYear, now: now, yesterday: 'yesterday'),
        DateFormat.yMMMd(locale).add_Hm().format(lastYear),
      );
      expect(
        formatWhenWithTime(at: now, now: now, yesterday: 'yesterday'),
        DateFormat.Hm(locale).format(now),
      );
    });
  }

  for (final locale in ['en', 'en_US', 'en_GB']) {
    test('$locale keeps every English date pattern byte-identical', () {
      expect(DateLabel.dayMonth(at, locale: locale), '19 Oct');
      expect(DateLabel.monthDay(at, locale: locale), 'Oct 19');
      expect(DateLabel.dayMonthYear(at, locale: locale), '19 Oct 2026');
      expect(
        DateLabel.weekdayDayMonth(at, locale: locale),
        'Monday 19 October',
      );
      expect(
        DateLabel.weekdayDayMonthYear(at, locale: locale),
        'Monday 19 October 2026',
      );
      expect(DateLabel.shortWeekdayDayMonth(at, locale: locale), 'Mon, 19 Oct');
      expect(
        DateLabel.dayMonth(at, locale: locale, withTime: true),
        '19 Oct 05:03',
      );
      expect(
        DateLabel.dayMonthYear(at, locale: locale, withTime: true),
        '19 Oct 2026 05:03',
      );
      expect(
        DateLabel.shortWeekdayDayMonth(at, locale: locale, withTime: true),
        'Mon 19 Oct, 05:03',
      );
    });
  }

  for (final locale in ['de', 'ja']) {
    test('$locale uses intl skeleton order and punctuation for every date', () {
      expect(
        DateLabel.dayMonth(at, locale: locale),
        DateFormat.MMMd(locale).format(at),
      );
      expect(
        DateLabel.monthDay(at, locale: locale),
        DateFormat.MMMd(locale).format(at),
      );
      expect(
        DateLabel.dayMonthYear(at, locale: locale),
        DateFormat.yMMMd(locale).format(at),
      );
      expect(
        DateLabel.weekdayDayMonth(at, locale: locale),
        DateFormat.MMMMEEEEd(locale).format(at),
      );
      expect(
        DateLabel.weekdayDayMonthYear(at, locale: locale),
        DateFormat.yMMMMEEEEd(locale).format(at),
      );
      expect(
        DateLabel.shortWeekdayDayMonth(at, locale: locale),
        DateFormat.MMMEd(locale).format(at),
      );
      expect(
        DateLabel.dayMonth(at, locale: locale, withTime: true),
        DateFormat.MMMd(locale).add_Hm().format(at),
      );
      expect(
        DateLabel.dayMonthYear(at, locale: locale, withTime: true),
        DateFormat.yMMMd(locale).add_Hm().format(at),
      );
      expect(
        DateLabel.shortWeekdayDayMonth(at, locale: locale, withTime: true),
        DateFormat.MMMEd(locale).add_Hm().format(at),
      );
    });
  }

  test('all date patterns fall back safely in a fresh isolate', () async {
    final labels = await Isolate.run(() {
      final at = DateTime(2026, 10, 19, 5, 3);
      Intl.defaultLocale = 'ja';
      final defaultLabel = DateLabel.dayMonth(at);
      return [
        defaultLabel,
        for (final locale in ['de', 'ja', 'not_a_locale', '[en-XA]']) ...[
          DateLabel.dayMonth(at, locale: locale),
          DateLabel.monthDay(at, locale: locale),
          DateLabel.dayMonthYear(at, locale: locale),
          DateLabel.weekdayDayMonth(at, locale: locale),
          DateLabel.weekdayDayMonthYear(at, locale: locale),
          DateLabel.shortWeekdayDayMonth(at, locale: locale),
          DateLabel.dayMonth(at, locale: locale, withTime: true),
          DateLabel.dayMonthYear(at, locale: locale, withTime: true),
          DateLabel.shortWeekdayDayMonth(at, locale: locale, withTime: true),
        ],
      ];
    });
    expect(labels, [
      '19 Oct',
      for (var i = 0; i < 4; i++) ...[
        '19 Oct',
        'Oct 19',
        '19 Oct 2026',
        'Monday 19 October',
        'Monday 19 October 2026',
        'Mon, 19 Oct',
        '19 Oct 05:03',
        '19 Oct 2026 05:03',
        'Mon 19 Oct, 05:03',
      ],
    ]);
  });
}
