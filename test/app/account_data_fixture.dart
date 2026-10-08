import 'dart:io';
import 'dart:typed_data';

import 'package:critalarm/core/account/account_tag.dart';
import 'package:critalarm/features/incidents/data/own_look/file_own_look_store.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_scrim.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/own_look_store.dart';
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

/// A person's own alarm look as a phone holds it: the photo file in a
/// folder of its own, its record and the accent in [prefs]. On the list,
/// unlike own sounds: a photo is on screen for anyone holding the phone.
final class OwnLookOnDisk {
  OwnLookOnDisk._(this.prefs, this.root, this.store);

  final SharedPreferences prefs;
  final Directory root;
  final FileOwnLookStore store;

  /// Saves a photo and an accent through the real store, in a folder that
  /// is deleted when the test ends.
  static Future<OwnLookOnDisk> seed(SharedPreferences prefs) async {
    final root = await Directory.systemTemp.createTemp('own_look_test_');
    addTearDown(() async {
      if (root.existsSync()) await root.delete(recursive: true);
    });
    final store = FileOwnLookStore(prefs, () async => root);
    addTearDown(store.dispose);
    await store.savePhoto(
      Uint8List.fromList(List<int>.generate(64, (i) => i)),
      width: 4,
      height: 4,
      measure: const OwnPhotoMeasure(
        columns: 1,
        rows: 1,
        peaks: [200],
        lows: [10],
      ),
    );
    await store.setAccent('mint');
    return OwnLookOnDisk._(prefs, root, store);
  }

  /// Every file under the photo's folder, whatever it is called.
  List<String> get files => [
    if (root.existsSync())
      for (final entry in root.listSync(recursive: true))
        if (entry is File) entry.path,
  ];

  Future<void> expectKept() async {
    expect(files, hasLength(1));
    expect(prefs.getString(OwnLookStore.photoKey), isNotNull);
    expect(prefs.getString(OwnLookStore.accentKey), 'mint');
    expect(store.photo, isNotNull);
    expect(await store.readPhoto(), hasLength(64));
  }

  Future<void> expectGone() async {
    expect(files, isEmpty, reason: 'the photo file is still on the phone');
    expect(prefs.getString(OwnLookStore.photoKey), isNull);
    expect(prefs.getString(OwnLookStore.accentKey), isNull);
    expect(store.photo, isNull);
    expect(store.accentId, isNull);
    expect(await store.readPhoto(), isNull);
  }
}
