import 'dart:convert';

import 'package:critalarm/core/telemetry/analytics_events.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reports the push events the native side recorded while Dart was asleep.
///
/// A push handled in the background never reaches Dart, and the native code has
/// no way to read the analytics opt-in, so it writes what happened to shared
/// preferences instead. This drains that list on launch and reports it through
/// [TelemetryGate], which drops everything unless the user opted in.
final class PushEventDrain {
  const PushEventDrain(this._prefs, this._gate);

  /// Written by `PushEventLog.kt`. The `flutter.` prefix is what the
  /// shared_preferences plugin puts on every key it owns.
  static const storageKey = 'pending_push_events';

  final SharedPreferences _prefs;
  final TelemetryGate _gate;

  /// Reports and clears the backlog. Returns how many rows were reported.
  Future<int> drain() async {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return 0;
    await _prefs.remove(storageKey);

    List<dynamic> rows;
    try {
      rows = jsonDecode(raw) as List<dynamic>;
    } on FormatException {
      return 0;
    }

    var reported = 0;
    for (final row in rows.whereType<Map<String, dynamic>>()) {
      final name = row['name'] as String?;
      if (name == null || !_allowed.contains(name)) continue;
      final params = <String, Object?>{
        for (final entry in row.entries)
          if (entry.key != 'name') entry.key: entry.value,
      };
      await _gate.logEvent(name, params);
      reported++;
    }
    return reported;
  }

  static const Set<String> _allowed = {
    AnalyticsEvents.alarmFired,
    AnalyticsEvents.alarmAcked,
    AnalyticsEvents.timeToAckMs,
    AnalyticsEvents.pushReceived,
    AnalyticsEvents.pushDropped,
  };
}
