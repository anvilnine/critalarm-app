import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _strings() =>
    jsonDecode(File('assets/translations/en.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final strings = _strings();
  final reminders = strings['local_reminders'] as Map<String, dynamic>;

  test('has every key the spec names for ideas 21 and 22', () {
    for (final key in [
      'review_title_1',
      'review_body_1',
      'review_title_2',
      'review_body_2',
      'review_action',
      'feedback_title_1',
      'feedback_body_1',
      'feedback_title_2',
      'feedback_body_2',
      'store_app_store',
      'store_google_play',
    ]) {
      expect(reminders, contains(key), reason: key);
    }
  });

  test('the fire drill pool has ten titles and ten bodies', () {
    for (var i = 1; i <= 10; i++) {
      expect(reminders, contains('drill_title_$i'));
      expect(reminders, contains('drill_body_$i'));
    }
  });

  test('every count uses the one and other forms', () {
    for (final key in [
      'drill_title_1',
      'drill_body_2',
      'drill_title_3',
      'drill_title_5',
      'drill_title_8',
      'backup_title',
      'morning_body',
      'ring_last_test',
    ]) {
      final value = reminders[key];
      expect(value, isA<Map<String, dynamic>>(), reason: key);
      expect(
        (value as Map<String, dynamic>).keys,
        containsAll(<String>['one', 'other']),
        reason: key,
      );
    }
  });

  test('the Pro sheet has its Remind me later label', () {
    final asks = strings['asks'] as Map<String, dynamic>;
    expect(asks['pro_later'], 'Remind me later');
  });

  test('the rings bullet is gone: every plan repeats', () {
    final asks = strings['asks'] as Map<String, dynamic>;
    expect(asks.containsKey('pro_bullet_rings'), isFalse);
  });

  test('no string carries a long dash', () {
    final raw = File('assets/translations/en.json').readAsStringSync();
    expect(raw.contains('\u2014'), isFalse);
    expect(raw.contains('\u2013'), isFalse);
  });
}
