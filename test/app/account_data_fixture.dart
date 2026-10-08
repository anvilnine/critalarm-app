import 'package:critalarm/core/account/account_tag.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Everything on the one list of what belongs to an account, as a phone
/// holds it after some use on [accountId], with the own sounds the list
/// leaves alone next to it.
Map<String, Object> accountDataFor(String accountId) {
  final tag = accountTagFor(accountId)!;
  return {
    // The three drops the wipe always made.
    'msg_sync_last_id.prod': 'm_1',
    'ack_queue_v1': '[]',
    'search_recent_queries': ['prod'],
    // Wake-up challenges.
    'topic_challenge.prod': 'type_topic_name',
    'topic_challenge.nas': 'type_topic_name',
    'topic_challenge_default': 'type_topic_name',
    'topic_challenge_owed.prod': true,
    'topic_challenge_owed.nas': true,
    'topic_challenge_owed_for': tag,
    // Alarm looks.
    'alarm_style_default': 'minimal',
    'alarm_style_topic.prod': 'minimal',
    'alarm_style_open_when_last_sure': tag,
    // The own sounds lock.
    'alarm_sound_own_locked': false,
    'alarm_sound_own_locked_for': tag,
    ...ownSounds,
  };
}

/// A person's own sounds and what rings where. Never on the list.
const Map<String, Object> ownSounds = {
  'alarm_sound_default': 'user_1',
  'alarm_sound_per_topic': '{"prod":"user_2"}',
  'alarm_sound_user_list': '[{"id":"user_1"},{"id":"user_2"}]',
};

/// Writes [values] into [prefs], for a harness that has prefs already.
Future<void> writeAll(
  SharedPreferences prefs,
  Map<String, Object> values,
) async {
  for (final MapEntry(:key, :value) in values.entries) {
    switch (value) {
      case final bool flag:
        await prefs.setBool(key, flag);
      case final String text:
        await prefs.setString(key, text);
      case final List<String> list:
        await prefs.setStringList(key, list);
      default:
        throw ArgumentError.value(value, key);
    }
  }
}

/// The prefixes and keys of everything on the list.
const _accountKeyPrefixes = [
  'msg_sync_last_id.',
  'topic_challenge.',
  'topic_challenge_owed.',
  'alarm_style_topic.',
];
const _accountKeys = [
  'ack_queue_v1',
  'topic_challenge_default',
  'topic_challenge_owed_for',
  'alarm_style_default',
  'alarm_style_open_when_last_sure',
  'alarm_sound_own_locked',
  'alarm_sound_own_locked_for',
];

/// The keys in [prefs] that are on the list. Empty after a wipe.
List<String> accountKeysLeft(SharedPreferences prefs) => [
  for (final key in prefs.getKeys())
    if (_accountKeys.contains(key) || _accountKeyPrefixes.any(key.startsWith))
      key,
  if ((prefs.getStringList('search_recent_queries') ?? const []).isNotEmpty)
    'search_recent_queries',
]..sort();

void expectAccountDataGone(SharedPreferences prefs) =>
    expect(accountKeysLeft(prefs), isEmpty);

void expectAccountDataKept(SharedPreferences prefs) =>
    expect(accountKeysLeft(prefs), hasLength(14));

void expectOwnSoundsKept(SharedPreferences prefs) {
  for (final MapEntry(:key, :value) in ownSounds.entries) {
    expect(prefs.getString(key), value, reason: key);
  }
}
