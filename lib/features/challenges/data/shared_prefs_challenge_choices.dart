import 'dart:async';

import 'package:critalarm/core/account/account_tag.dart';
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

  /// The tag of the account this phone is on, as [keepFlagsOnlyFor] was
  /// last told. Null until then, and while the phone has no account.
  String? _accountTag;

  /// Whether the flags on this phone were written for the account it is
  /// on.
  bool get _flagsAreOurs => noteIsForAccount(
    noteTag: _string(ChallengeChoices.owedAccountKey),
    accountTag: _accountTag,
  );

  /// Every flag key, set or not, whoever it was written for.
  List<String> get _flagKeys => [
    for (final key in _prefs.getKeys())
      if (key.startsWith(ChallengeChoices.owedKeyPrefix)) key,
  ];

  /// Takes every flag and their tag away. True when a flag was there.
  Future<bool> _dropFlags() async {
    final keys = _flagKeys;
    for (final key in keys) {
      await _prefs.remove(key);
    }
    await _prefs.remove(ChallengeChoices.owedAccountKey);
    return keys.isNotEmpty;
  }

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
  Future<void> forgetAll() async {
    for (final key in _prefs.getKeys().toList()) {
      if (key.startsWith(ChallengeChoices.choiceKeyPrefix)) {
        await _prefs.remove(key);
      }
    }
    await _prefs.remove(ChallengeChoices.defaultKey);
    await _dropFlags();
    _changes.add(null);
  }

  @override
  Future<bool> keepFlagsOnlyFor(String? accountTag) async {
    _accountTag = accountTag;
    if (accountTag == null) return false;
    if (_string(ChallengeChoices.owedAccountKey) == accountTag) return false;
    return _dropFlags();
  }

  @override
  Set<String> get flaggedTopics {
    if (!_flagsAreOurs) return const <String>{};
    const prefix = ChallengeChoices.owedKeyPrefix;
    return {
      for (final key in _prefs.getKeys())
        if (key.startsWith(prefix) && _isTrue(key))
          key.substring(prefix.length),
    };
  }

  @override
  bool isFlagged(String topic) =>
      _flagsAreOurs && _isTrue('${ChallengeChoices.owedKeyPrefix}$topic');

  @override
  Future<void> writeFlag(String topic, {required bool isOwed}) async {
    final key = '${ChallengeChoices.owedKeyPrefix}$topic';
    // No key reads as "not owed" on both platforms, so a cleared flag
    // leaves nothing behind.
    if (isOwed) {
      final tag = _accountTag;
      if (tag == null) throw StateError('No account to write the flag for');
      // Flags another account left behind never get this account's tag.
      if (!_flagsAreOurs) await _dropFlags();
      await _prefs.setBool(key, true);
      if (_string(ChallengeChoices.owedAccountKey) != tag) {
        await _prefs.setString(ChallengeChoices.owedAccountKey, tag);
      }
    } else {
      await _prefs.remove(key);
    }
  }

  @override
  Stream<void> get changes => _changes.stream;

  Future<void> dispose() => _changes.close();
}
