import 'dart:async';

import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_assignments.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_choices.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [AlarmStyleChoices] in the app's preferences.
///
/// A key that holds something of the wrong type reads as not there. Ids
/// are kept as written, known to this build or not.
class SharedPrefsAlarmStyleChoices implements AlarmStyleChoices {
  SharedPrefsAlarmStyleChoices(this._prefs);

  final SharedPreferences _prefs;
  final _changes = StreamController<void>.broadcast();

  String? _string(String key) {
    try {
      final value = _prefs.getString(key);
      return value == null || value.isEmpty ? null : value;
    } on Object catch (_) {
      return null;
    }
  }

  @override
  AlarmStyleAssignments get assignments {
    const prefix = AlarmStyleChoices.topicKeyPrefix;
    final perTopic = <String, String>{};
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final id = _string(key);
      if (id != null) perTopic[key.substring(prefix.length)] = id;
    }
    return AlarmStyleAssignments(
      defaultStyleId: _string(AlarmStyleChoices.defaultKey),
      perTopic: perTopic,
    );
  }

  Future<void> _write(String key, String? styleId) async {
    if (styleId == null || styleId.isEmpty) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, styleId);
    }
    _changes.add(null);
  }

  @override
  Future<void> setDefault(String? styleId) =>
      _write(AlarmStyleChoices.defaultKey, styleId);

  @override
  Future<void> setTopicStyle(String topic, String? styleId) =>
      _write('${AlarmStyleChoices.topicKeyPrefix}$topic', styleId);

  @override
  Future<void> forgetTopic(String topic) => setTopicStyle(topic, null);

  @override
  bool get wasOpenWhenLastSure {
    try {
      return _prefs.getBool(AlarmStyleChoices.openWhenLastSureKey) ?? false;
    } on Object catch (_) {
      return false;
    }
  }

  @override
  Future<void> writeOpenWhenLastSure({required bool isOpen}) async {
    // No key reads as "not open", so a cleared note leaves nothing behind.
    if (isOpen) {
      await _prefs.setBool(AlarmStyleChoices.openWhenLastSureKey, true);
    } else {
      await _prefs.remove(AlarmStyleChoices.openWhenLastSureKey);
    }
  }

  @override
  Stream<void> get changes => _changes.stream;

  Future<void> dispose() => _changes.close();
}
