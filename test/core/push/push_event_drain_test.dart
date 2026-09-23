import 'dart:convert';

import 'package:critalarm/core/push/push_event_drain.dart';
import 'package:critalarm/core/telemetry/analytics_events.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('recent retains 100 valid events newest first across drains', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final gate = _RecordingGate();
    final drain = PushEventDrain(prefs, gate);

    await prefs.setString(
      PushEventDrain.storageKey,
      jsonEncode([
        for (var i = 0; i < 70; i++)
          {'name': AnalyticsEvents.pushReceived, 'event_id': '$i'},
        {'ignored': true},
      ]),
    );
    expect(await drain.drain(), 70);
    expect(drain.recent(), hasLength(70));
    expect(drain.recent().first.values['event_id'], '69');

    await prefs.setString(
      PushEventDrain.storageKey,
      jsonEncode([
        for (var i = 70; i < 120; i++)
          {'name': AnalyticsEvents.pushReceived, 'event_id': '$i'},
      ]),
    );
    expect(await drain.drain(), 50);
    expect(drain.recent(), hasLength(100));
    expect(drain.recent().first.values['event_id'], '119');
    expect(drain.recent().last.values['event_id'], '20');
    expect(gate.events, hasLength(120));
  });

  test('invalid and non-allowlisted events do not reach telemetry', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final gate = _RecordingGate();
    final drain = PushEventDrain(prefs, gate);
    await prefs.setString(
      PushEventDrain.storageKey,
      jsonEncode([
        {'name': 'debug_action', 'action': 'refresh'},
        {'name': 'push_state_change', 'kind': 'ack'},
        {'name': 'unknown_event'},
        {'name': 3},
      ]),
    );

    expect(await drain.drain(), 0);
    expect(gate.events, isEmpty);
    expect(drain.recent().map((event) => event.name), [
      'push_state_change',
      'debug_action',
    ]);
  });
}

final class _RecordingGate extends NoopTelemetryGate {
  final events = <String>[];

  @override
  Future<void> logEvent(String name, [Map<String, Object?>? parameters]) async {
    events.add(name);
  }
}
