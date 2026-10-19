import 'dart:convert';
import 'dart:io';

import 'l10n_parity.dart';

const _plain = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
const _accented = 'ÅƁÇÐÉƑĜĤÎĴĶĻḾÑÖÞǪŔŠŢÛṼŴẊÝŽåƀçðéƒĝĥîĵķļḿñöþǫŕšţûṽŵẋýž';

String pseudoValue(String value, List<String> keepWords) {
  final words = keepWords.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final protected = RegExp([
    placeholderPattern.pattern,
    ...words.map((word) => keepWordPattern(word).pattern),
  ].join('|'));
  String accent(String text) => text.split('').map((letter) {
    final index = _plain.indexOf(letter);
    return index < 0 ? letter : _accented[index];
  }).join();

  final result = StringBuffer('[');
  var offset = 0;
  for (final match in protected.allMatches(value)) {
    result
      ..write(accent(value.substring(offset, match.start)))
      ..write(match.group(0));
    offset = match.end;
  }
  result.write(accent(value.substring(offset)));
  // Brackets count towards the 140 percent target. Short and empty strings
  // necessarily grow by more than 40 percent.
  final padding = (value.length * 1.4).ceil() - result.length - 1;
  if (padding > 0) result.write('~' * padding);
  result.write(']');
  return result.toString();
}

Map<String, dynamic> pseudoTranslations(
  Map<String, dynamic> source,
  List<String> keepWords,
) => source.map((key, value) {
  if (value is Map<String, dynamic>) {
    return MapEntry(key, pseudoTranslations(value, keepWords));
  }
  if (value is! String) {
    throw FormatException('$key: expected a string or object');
  }
  return MapEntry(key, pseudoValue(value, keepWords));
});

File generatePseudoLocale(Directory directory, List<String> keepWords) {
  final source = readTranslation(File('${directory.path}/en.json'));
  final output = File('${directory.path}/en-XA.json');
  final values = pseudoTranslations(source, keepWords);
  final json = const JsonEncoder.withIndent('  ').convert(values);
  output.writeAsStringSync('$json\n');
  return output;
}

// Generate before starting a debug capture:
// fvm dart run tool/l10n_pseudo.dart
// fvm flutter run --debug --dart-define=PSEUDO_LOCALE=true
void main(List<String> arguments) {
  if (arguments.length > 2) {
    stderr.writeln(
      'Usage: l10n_pseudo.dart [translations-directory] [keep-file]',
    );
    exitCode = 64;
    return;
  }
  try {
    final output = generatePseudoLocale(
      Directory(arguments.isEmpty ? 'assets/translations' : arguments[0]),
      readKeepWords(
        File(arguments.length < 2 ? 'tool/l10n_keep.txt' : arguments[1]),
      ),
    );
    stdout.writeln('Generated ${output.path}.');
  } on Object catch (error) {
    stderr.writeln('Pseudo-locale generation FAILED: $error');
    exitCode = 1;
  }
}
