import 'dart:convert';
import 'dart:io';

import 'package:critalarm/core/l10n/app_locales.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization/src/easy_localization_controller.dart';
import 'package:easy_localization/src/localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../tool/l10n_parity.dart';
import '../../tool/l10n_pseudo.dart';

void main() {
  final keep = readKeepWords(File('tool/l10n_keep.txt'));

  test('every real English value expands and preserves tokens', () {
    final english = readTranslation(File('assets/translations/en.json'));
    final pseudo = pseudoTranslations(english, keep);
    void visit(Map<String, dynamic> source, Map<String, dynamic> result) {
      expect(result.keys, unorderedEquals(source.keys));
      for (final entry in source.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          visit(value, result[entry.key] as Map<String, dynamic>);
        } else {
          final text = value as String;
          final expanded = result[entry.key] as String;
          expect(expanded.length, greaterThan(text.length), reason: entry.key);
          expect(
            expanded.length,
            greaterThanOrEqualTo((text.length * 1.4).ceil()),
          );
          expect(expanded, startsWith('['));
          expect(expanded, endsWith(']'));
          expect(namedPlaceholders(expanded), namedPlaceholders(text));
          expect(
            positionalPlaceholders(expanded),
            positionalPlaceholders(text),
          );
          for (final word in keep) {
            expect(keepWordCount(expanded, word), keepWordCount(text, word));
          }
        }
      }
    }
    visit(english, pseudo);
  });

  test('accents letters but leaves adjacent protected tokens untouched', () {
    final value = pseudoValue('Crit Alarm Crit curl {name}{} Hello', keep);
    expect(value, contains('Crit Alarm Crit curl {name}{}'));
    expect(value, contains('Ĥéļļö'));
    expect(pseudoValue('', keep), '[]');
  });

  test('generator writes en-XA with valid parity', () {
    final directory = Directory.systemTemp.createTempSync('l10n_pseudo_');
    addTearDown(() => directory.deleteSync(recursive: true));
    File('${directory.path}/en.json').writeAsStringSync(jsonEncode({
      'title': 'Crit Alarm {name} {}',
      'items': {'one': 'Item', 'other': 'Items'},
    }));
    final output = generatePseudoLocale(directory, keep);
    expect(output.path, '${directory.path}/en-XA.json');
    expect(readTranslation(output)['title'], contains('Crit Alarm {name} {}'));
    expect(checkTranslationsDirectory(directory, keepWords: keep), isEmpty);
  });

  test('release and profile configurations never list pseudo locale', () {
    expect(localesForBuild(isDebug: false, pseudoRequested: true),
        [const Locale('en')]);
    expect(localesForBuild(isDebug: false, pseudoRequested: false),
        [const Locale('en')]);
    expect(localesForBuild(isDebug: true, pseudoRequested: false),
        [const Locale('en')]);
    expect(localesForBuild(isDebug: true, pseudoRequested: true),
        [const Locale('en'), const Locale('en', 'XA')]);
  });

  test('generated pseudo file loads without a widget tree', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final directory = Directory.systemTemp.createTempSync('l10n_load_');
    addTearDown(() => directory.deleteSync(recursive: true));
    File('${directory.path}/en.json').writeAsStringSync(
      File('assets/translations/en.json').readAsStringSync(),
    );
    generatePseudoLocale(directory, keep);
    final controller = EasyLocalizationController(
      forceLocale: const Locale('en', 'XA'),
      supportedLocales: localesForBuild(isDebug: true, pseudoRequested: true),
      fallbackLocale: const Locale('en'),
      path: directory.path,
      useOnlyLangCode: false,
      useFallbackTranslations: true,
      saveLocale: false,
      assetLoader: const _FileAssetLoader(),
      onLoadError: (e) => throw e,
    );
    await controller.loadTranslations();
    Localization.load(
      const Locale('en', 'XA'),
      translations: controller.translations,
      fallbackTranslations: controller.fallbackTranslations,
    );
    expect('app.title'.tr(), startsWith('[Crit Alarm'));
    controller.dispose();
  });
}

// Read the generated file through easy_localization, without a widget test or
// requiring a generated asset to exist before Flutter builds the test bundle.
class _FileAssetLoader extends AssetLoader {
  const _FileAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      readTranslation(File('$path/${locale.toLanguageTag()}.json'));
}
