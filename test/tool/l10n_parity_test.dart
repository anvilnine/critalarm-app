import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/l10n_parity.dart';

void main() {
  late Directory directory;
  late File keepFile;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('l10n_parity_');
    keepFile = File('${directory.path}/keep.txt')
      ..writeAsStringSync('Crit Alarm\nCrit\ncurl\n');
  });
  tearDown(() => directory.deleteSync(recursive: true));

  void write(String locale, Map<String, dynamic> values) {
    File('${directory.path}/$locale.json')
        .writeAsStringSync(jsonEncode(values));
  }

  List<String> check() => checkTranslationsDirectory(
    directory,
    keepWords: readKeepWords(keepFile),
  );

  test('English alone passes', () {
    write('en', {'nested': {'title': 'Hello'}});
    expect(check(), isEmpty);
  });

  // Rule: identical non-plural key sets. No other rule is violated.
  test('missing key reports its full path', () {
    write('en', {'nested': {'title': 'Hello'}});
    write('de', {'nested': <String, dynamic>{}});
    expect(check(), ['de: nested.title: missing key']);
  });

  // Rule: identical non-plural key sets. No other rule is violated.
  test('extra key reports its full path', () {
    write('en', {'nested': {'title': 'Hello'}});
    write('de', {'nested': {'title': 'Hallo', 'extra': 'Extra'}});
    expect(check(), ['de: nested.extra: extra key']);
  });

  // Rule: same named placeholder set only.
  test('dropped named placeholder fails', () {
    write('en', {'title': 'Hello {name}'});
    write('de', {'title': 'Hallo'});
    expect(check(), ['de: title: named placeholders differ ({name} vs )']);
  });

  // Rule: same positional placeholder count only.
  test('dropped positional placeholder fails', () {
    write('en', {'title': 'Hello {} {}'});
    write('de', {'title': 'Hallo {}'});
    expect(check(), ['de: title: positional placeholders differ (2 vs 1)']);
  });

  // Rule: locale-required plural forms only, not generic missing keys.
  test('missing plural form fails once', () {
    write('en', {'items': {'one': 'Item', 'other': 'Items'}});
    write('de', {'items': {'other': 'Dinge'}});
    expect(check(), ['de: items.one: missing plural form']);
  });

  // Rule: keep words must retain their exact spelling only.
  test('changed keep word fails', () {
    write('en', {'title': 'Run curl'});
    write('de', {'title': 'Starte CURL'});
    expect(check(), ['de: title: keep word "curl" must appear unchanged']);
  });

  test('all listed locales enforce their plural forms', () {
    write('en', {'items': {'one': 'Item', 'other': 'Items'}});
    for (final locale in ['en', 'de', 'es', 'fr', 'pt-BR']) {
      write(locale, {'items': {'one': 'Item', 'other': 'Items'}});
    }
    for (final locale in ['ja', 'ko', 'zh-Hans']) {
      write(locale, {'items': {'other': 'Items'}});
    }
    expect(check(), isEmpty);
    write('ja', {'items': {'one': 'Item', 'other': 'Items'}});
    expect(check(), isEmpty);
  });

  test('Asian locales still require other', () {
    write('en', {'items': {'one': 'Item', 'other': 'Items'}});
    write('ko', {'items': {'one': 'Item'}});
    expect(check(), ['ko: items.other: missing plural form']);
  });


  // Rule: plural forms do not permit unrelated extra keys.
  test('extra plural form fails key parity', () {
    write('en', {'items': {'one': 'Item', 'other': 'Items'}});
    write('de', {
      'items': {'one': 'Ding', 'other': 'Dinge', 'few': 'Dinge'},
    });
    expect(check(), ['de: items.few: extra key']);
  });

  test('English plural forms are validated too', () {
    write('en', {'items': {'other': 'Items'}});
    expect(check(), ['en: items.one: missing plural form']);
  });

  test('placeholder order and repeated named arguments may change', () {
    write('en', {'title': '{first} {last} {first} {}'});
    write('de', {'title': '{} {last} {first}'});
    expect(check(), isEmpty);
  });

  test('keep phrases use word boundaries and preserve occurrence counts', () {
    write('en', {'title': 'Crit Alarm, Crit, curl, curl. Critical.'});
    write('de', {'title': 'Crit Alarm, Crit, curl, curl. Kritisch.'});
    expect(check(), isEmpty);
    write('de', {'title': 'Crit Alarm, Crit, curl. Kritisch.'});
    expect(check(), ['de: title: keep word "curl" must appear unchanged']);
  });

  test('non-string values produce a readable error', () {
    write('en', {'title': 'Hello'});
    write('de', {'title': 42});
    expect(check(), ['de: title: expected a string']);
  });

  test('malformed JSON produces a readable error', () {
    write('en', {'title': 'Hello'});
    File('${directory.path}/de.json').writeAsStringSync('{');
    expect(check().single, startsWith('de: invalid JSON:'));
  });

  test('CLI exits nonzero for a broken fixture and zero for English only',
      () async {
    write('en', {'title': 'Hello'});
    write('de', <String, dynamic>{});
    Future<ProcessResult> run() => Process.run('fvm', [
      'dart', 'run', 'tool/l10n_parity.dart', directory.path, keepFile.path,
    ]);
    final broken = await run();
    expect(broken.exitCode, 1);
    expect(broken.stderr, contains('de: title: missing key'));
    File('${directory.path}/de.json').deleteSync();
    final valid = await run();
    expect(valid.exitCode, 0);
    expect(valid.stdout, contains('Translation parity check passed.'));
  });
}
