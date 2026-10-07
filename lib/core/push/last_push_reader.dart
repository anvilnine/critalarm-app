import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// When the phone last received a push from the relay, and the clock the
/// "nothing for a week" rule counts from when it never has.
///
/// The native push handlers write a `push_received` row for every push they
/// accept (`PushEventLog`). `PushEventDrain` empties that list on launch and
/// calls [record] with the newest row first, so the time survives the drain.
class LastPushStore {
  LastPushStore(SharedPreferences prefs) : _prefs = prefs;

  static const receivedAtKey = 'last_push_received_at_ms';
  static const watchingSinceKey = 'last_push_watching_since_ms';

  final SharedPreferences _prefs;

  DateTime? get receivedAt => _read(receivedAtKey);

  /// Keeps [at] only if it is newer than what is held.
  Future<void> record(DateTime at) async {
    final current = receivedAt;
    if (current != null && !at.isAfter(current)) return;
    await _prefs.setInt(receivedAtKey, at.toUtc().millisecondsSinceEpoch);
  }

  /// The first time anything asked. A phone that has never received a push
  /// counts its silence from here, so an update that adds this check does not
  /// start from a week of "nothing".
  Future<DateTime> watchingSince(DateTime now) async {
    final held = _read(watchingSinceKey);
    if (held != null) return held;
    await _prefs.setInt(watchingSinceKey, now.toUtc().millisecondsSinceEpoch);
    return now.toUtc();
  }

  DateTime? _read(String key) {
    final ms = _prefs.getInt(key);
    return ms == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }
}

/// Newest `at_ms` of a `push_received` row in [rows], or null.
DateTime? newestPushReceived(Iterable<Object?> rows) {
  DateTime? newest;
  for (final row in rows) {
    if (row is! Map || row['name'] != pushReceivedName) continue;
    final ms = row['at_ms'];
    if (ms is! num) continue;
    final at = DateTime.fromMillisecondsSinceEpoch(ms.toInt(), isUtc: true);
    if (newest == null || at.isAfter(newest)) newest = at;
  }
  return newest;
}

/// The event name the native handlers write. Same string as
/// `AnalyticsEvents.pushReceived`.
const pushReceivedName = 'push_received';

/// Reads the newest push the phone has received, from every place it can be.
///
/// - [LastPushStore], where the drain left it.
/// - The list the native side writes to and the drain has not emptied yet
///   (Android writes it while the app runs).
/// - `nativeRows`, for iOS, where the extension writes to the App Group and
///   the rows only reach that list on the next launch.
final class LastPushReader {
  LastPushReader(
    this._prefs,
    this.store, {
    this.pendingKey = 'pending_push_events',
    this._nativeRows,
  });

  final SharedPreferences _prefs;
  final LastPushStore store;

  /// `PushEventDrain.storageKey`.
  final String pendingKey;
  final Future<List<Object?>> Function()? _nativeRows;

  Future<DateTime?> read() async {
    // Native code writes the pending list while Dart is running.
    await _prefs.reload();
    final candidates = <DateTime?>[store.receivedAt, _pending()];
    final native = _nativeRows;
    if (native != null) {
      try {
        candidates.add(newestPushReceived(await native()));
      } on Object catch (_) {
        // The native read is a bonus. The others still answer.
      }
    }
    DateTime? newest;
    for (final at in candidates) {
      if (at != null && (newest == null || at.isAfter(newest))) newest = at;
    }
    return newest;
  }

  DateTime? _pending() {
    final raw = _prefs.getString(pendingKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? newestPushReceived(decoded) : null;
    } on FormatException {
      return null;
    }
  }
}
