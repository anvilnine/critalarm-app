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
  static const topicsHeldKey = 'missed_alarm_topics_held_v1';

  final SharedPreferences _prefs;

  @override
  PhoneRecord readRecord() => PhoneRecord.fromJson(_decode(recordKey));

  @override
  Future<void> writeRecord(PhoneRecord record) =>
      _prefs.setString(recordKey, jsonEncode(record.toJson()));

  @override
  Map<String, DateTime> readDismissed() => _readTimes(dismissedKey);

  @override
  Future<void> writeDismissed(Map<String, DateTime> dismissed) =>
      _writeTimes(dismissedKey, dismissed);

  @override
  Map<String, List<TopicHold>> readTopicHolds() {
    final raw = _decode(topicsHeldKey);
    if (raw is! Map) return {};
    final holds = <String, List<TopicHold>>{};
    for (final entry in raw.entries) {
      final name = entry.key;
      final list = entry.value;
      if (name is! String || list is! List) continue;
      final read = <TopicHold>[];
      for (final pair in list) {
        if (pair is! List || pair.isEmpty || pair.first is! num) continue;
        final until = pair.length > 1 ? pair[1] : null;
        read.add(
          TopicHold(
            since: _time((pair.first as num).toInt()),
            until: until is num ? _time(until.toInt()) : null,
          ),
        );
      }
      if (read.isNotEmpty) holds[name] = read;
    }
    return holds;
  }

  @override
  Future<void> writeTopicHolds(Map<String, List<TopicHold>> holds) =>
      _prefs.setString(
        topicsHeldKey,
        jsonEncode({
          for (final entry in holds.entries)
            entry.key: [
              for (final hold in entry.value)
                [
                  hold.since.toUtc().millisecondsSinceEpoch,
                  hold.until?.toUtc().millisecondsSinceEpoch,
                ],
            ],
        }),
      );

  @override
  Future<void> clearServerData() async {
    await _prefs.remove(recordKey);
    await _prefs.remove(dismissedKey);
    await _prefs.remove(topicsHeldKey);
  }

  Map<String, DateTime> _readTimes(String key) {
    final raw = _decode(key);
    return {
      if (raw is Map)
        for (final entry in raw.entries)
          if (entry.key is String && entry.value is num)
            entry.key as String: _time((entry.value as num).toInt()),
    };
  }

  Future<void> _writeTimes(String key, Map<String, DateTime> times) =>
      _prefs.setString(
        key,
        jsonEncode({
          for (final entry in times.entries)
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
    if (server == null || since == null) return null;
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
