import 'package:critalarm/core/models/topic.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Caches each topic's timers where the Android notification can read them.
///
/// The card is often built by FCM with no Flutter engine running, so these have
/// to be on disk before the push lands. `TopicTimerStore.kt` reads the same
/// keys. The value is `repeat_interval_s|max_ring_s|desk_timer_s`.
///
/// The critical switch rides along under its own key. A re-arm has to know
/// whether the topic still rings: turning the switch off must stop the loop
/// for every incident on that topic, and the native side has no other way to
/// read it.
class TopicTimerCache {
  const TopicTimerCache(this._preferences);

  static const String keyPrefix = 'topic_timers.';

  static const String criticalKeyPrefix = 'topic_critical.';

  final SharedPreferences _preferences;

  Future<void> save(List<Topic> topics) async {
    final wanted = <String>{};
    for (final topic in topics) {
      final key = '$keyPrefix${topic.name}';
      final criticalKey = '$criticalKeyPrefix${topic.name}';
      wanted
        ..add(key)
        ..add(criticalKey);
      await _preferences.setString(
        key,
        '${topic.repeatIntervalS}|${topic.maxRingS}|${topic.deskTimerS}',
      );
      await _preferences.setBool(criticalKey, topic.critical);
    }
    final stale = _preferences
        .getKeys()
        .where(
          (key) =>
              (key.startsWith(keyPrefix) ||
                  key.startsWith(criticalKeyPrefix)) &&
              !wanted.contains(key),
        )
        .toList();
    for (final key in stale) {
      await _preferences.remove(key);
    }
  }
}
