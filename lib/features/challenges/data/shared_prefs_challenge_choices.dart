import 'dart:async';

import 'package:critalarm/features/challenges/domain/challenge_choices.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [ChallengeChoices] in the app's preferences, where the Android card and
/// the iOS app can read the flag with no Dart running.
///
/// A key that holds something of the wrong type reads as not there.
class SharedPrefsChallengeChoices implements ChallengeChoices {
  SharedPrefsChallengeChoices(this._prefs);

  final SharedPreferences _prefs;
  final _changes = StreamController<void>.broadcast();

  String? _string(String key) {
    try {
      return _prefs.getString(key);
    } on Object catch (_) {
      return null;
    }
  }

  bool _isTrue(String key) {
    try {
      return _prefs.getBool(key) ?? false;
    } on Object catch (_) {
      return false;
    }
  }

  @override
  ChallengeKind? choiceFor(String topic) => ChallengeKind.fromId(
    _string('${ChallengeChoices.choiceKeyPrefix}$topic'),
  );

  @override
  Map<String, ChallengeKind> get choices {
    const prefix = ChallengeChoices.choiceKeyPrefix;
    final found = <String, ChallengeKind>{};
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final kind = ChallengeKind.fromId(_string(key));
      if (kind != null) found[key.substring(prefix.length)] = kind;
    }
    return found;
  }

  @override
  Future<void> setChoice(String topic, ChallengeKind? kind) async {
    final key = '${ChallengeChoices.choiceKeyPrefix}$topic';
    if (kind == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, kind.id);
    }
    _changes.add(null);
  }

  @override
  ChallengeKind? get defaultForNewTopics =>
      ChallengeKind.fromId(_string(ChallengeChoices.defaultKey));

  @override
  Future<void> setDefaultForNewTopics(ChallengeKind? kind) async {
    if (kind == null) {
      await _prefs.remove(ChallengeChoices.defaultKey);
    } else {
      await _prefs.setString(ChallengeChoices.defaultKey, kind.id);
    }
    _changes.add(null);
  }

  @override
  Future<void> applyDefaultTo(String newTopic) =>
      setChoice(newTopic, defaultForNewTopics);

  @override
  Future<void> forgetTopic(String topic) => setChoice(topic, null);

  @override
  Set<String> get flaggedTopics {
    const prefix = ChallengeChoices.owedKeyPrefix;
    return {
      for (final key in _prefs.getKeys())
        if (key.startsWith(prefix) && _isTrue(key))
          key.substring(prefix.length),
    };
  }

  @override
  bool isFlagged(String topic) =>
      _isTrue('${ChallengeChoices.owedKeyPrefix}$topic');

  @override
  Future<void> writeFlag(String topic, {required bool isOwed}) async {
    final key = '${ChallengeChoices.owedKeyPrefix}$topic';
    // No key reads as "not owed" on both platforms, so a cleared flag
    // leaves nothing behind.
    if (isOwed) {
      await _prefs.setBool(key, true);
    } else {
      await _prefs.remove(key);
    }
  }

  @override
  Stream<void> get changes => _changes.stream;

  Future<void> dispose() => _changes.close();
}
