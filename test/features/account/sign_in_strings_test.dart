import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Rule 5: the strings for the reinstall states, in every language.
void main() {
  final files = Directory('assets/translations')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList();

  Map<String, dynamic> accountBlock(File file) =>
      (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)['account']
          as Map<String, dynamic>;

  const devices = ['', '_ipad', '_tablet', '_computer'];
  const deviceKeys = [
    'on_account_label',
    'on_account_alarms_ring',
    'on_account_alerts_arrive',
    'leave_title',
    'leave_warning',
  ];
  const plainKeys = [
    'on_account_email_hidden',
    'on_account_others',
    'on_account_status',
    'finish_sign_in',
    'use_different_account',
    'leave_button',
    'stay_button',
  ];

  test('rule 5: every language ships', () {
    expect(files, hasLength(greaterThanOrEqualTo(15)));
  });

  test('rule 5: the old dead-end error is gone from every language', () {
    for (final file in files) {
      final account = accountBlock(file);
      for (final suffix in devices) {
        expect(
          account.containsKey('error_other_identity$suffix'),
          isFalse,
          reason: file.path,
        );
      }
    }
  });

  test('rule 5: every new key, with its device variants, in every '
      'language', () {
    for (final file in files) {
      final account = accountBlock(file);
      for (final key in deviceKeys) {
        for (final suffix in devices) {
          expect(
            account['$key$suffix'],
            isNotNull,
            reason: '${file.path} $key',
          );
        }
      }
      for (final key in plainKeys) {
        expect(account[key], isNotNull, reason: '${file.path} $key');
      }
    }
  });

  test('rule 5: the English never says rung, belongs to, or sign out of '
      'that one first, and never rings beside leave', () {
    final en = File('assets/translations/en.json');
    final account = accountBlock(en);
    final text = [
      for (final key in [...deviceKeys, ...plainKeys])
        for (final suffix in deviceKeys.contains(key) ? devices : const [''])
          jsonEncode(account['$key$suffix']),
    ].join('\n').toLowerCase();
    expect(text, isNot(contains('rung')));
    expect(text, isNot(contains('belongs to')));
    expect(text, isNot(contains('sign out of that one first')));
    for (final suffix in devices) {
      final leave = jsonEncode(account['leave_warning$suffix']).toLowerCase();
      expect(leave, contains('sounding'));
      expect(leave, isNot(contains('ring')));
    }
  });
}
