import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Rules 7 and 8: what leaves the account card, and the page strings in
/// every language.
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
  const deviceKeys = ['ways_this_device', 'ways_remove_current'];
  const plainKeys = [
    'ways_title',
    'ways_list_header',
    'ways_add_header',
    'ways_added',
    'ways_remove_label',
    'ways_remove_title',
    'ways_remove_body',
    'ways_remove_button',
    'ways_error_cap',
    'ways_remove_failed',
    'ways_row_detail',
    'link_add_apple',
    'link_add_google',
  ];
  const gone = ['link_header', 'link_body', 'providers_label'];

  test('rule 8: every page key, with its device variants, in every '
      'language', () {
    expect(files, hasLength(greaterThanOrEqualTo(15)));
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

  test('rule 7 and rule 8: the add rows text and the ways label line leave '
      'every language and the account card', () {
    for (final file in files) {
      final account = accountBlock(file);
      for (final key in gone) {
        expect(account.containsKey(key), isFalse, reason: '${file.path} $key');
      }
    }
    final card = File(
      'lib/features/account/presentation/account_screen.dart',
    ).readAsStringSync();
    expect(card, isNot(contains('_AddProviderRows')));
    expect(card, isNot(contains('account_providers_label')));
    expect(card, contains('signInMethodsPath'));
  });

  test('rule 8: Delete account is never on the page', () {
    final page = File(
      'lib/features/account/presentation/sign_in_methods_screen.dart',
    ).readAsStringSync();
    expect(page, isNot(contains('account_delete')));
    expect(page, isNot(contains('/settings/account/delete')));
  });

  test('rule 3: the This phone marker is a quiet second line, with no face '
      'and no badge on the page', () {
    final page = File(
      'lib/features/account/presentation/sign_in_methods_screen.dart',
    ).readAsStringSync();
    expect(page, isNot(contains('AppBadge')));
    expect(page, isNot(contains('FaceWidget')));
    expect(page, contains('account_ways_row_detail'));
  });
}
