import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every string in the English file, keyed by its dotted path.
Map<String, String> _strings() {
  final json =
      jsonDecode(File('assets/translations/en.json').readAsStringSync())
          as Map<String, dynamic>;
  final out = <String, String>{};
  void walk(String prefix, Map<String, dynamic> node) {
    node.forEach((k, v) {
      final key = prefix.isEmpty ? k : '$prefix.$k';
      if (v is Map<String, dynamic>) {
        walk(key, v);
      } else {
        out[key] = '$v';
      }
    });
  }

  walk('', json);
  return out;
}

/// Other senses of the word "hosted". A string may hold these and nothing
/// else spelled "hosted". Add a pattern here, with the sense, before a new
/// string uses the word for something that is not the paid plan.
final _otherSenses = <RegExp>[
  // The user runs the server.
  RegExp('self-hosted', caseSensitive: false),
  // Sound packs the store delivers.
  RegExp('store-hosted', caseSensitive: false),
  RegExp('apple-hosted', caseSensitive: false),
  RegExp('google-hosted', caseSensitive: false),
  RegExp('github-hosted', caseSensitive: false),
];

String _withoutPlaceholders(String value) =>
    value.replaceAll(RegExp(r'\{[A-Za-z0-9_]*\}'), '');

void main() {
  final strings = _strings();

  test('no visible string names the paid plan Hosted', () {
    final offenders = <String>[];
    strings.forEach((key, value) {
      var text = _withoutPlaceholders(value);
      for (final sense in _otherSenses) {
        text = text.replaceAll(sense, '');
      }
      if (RegExp(r'\bhosted\b', caseSensitive: false).hasMatch(text)) {
        offenders.add('$key: $value');
      }
    });
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('the allow list is used: self-hosted is still said somewhere', () {
    expect(strings['settings.server_self_hosted'], 'Self-hosted');
  });

  test('the plan is called Cloud', () {
    expect(strings['paywall_kit.name_hosted'], 'Cloud');
    expect(strings['settings.plan_pro'], 'Cloud');
  });

  test('no string calls the server we run Crit Alarm Cloud', () {
    final offenders = <String>[];
    strings.forEach((key, value) {
      if (RegExp('Crit Alarm Cloud', caseSensitive: false).hasMatch(value) &&
          // The plan itself may be named in full: "Crit Alarm Cloud is on."
          !const {
            'paywall.feedback_upgraded',
            'paywall.feedback_restored',
            'paywall_kit.done_hosted',
          }.contains(key)) {
        offenders.add('$key: $value');
      }
    });
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('no string says a phone is connected to, or uses, Cloud', () {
    final offenders = <String>[];
    final server = RegExp(
      r'(connect(ed|ing)? to|use|replaces) (crit alarm )?cloud\b',
      caseSensitive: false,
    );
    strings.forEach((key, value) {
      if (server.hasMatch(value)) offenders.add('$key: $value');
    });
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
