import 'dart:convert';

import 'package:critalarm/core/alarm/alarm_debug_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final takenAt = DateTime.utc(2026, 9, 23, 10);
  const environment = DebugEnvironment(
    serverMode: 'hosted',
    baseUrl: 'https://alerts.example.com',
    tier: 'free',
    historyDays: 30,
    quietHoursHolding: false,
  );

  test('parses native snapshot sections and converts epoch seconds to UTC', () {
    final snapshot = AlarmDebugSnapshot.fromNative(
      {
        'incidents': [
          {
            'id': 'inc_1',
            'topic': 'prod',
            'phone_state': 'silenced',
            'ring_until': 1790157600,
            'rearm_pending': true,
            'rearm_fires_at': 1790157601,
            'acked_locally': false,
            'desk_timer_fires_at': 1790157602,
            'last_push_kind': 'repeat',
            'last_push_at': 1790157603,
            'content_cached_at': 1790157604,
            'content_last_message_at': 1790157605,
          },
        ],
        'ack_queue': [
          {
            'action': 'ack',
            'incident_id': 'inc_1',
            'attempts': 2,
            'next_attempt_at': 1790157606,
            'last_error': 'offline',
          },
        ],
        'acked_set': [
          {'incident_id': 'inc_1', 'marked_at': 1790157607},
        ],
        'scheduled': [
          {'kind': 'alarmkit', 'identifier': 'inc_1', 'fires_at': 1790157608},
        ],
        'permissions': {
          'notifications': 'authorized',
          'alarmkit': 'unsupported',
          'battery_exempt': null,
        },
        'ringing': true,
      },
      takenAt: takenAt,
      environment: environment,
    );

    expect(snapshot.takenAt, takenAt);
    expect(snapshot.incidents.single.id, 'inc_1');
    expect(snapshot.incidents.single.phoneState, 'silenced');
    expect(snapshot.incidents.single.ringUntil, DateTime.utc(2026, 9, 23, 10));
    expect(
      snapshot.ackQueue.single.nextAttemptAt,
      DateTime.utc(2026, 9, 23, 10, 0, 6),
    );
    expect(snapshot.ackQueue.single.source, DebugAckSource.native);
    expect(
      snapshot.ackedSet.single.markedAt,
      DateTime.utc(2026, 9, 23, 10, 0, 7),
    );
    expect(
      snapshot.scheduled.single.firesAt,
      DateTime.utc(2026, 9, 23, 10, 0, 8),
    );
    expect(snapshot.permissions.notifications, 'authorized');
    expect(snapshot.ringing, isTrue);
  });

  test('missing sections become empty and malformed rows are skipped', () {
    final snapshot = AlarmDebugSnapshot.fromNative(
      {
        'incidents': [
          null,
          {'topic': 'missing-id'},
        ],
        'ack_queue': [
          {'action': 'ack', 'incident_id': 'inc_1', 'attempts': 'bad'},
        ],
        'scheduled': [
          {'kind': 3, 'identifier': 'bad'},
        ],
      },
      takenAt: takenAt,
      environment: environment,
    );

    expect(snapshot.incidents, isEmpty);
    expect(snapshot.ackQueue, isEmpty);
    expect(snapshot.ackedSet, isEmpty);
    expect(snapshot.scheduled, isEmpty);
    expect(snapshot.pushEvents, isEmpty);
    expect(snapshot.launchCalls, isEmpty);
  });

  test('nested maps with non-string keys are safely filtered', () {
    final snapshot = AlarmDebugSnapshot.fromNative(
      {
        'permissions': {1: 'ignored', 'notifications': 'authorized'},
        'incidents': [
          {1: 'ignored', 'id': 'inc_1'},
        ],
      },
      takenAt: takenAt,
      environment: environment,
    );

    expect(snapshot.permissions.notifications, 'authorized');
    expect(snapshot.incidents.single.id, 'inc_1');
  });

  test('JSON report safely filters non-string keys in nested maps', () {
    final snapshot = AlarmDebugSnapshot.fromJson({
      'environment': {1: 'ignored', 'base_url': 'https://example.test'},
      'incidents': [
        {1: 'ignored', 'id': 'inc_1'},
      ],
      'store': {1: 'ignored', 'database_bytes': 42},
      'permissions': {1: 'ignored', 'notifications': 'authorized'},
    });

    expect(snapshot.environment.baseUrl, 'https://example.test');
    expect(snapshot.incidents.single.id, 'inc_1');
    expect(snapshot.store.databaseBytes, 42);
    expect(snapshot.permissions.notifications, 'authorized');
  });

  test('push event timestamp accepts native at_ms epoch milliseconds', () {
    final event = DebugPushEvent.fromJson({
      'name': 'push_received',
      'at_ms': 1790157600123,
    });

    expect(event?.at, DateTime.utc(2026, 9, 23, 10, 0, 0, 123));
  });

  test('unknown phone state stays displayable as unknown', () {
    final snapshot = AlarmDebugSnapshot.fromNative(
      {
        'incidents': [
          {'id': 'inc_1', 'phone_state': 'future-native-state'},
        ],
      },
      takenAt: takenAt,
      environment: environment,
    );

    expect(snapshot.incidents.single.phoneState, 'unknown');
  });

  test('same native and Dart ack entry merges retaining newest details', () {
    final native = DebugAckEntry(
      action: 'ack',
      incidentId: 'inc_1',
      attempts: 1,
      nextAttemptAt: DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true),
      source: DebugAckSource.native,
    );
    final dart = DebugAckEntry(
      action: 'ack',
      incidentId: 'inc_1',
      attempts: 3,
      nextAttemptAt: DateTime.fromMillisecondsSinceEpoch(4000, isUtc: true),
      lastError: 'offline',
      source: DebugAckSource.dart,
    );

    final snapshot = AlarmDebugSnapshot.fromNative(
      {
        'ack_queue': [
          {
            'action': 'ack',
            'incident_id': 'inc_1',
            'attempts': native.attempts,
            'next_attempt_at':
                native.nextAttemptAt.millisecondsSinceEpoch ~/ 1000,
          },
        ],
      },
      takenAt: takenAt,
      environment: environment,
      dartAckQueue: [dart],
    );

    expect(snapshot.ackQueue, hasLength(1));
    expect(snapshot.ackQueue.single.attempts, 3);
    expect(
      snapshot.ackQueue.single.nextAttemptAt,
      DateTime.fromMillisecondsSinceEpoch(4000, isUtc: true),
    );
    expect(snapshot.ackQueue.single.lastError, 'offline');
    expect(snapshot.ackQueue.single.source, DebugAckSource.combined);
  });

  test('JSON report round trips through the snapshot parser', () {
    final snapshot = AlarmDebugSnapshot.fromNative(
      {
        'incidents': [
          {'id': 'inc_1', 'phone_state': 'closed'},
        ],
        'ringing': false,
      },
      takenAt: takenAt,
      environment: environment,
    );

    final decoded = jsonDecode(jsonEncode(snapshot.toJson()));
    final restored = AlarmDebugSnapshot.fromJson(
      Map<String, Object?>.from(decoded as Map),
    );

    expect(restored.toJson(), snapshot.toJson());
  });
}
