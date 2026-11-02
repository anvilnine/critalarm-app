import 'package:critalarm/core/l10n/app_locales.dart';
import 'package:critalarm/core/l10n/shipped_locales.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Locale _parse(String tag) => localeFromTag(tag);

void main() {
  String resolve(String phone) =>
      resolvePhoneLocales([_parse(phone)]).toLanguageTag();

  group('resolvePhoneLocales', () {
    test('Traditional regions without a script map to zh-Hant', () {
      expect(resolve('zh_TW'), 'zh-Hant');
      expect(resolve('zh_HK'), 'zh-Hant');
      expect(resolve('zh_MO'), 'zh-Hant');
    });

    test('script Hant maps to zh-Hant whatever the region', () {
      expect(resolve('zh_Hant_TW'), 'zh-Hant');
      expect(resolve('zh_Hant_CN'), 'zh-Hant');
      expect(resolve('zh_Hant'), 'zh-Hant');
    });

    test('other Chinese maps to zh-Hans', () {
      expect(resolve('zh_CN'), 'zh-Hans');
      expect(resolve('zh_Hans_SG'), 'zh-Hans');
      expect(resolve('zh_Hans_HK'), 'zh-Hans');
      expect(resolve('zh_SG'), 'zh-Hans');
      expect(resolve('zh'), 'zh-Hans');
    });

    test('everything else resolves as before', () {
      expect(resolve('pt_PT'), 'pt-BR');
      expect(resolve('pt_BR'), 'pt-BR');
      expect(resolve('es_MX'), 'es');
      expect(resolve('en_US'), 'en');
      expect(resolve('de_AT'), 'de');
      expect(resolve('sv_SE'), 'en');
    });

    test('an empty or missing list falls back to the first shipped locale', () {
      expect(resolvePhoneLocales(const []).toLanguageTag(), 'en');
      expect(resolvePhoneLocales(null).toLanguageTag(), 'en');
    });

    test('a later Chinese locale is folded too', () {
      final result = resolvePhoneLocales([_parse('sv_SE'), _parse('zh_TW')]);
      expect(result.toLanguageTag(), 'zh-Hant');
    });

    test('every shipped tag resolves to itself', () {
      for (final tag in shippedLocaleTags) {
        expect(resolve(tag), tag);
      }
    });
  });

  group('chinesePhoneStartLocale', () {
    test('is set when the first phone locale is Chinese', () {
      expect(
        chinesePhoneStartLocale([_parse('zh_TW')])?.toLanguageTag(),
        'zh-Hant',
      );
      expect(
        chinesePhoneStartLocale([
          _parse('zh_CN'),
          _parse('en_US'),
        ])?.toLanguageTag(),
        'zh-Hans',
      );
    });

    test('is null otherwise', () {
      expect(
        chinesePhoneStartLocale([_parse('en_US'), _parse('zh_TW')]),
        isNull,
      );
      expect(chinesePhoneStartLocale(const []), isNull);
    });
  });
}
