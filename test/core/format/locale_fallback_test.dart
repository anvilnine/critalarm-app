import 'dart:isolate';

import 'package:critalarm/core/format/number_format.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  test('fresh isolates format safely before date symbols are loaded', () async {
    // A separate isolate has no date initialization from the shared helper.
    final values = await Isolate.run(() async {
      Intl.defaultLocale = 'de';
      final defaultLocale = currentFormatLocale();
      final before = currentFormatLocale('en');
      final unsupported = currentFormatLocale('not_a_locale');
      final unloaded = currentFormatLocale('de');
      final date = DateTime(2026, 3, 4, 18, 5);
      final results = [
        defaultLocale,
        before,
        unsupported,
        unloaded,
        DateFormat('d MMMM HH:mm', before).format(date),
        NumberFormat.decimalPattern(before).format(1234.5),
        DateFormat('d MMMM', unloaded).format(date),
        NumberFormat.decimalPattern(unsupported).format(1.5),
      ];
      await initializeDateFormatting('de');
      final after = currentFormatLocale('de');
      return [
        ...results,
        after,
        DateFormat('d MMMM HH:mm', after).format(date),
        NumberFormat.decimalPattern(after).format(1234.5),
      ];
    });

    expect(values, [
      'en_US',
      'en_US',
      'en_US',
      'en_US',
      '4 March 18:05',
      '1,234.5',
      '4 March',
      '1.5',
      'de',
      '4 März 18:05',
      '1.234,5',
    ]);
  });
}
