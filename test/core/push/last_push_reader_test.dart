import 'dart:convert';

import 'package:critalarm/core/push/last_push_reader.dart';
import 'package:critalarm/core/push/push_event_drain.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late LastPushStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = LastPushStore(prefs);
  });

  test(
    'the drain keeps the newest push time after it empties the list',
    () async {
      final drain = PushEventDrain(
        prefs,
        const NoopTelemetryGate(),
        lastPush: store,
      );
      await prefs.setString(
        PushEventDrain.storageKey,
        jsonEncode([
          {'name': 'push_received', 'at_ms': 2000},
          {'name': 'push_dropped', 'at_ms': 9000},
          {'name': 'push_received', 'at_ms': 1000},
        ]),
      );
      await drain.drain();

      expect(prefs.getString(PushEventDrain.storageKey), isNull);
      expect(
        store.receivedAt,
        DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true),
      );
    },
  );

  test('the drain never moves the stored time backwards', () async {
    final drain = PushEventDrain(
      prefs,
      const NoopTelemetryGate(),
      lastPush: store,
    );
    await store.record(DateTime.fromMillisecondsSinceEpoch(5000, isUtc: true));
    await prefs.setString(
      PushEventDrain.storageKey,
      jsonEncode([
        {'name': 'push_received', 'at_ms': 2000},
      ]),
    );
    await drain.drain();
    expect(
      store.receivedAt,
      DateTime.fromMillisecondsSinceEpoch(5000, isUtc: true),
    );
  });

  test('the drain still lists the same events for the debug screen', () async {
    final drain = PushEventDrain(
      prefs,
      const NoopTelemetryGate(),
      lastPush: store,
    );
    await prefs.setString(
      PushEventDrain.storageKey,
      jsonEncode([
        {'name': 'push_received', 'at_ms': 2000},
      ]),
    );
    await drain.drain();
    expect(drain.recent().single.name, 'push_received');
    expect(
      drain.recent().single.at,
      DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true),
    );
  });

  test('the reader answers null with nothing anywhere', () async {
    expect(await LastPushReader(prefs, store).read(), isNull);
  });

  test('a malformed pending list is ignored', () async {
    await prefs.setString(PushEventDrain.storageKey, 'not json');
    expect(await LastPushReader(prefs, store).read(), isNull);
  });

  test(
    'the reader takes the newest of store, pending list and native rows',
    () async {
      await store.record(
        DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      );
      await prefs.setString(
        PushEventDrain.storageKey,
        jsonEncode([
          {'name': 'push_received', 'at_ms': 3000},
        ]),
      );
      final reader = LastPushReader(
        prefs,
        store,
        nativeRows: () async => [
          {'name': 'push_received', 'at_ms': 2000},
        ],
      );
      expect(
        await reader.read(),
        DateTime.fromMillisecondsSinceEpoch(3000, isUtc: true),
      );
    },
  );

  drainSurvivesAThrowingStore();

  test('watchingSince is set once and kept', () async {
    final first = DateTime.utc(2026, 10, 7);
    expect(await store.watchingSince(first), first);
    expect(
      await store.watchingSince(first.add(const Duration(days: 3))),
      first,
    );
  });
}

class _ThrowingLastPushStore extends LastPushStore {
  _ThrowingLastPushStore(super.prefs);

  @override
  Future<void> record(DateTime at) async => throw StateError('disk full');
}

void drainSurvivesAThrowingStore() {
  test('a store that throws does not stop or change the drain', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final gate = _CountingGate();
    final drain = PushEventDrain(
      prefs,
      gate,
      lastPush: _ThrowingLastPushStore(prefs),
    );
    await prefs.setString(
      PushEventDrain.storageKey,
      jsonEncode([
        {'name': 'push_received', 'at_ms': 2000},
        {'name': 'push_dropped', 'reason': 'x'},
        {'name': 'debug_action', 'action': 'refresh'},
      ]),
    );

    expect(await drain.drain(), 2);
    expect(gate.events, ['push_received', 'push_dropped']);
    expect(drain.recent().map((e) => e.name), [
      'debug_action',
      'push_dropped',
      'push_received',
    ]);
    expect(prefs.getString(PushEventDrain.storageKey), isNull);
  });
}

class _CountingGate extends NoopTelemetryGate {
  _CountingGate();

  final events = <String>[];

  @override
  Future<void> logEvent(String name, [Map<String, Object?>? parameters]) async {
    events.add(name);
  }
}
