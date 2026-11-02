import 'package:critalarm/core/l10n/upper_for_locale.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('upperForLocale', () {
    test('Turkish maps i to dotted capital and dotless i to I', () {
      const tr = Locale('tr');
      expect(upperForLocale('iyi', tr), 'İYİ');
      expect(upperForLocale('ışık', tr), 'IŞIK');
      expect(upperForLocale('alarm kapat', tr), 'ALARM KAPAT');
      expect(upperForLocale('Türkçe', tr), 'TÜRKÇE');
    });

    test('Turkish applies to a regional tag too', () {
      expect(upperForLocale('iş', const Locale('tr', 'TR')), 'İŞ');
    });

    test('other languages use plain toUpperCase', () {
      expect(upperForLocale('in time', const Locale('en')), 'IN TIME');
      expect(upperForLocale('ısı', const Locale('de')), 'ISI');
      expect(upperForLocale('ひらがな', const Locale('ja')), 'ひらがな');
    });
  });
}
