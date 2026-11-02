import 'dart:convert';
import 'dart:io';

const pluralForms = {'zero', 'one', 'two', 'few', 'many', 'other'};
const requiredPluralForms = <String, Set<String>>{
  'en': {'one', 'other'},
  'de': {'one', 'other'},
  'es': {'one', 'other'},
  'fr': {'one', 'other'},
  'pt-BR': {'one', 'other'},
  'ja': {'other'},
  'ko': {'other'},
  'zh-Hans': {'other'},
};

final placeholderPattern = RegExp(r'\{([A-Za-z_][A-Za-z0-9_]*)?\}');

List<String> readKeepWords(File file) => file
    .readAsLinesSync()
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty)
    .toSet()
    .toList();

Map<String, dynamic> readTranslation(File file) {
  final value = jsonDecode(file.readAsStringSync());
  if (value is! Map<String, dynamic>) {
    throw const FormatException('expected a JSON object');
  }
  return value;
}

Set<String> namedPlaceholders(String value) => placeholderPattern
    .allMatches(value)
    .where((match) => match.group(1) != null)
    .map((match) => match.group(0)!)
    .toSet();

int positionalPlaceholders(String value) => placeholderPattern
    .allMatches(value)
    .where((match) => match.group(1) == null)
    .length;

// Boundaries prevent Crit matching Critical. Longest phrases are protected
// first by the pseudo generator; counts here also cover repeated keep words.
RegExp keepWordPattern(String word) => RegExp(
  '(?<![A-Za-z0-9_])${RegExp.escape(word)}(?![A-Za-z0-9_])',
);

int keepWordCount(String value, String word) =>
    keepWordPattern(word).allMatches(value).length;

bool _isPlural(Map<String, dynamic> value) =>
    value.isNotEmpty && value.keys.every(pluralForms.contains);

List<String> checkTranslationsDirectory(
  Directory directory, {
  required List<String> keepWords,
}) {
  final errors = <String>[];
  Map<String, dynamic> english;
  try {
    english = readTranslation(File('${directory.path}/en.json'));
  } on FormatException catch (error) {
    return ['en: invalid JSON: ${error.message}'];
  } on FileSystemException catch (error) {
    return ['en: ${error.message}'];
  }

  void compare(
    String locale,
    Map<String, dynamic> source,
    Map<String, dynamic> target,
    String parent,
  ) {
    String path(String key) => parent.isEmpty ? key : '$parent.$key';
    void fail(String key, String message) =>
        errors.add('$locale: ${path(key)}: $message');

    final plural = _isPlural(source);
    final required =
        requiredPluralForms[locale] ??
        (locale == 'en-XA' ? requiredPluralForms['en']! : source.keys.toSet());
    for (final key in source.keys) {
      if (!target.containsKey(key) && (!plural || required.contains(key))) {
        fail(key, plural ? 'missing plural form' : 'missing key');
      }
    }
    if (plural) {
      for (final key in required.difference(source.keys.toSet())) {
        if (!target.containsKey(key)) fail(key, 'missing plural form');
      }
    }
    bool isAllowedForm(String key) =>
        plural && required.contains(key) && pluralForms.contains(key);
    for (final key in target.keys) {
      if (!source.containsKey(key) && !isAllowedForm(key)) {
        fail(key, 'extra key');
      }
    }
    for (final entry in target.entries) {
      final key = entry.key;
      if (!source.containsKey(key) && !isAllowedForm(key)) {
        continue;
      }
      // A locale-only plural form has the same contract as English other.
      final original = source[key] ?? (plural ? source['other'] : null);
      final translated = entry.value;
      if (original is Map<String, dynamic>) {
        if (translated is Map<String, dynamic>) {
          compare(locale, original, translated, path(key));
        } else {
          fail(key, 'expected an object');
        }
      } else if (original is! String || translated is! String) {
        fail(key, 'expected a string');
      } else {
        final expected = namedPlaceholders(original);
        final actual = namedPlaceholders(translated);
        if (expected.difference(actual).isNotEmpty ||
            actual.difference(expected).isNotEmpty) {
          fail(
            key,
            'named placeholders differ '
            '(${(expected.toList()..sort()).join(', ')} vs '
            '${(actual.toList()..sort()).join(', ')})',
          );
        }
        final expectedCount = positionalPlaceholders(original);
        final actualCount = positionalPlaceholders(translated);
        if (expectedCount != actualCount) {
          fail(
            key,
            'positional placeholders differ '
            '($expectedCount vs $actualCount)',
          );
        }
        for (final word in keepWords) {
          final count = keepWordCount(original, word);
          if (count > 0 && keepWordCount(translated, word) != count) {
            fail(key, 'keep word "$word" must appear unchanged');
          }
        }
      }
    }
  }

  try {
    final files =
        directory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final locale = file.uri.pathSegments.last.replaceFirst(
        RegExp(r'\.json$'),
        '',
      );
      try {
        compare(locale, english, readTranslation(file), '');
      } on FormatException catch (error) {
        errors.add('$locale: invalid JSON: ${error.message}');
      } on FileSystemException catch (error) {
        errors.add('$locale: ${error.message}');
      }
    }
  } on FileSystemException catch (error) {
    errors.add(error.message);
  }
  return errors;
}

// Optional fixture paths let unit tests exercise the real CLI without touching
// the app assets: fvm dart run tool/l10n_parity.dart <directory> <keep-file>.
void main(List<String> arguments) {
  if (arguments.length > 2) {
    stderr.writeln(
      'Usage: l10n_parity.dart [translations-directory] [keep-file]',
    );
    exitCode = 64;
    return;
  }
  try {
    final errors = checkTranslationsDirectory(
      Directory(arguments.isEmpty ? 'assets/translations' : arguments[0]),
      keepWords: readKeepWords(
        File(arguments.length < 2 ? 'tool/l10n_keep.txt' : arguments[1]),
      ),
    );
    if (errors.isEmpty) {
      stdout.writeln('Translation parity check passed.');
    } else {
      stderr
        ..writeln(errors.join('\n'))
        ..writeln('Translation parity check FAILED.');
      exitCode = 1;
    }
  } on FileSystemException catch (error) {
    stderr.writeln('Translation parity check FAILED: ${error.message}');
    exitCode = 1;
  }
}
