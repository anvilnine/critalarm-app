import 'package:critalarm/core/models/topic.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Caches each topic's timers where the Android notification can read them.
///
/// The card is often built by FCM with no Flutter engine running, so these have
/// to be on disk before the push lands. `TopicTimerStore.kt` reads the same
/// keys. The value is `repeat_interval_s|max_ring_s|desk_timer_s`.
class TopicTimerCache {
  const TopicTimerCache(this._preferences);

  static const String keyPrefix = 'topic_timers.';

  final SharedPreferences _preferences;

  Future<void> save(List<Topic> topics) async {
    final wanted = <String>{};
    for (final topic in topics) {
      final key = '$keyPrefix${topic.name}';
      wanted.add(key);
      await _preferences.setString(
        key,
        '${topic.repeatIntervalS}|${topic.maxRingS}|${topic.deskTimerS}',
      );
    }
    final stale = _preferences
        .getKeys()
        .where(
          (key) => key.startsWith(keyPrefix) && !wanted.contains(key),
        )
        .toList();
    for (final key in stale) {
      await _preferences.remove(key);
    }
  }
}
