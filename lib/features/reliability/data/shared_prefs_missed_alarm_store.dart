import 'dart:convert';

import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_store.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/phone_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [MissedAlarmStore] in shared preferences. A value that does not read back
/// counts as not there, so a damaged one costs what it held and nothing else.
class SharedPrefsMissedAlarmStore implements MissedAlarmStore {
  SharedPrefsMissedAlarmStore(this._prefs);

  static const recordKey = 'missed_alarm_phone_record_v1';
  static const dismissedKey = 'missed_alarm_dismissed_v1';
  static const setupDoneAtKey = 'missed_alarm_setup_done_at_ms';
  static const connectedServerKey = 'missed_alarm_connected_server';
  static const connectedSinceKey = 'missed_alarm_connected_since_ms';

  final SharedPreferences _prefs;

  @override
  PhoneRecord readRecord() => PhoneRecord.fromJson(_decode(recordKey));

  @override
  Future<void> writeRecord(PhoneRecord record) =>
      _prefs.setString(recordKey, jsonEncode(record.toJson()));

  @override
  Map<String, DateTime> readDismissed() {
    final raw = _decode(dismissedKey);
    return {
      if (raw is Map)
        for (final entry in raw.entries)
          if (entry.key is String && entry.value is num)
            entry.key as String: _time((entry.value as num).toInt()),
    };
  }

  @override
  Future<void> writeDismissed(Map<String, DateTime> dismissed) =>
      _prefs.setString(
        dismissedKey,
        jsonEncode({
          for (final entry in dismissed.entries)
            entry.key: entry.value.toUtc().millisecondsSinceEpoch,
        }),
      );

  @override
  DateTime? readSetupDoneAt() {
    final ms = _prefs.getInt(setupDoneAtKey);
    return ms == null ? null : _time(ms);
  }

  @override
  Future<void> writeSetupDoneAt(DateTime at) =>
      _prefs.setInt(setupDoneAtKey, at.toUtc().millisecondsSinceEpoch);

  @override
  ConnectedServer? readConnected() {
    final server = _prefs.getString(connectedServerKey);
    final since = _prefs.getInt(connectedSinceKey);
    if (server == null || server.isEmpty || since == null) return null;
    return ConnectedServer(server: server, since: _time(since));
  }

  @override
  Future<void> writeConnected(ConnectedServer connected) async {
    await _prefs.setString(connectedServerKey, connected.server);
    await _prefs.setInt(
      connectedSinceKey,
      connected.since.toUtc().millisecondsSinceEpoch,
    );
  }

  Object? _decode(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  static DateTime _time(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
}
