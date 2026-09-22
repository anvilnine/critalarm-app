import 'dart:convert';

import 'package:critalarm/core/alarm/alarm_debug_snapshot.dart';
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
  PushEventDrain(this._prefs, this._gate, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// Written by `PushEventLog.kt`. The `flutter.` prefix is what the
  /// shared_preferences plugin puts on every key it owns.
  static const storageKey = 'pending_push_events';

  final SharedPreferences _prefs;
  final TelemetryGate _gate;
  final DateTime Function() _clock;
  final List<DebugPushEvent> _recent = [];

  /// The latest 100 valid events, newest first.
  List<DebugPushEvent> recent() => List.unmodifiable(_recent.reversed);

  /// Records a local developer action without sending it to telemetry.
  void recordDebugAction(String action) => _append(
    DebugPushEvent({
      'name': 'debug_action',
      'action': action,
      'at': _clock().toUtc().toIso8601String(),
    }),
  );

  /// Reports and clears the backlog. Returns how many rows were reported.
  Future<int> drain() async {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return 0;
    await _prefs.remove(storageKey);

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return 0;
    }
    if (decoded is! List) return 0;

    var reported = 0;
    for (final row in decoded.whereType<Map<String, dynamic>>()) {
      final rawName = row['name'];
      if (rawName is! String || rawName.isEmpty) continue;
      final name = rawName;
      if (_allowed.contains(name) || name == 'debug_action') {
        _append(DebugPushEvent(Map<String, Object?>.from(row)));
      }
      if (!_allowed.contains(name)) continue;
      final params = <String, Object?>{
        for (final entry in row.entries)
          if (entry.key != 'name') entry.key: entry.value,
      };
      await _gate.logEvent(name, params);
      reported++;
    }
    return reported;
  }

  void _append(DebugPushEvent event) {
    _recent.add(event);
    if (_recent.length > 100) {
      _recent.removeRange(0, _recent.length - 100);
    }
  }

  static const Set<String> _allowed = {
    AnalyticsEvents.alarmFired,
    AnalyticsEvents.alarmAcked,
    AnalyticsEvents.timeToAckMs,
    AnalyticsEvents.pushReceived,
    AnalyticsEvents.pushDropped,
  };
}
