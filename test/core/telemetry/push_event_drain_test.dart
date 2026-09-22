import 'dart:convert';

import 'package:critalarm/core/push/push_event_drain.dart';
import 'package:critalarm/core/telemetry/analytics_events.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingGate extends NoopTelemetryGate {
  const _RecordingGate(this.events);

  final List<(String, Map<String, Object?>?)> events;

  @override
  Future<void> logEvent(
    String name, [
    Map<String, Object?>? parameters,
  ]) async => events.add((name, parameters));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late List<(String, Map<String, Object?>?)> events;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    events = [];
  });

  test('an empty backlog reports nothing', () async {
    expect(await PushEventDrain(prefs, _RecordingGate(events)).drain(), 0);
    expect(events, isEmpty);
  });

  test('recorded events are reported and then cleared', () async {
    await prefs.setString(
      PushEventDrain.storageKey,
      jsonEncode([
        {'name': AnalyticsEvents.pushReceived, 'kind': 'open', 'priority': '5'},
        {'name': AnalyticsEvents.alarmFired, 'incident_id': 'inc_1'},
        {'name': AnalyticsEvents.pushDropped, 'reason': 'other_server'},
      ]),
    );

    expect(await PushEventDrain(prefs, _RecordingGate(events)).drain(), 3);
    expect(events.map((e) => e.$1), [
      AnalyticsEvents.pushReceived,
      AnalyticsEvents.alarmFired,
      AnalyticsEvents.pushDropped,
    ]);
    expect(events.first.$2, {'kind': 'open', 'priority': '5'});
    expect(prefs.getString(PushEventDrain.storageKey), isNull);
  });

  test('an event name that is not ours is ignored', () async {
    await prefs.setString(
      PushEventDrain.storageKey,
      jsonEncode([
        {'name': 'something_else', 'value': 1},
        {'name': AnalyticsEvents.timeToAckMs, 'value': 4200},
      ]),
    );

    expect(await PushEventDrain(prefs, _RecordingGate(events)).drain(), 1);
    expect(events.single.$1, AnalyticsEvents.timeToAckMs);
  });

  test('a corrupt backlog is dropped, not thrown', () async {
    await prefs.setString(PushEventDrain.storageKey, 'not json');
    expect(await PushEventDrain(prefs, _RecordingGate(events)).drain(), 0);
    expect(prefs.getString(PushEventDrain.storageKey), isNull);
  });

  test('a valid non-list backlog is dropped, not thrown', () async {
    await prefs.setString(PushEventDrain.storageKey, '{}');
    expect(await PushEventDrain(prefs, _RecordingGate(events)).drain(), 0);
    expect(prefs.getString(PushEventDrain.storageKey), isNull);
  });

  test('the gate drops everything while analytics is off', () async {
    await prefs.setString(
      PushEventDrain.storageKey,
      jsonEncode([
        {'name': AnalyticsEvents.alarmFired, 'incident_id': 'inc_1'},
      ]),
    );
    // NoopTelemetryGate stands in for the opt-in switch being off.
    expect(await PushEventDrain(prefs, const NoopTelemetryGate()).drain(), 1);
    expect(events, isEmpty);
  });
}
