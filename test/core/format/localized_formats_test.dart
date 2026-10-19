import 'dart:convert';
import 'dart:io';

import 'package:critalarm/core/format/number_format.dart';
import 'package:critalarm/core/format/when_label.dart';
import 'package:critalarm/features/history/presentation/history_formatting.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/history_preview.dart';
import 'package:critalarm/features/settings/presentation/sound_crop_screen.dart';
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  void load(String language, String file) {
    Localization.load(
      Locale(language),
      translations: Translations(
        jsonDecode(File(file).readAsStringSync()) as Map<String, dynamic>,
      ),
    );
  }

  setUpAll(() async {
    await initializeDateFormatting('de');
  });

  tearDown(() {
    load('en', 'assets/translations/en.json');
  });

  test('English durations retain spacing and padded seconds', () {
    load('en', 'assets/translations/en.json');
    expect(formatRingDuration(Duration.zero), '0 s');
    expect(formatRingDuration(const Duration(seconds: 44)), '44 s');
    expect(
      formatRingDuration(const Duration(minutes: 6, seconds: 2)),
      '6 min 02 s',
    );
    expect(formatCompactDuration(const Duration(minutes: 60)), '1 h');
    expect(formatCompactDuration(const Duration(minutes: 65)), '1 h 5 min');
    expect(formatNum(1.1999999999999993), '1.2');
    expect(formatNum(88), '88');
    expect(formatNum(-0.01), '0');
    expect(formatNum(1234.5), '1234.5');
    expect(formatClipLength(const Duration(milliseconds: 29500)), '29.5 s');
    expect(formatClipLength(const Duration(seconds: 2)), '2.0 s');
    expect(formatClipTime(const Duration(milliseconds: 42050)), '0:42.1');
    expect(historyPreviewAge(90), '90d');
  });

  test('German bundle controls dates, clock, numbers and unit ordering', () {
    load('de', 'test/core/format/fixtures/de.json');
    final sample = DateTime(2026, 3, 4, 18, 5);
    expect(
      DateFormat('d MMMM', currentFormatLocale()).format(sample),
      '4 März',
    );
    expect(DateFormat.jm(currentFormatLocale()).format(sample), '18:05');
    expect(
      formatWhen(
        at: sample,
        now: DateTime(2026, 3, 8),
        yesterday: 'Gestern',
      ),
      '4 März',
    );
    expect(
      formatWhenWithTime(
        at: sample,
        now: DateTime(2026, 3, 8),
        yesterday: 'Gestern',
      ),
      '4 März 18:05',
    );
    expect(
      formatRingDuration(const Duration(minutes: 6, seconds: 2)),
      '02 Sek., 6 Min.',
    );
    expect(
      formatCompactDuration(const Duration(minutes: 65)),
      '5 Min., 1 Std.',
    );
    expect(formatNum(29.5), '29,5');
    expect(formatNum(-0.01), '0');
    expect(formatNum(1234.5), '1234,5');
    expect(formatClipLength(const Duration(milliseconds: 29500)), '29,5 Sek.');
    expect(formatClipTime(const Duration(milliseconds: 42050)), '0:42,1');
    expect(historyPreviewAge(90), '90T');
  });

  test('pseudo metadata keeps English date and number symbols', () {
    Localization.load(
      const Locale('en', 'XA'),
      translations: Translations({
        'dart_format': {'locale': '[éñ]'},
      }),
    );
    expect(currentFormatLocale(), 'en');
    expect(formatNum(1.2), '1.2');
  });

  test('formatters read the bundle again after a language change', () {
    load('de', 'test/core/format/fixtures/de.json');
    expect(formatNum(1.2), '1,2');
    load('en', 'assets/translations/en.json');
    expect(formatNum(1.2), '1.2');
  });
}
