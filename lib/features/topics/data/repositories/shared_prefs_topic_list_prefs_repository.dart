import 'package:critalarm/features/topics/domain/repositories/topic_list_prefs_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsTopicListPrefsRepository implements TopicListPrefsRepository {
  const SharedPrefsTopicListPrefsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _pinnedKey = 'topic_list_pinned';
  static const _mutedKey = 'topic_list_muted';
  static const _lastReadPrefix = 'topic_list_last_read.';

  @override
  Set<String> pinned() => (_prefs.getStringList(_pinnedKey) ?? []).toSet();

  @override
  Set<String> muted() => (_prefs.getStringList(_mutedKey) ?? []).toSet();

  @override
  DateTime? lastReadAt(String topic) {
    final ms = _prefs.getInt('$_lastReadPrefix$topic');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Future<void> setPinned(String topic, {required bool pinned}) =>
      _toggle(_pinnedKey, topic, on: pinned);

  @override
  Future<void> setMuted(String topic, {required bool muted}) =>
      _toggle(_mutedKey, topic, on: muted);

  @override
  Future<void> markRead(String topic, DateTime at) =>
      _prefs.setInt('$_lastReadPrefix$topic', at.millisecondsSinceEpoch);

  Future<void> _toggle(String key, String topic, {required bool on}) {
    final names = (_prefs.getStringList(key) ?? []).toSet();
    if (on) {
      names.add(topic);
    } else {
      names.remove(topic);
    }
    return _prefs.setStringList(key, names.toList()..sort());
  }
}
