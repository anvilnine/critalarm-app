import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Incident', () {
    test('defaults match specification', () {
      const inc = Incident(
        id: 'inc_1',
        topic: 'prod-db',
      );

      expect(inc.id, 'inc_1');
      expect(inc.topic, 'prod-db');
      expect(inc.state, IncidentStates.open);
      expect(inc.isOpen, isTrue);
      expect(inc.isAcked, isFalse);
      expect(inc.isClosed, isFalse);
      expect(inc.isExpired, isFalse);
      expect(inc.openedAt, isNull);
      expect(inc.ackedAt, isNull);
      expect(inc.closedAt, isNull);
      expect(inc.lastMessageAt, isNull);
      expect(inc.deskTimerFiresAt, isNull);
      expect(inc.messages, isEmpty);
    });

    test('state helpers evaluate correctly', () {
      const openInc = Incident(id: '1', topic: 't');
      const ackedInc = Incident(id: '2', topic: 't', state: 'acked');
      const closedInc = Incident(id: '3', topic: 't', state: 'closed');
      const expiredInc = Incident(id: '4', topic: 't', state: 'expired');

      expect(openInc.isOpen, isTrue);
      expect(openInc.incidentState, IncidentState.open);

      expect(ackedInc.isAcked, isTrue);
      expect(ackedInc.incidentState, IncidentState.acked);

      expect(closedInc.isClosed, isTrue);
      expect(closedInc.incidentState, IncidentState.closed);

      expect(expiredInc.isExpired, isTrue);
      expect(expiredInc.incidentState, IncidentState.expired);
    });

    test('copyWith updates state and timestamps', () {
      final now = DateTime.utc(2026, 9, 11, 4);
      final inc = Incident(
        id: 'inc_5',
        topic: 'prod',
        openedAt: now,
      );

      final acked = inc.copyWith(
        state: IncidentStates.acked,
        ackedAt: now.add(const Duration(minutes: 2)),
        deskTimerFiresAt: now.add(const Duration(minutes: 12)),
      );

      expect(acked.id, 'inc_5');
      expect(acked.topic, 'prod');
      expect(acked.state, 'acked');
      expect(acked.isAcked, isTrue);
      expect(acked.openedAt, now);
      expect(acked.ackedAt, now.add(const Duration(minutes: 2)));
      expect(acked.deskTimerFiresAt, now.add(const Duration(minutes: 12)));
    });

    test('serializes and deserializes JSON roundtrip with messages', () {
      final openedAt = DateTime.utc(2026, 9, 10, 10);
      const msg = Message(
        id: 'm_10',
        topic: 'prod',
        title: 'Down',
        message: 'DB failed',
        priority: 5,
        incidentId: 'inc_roundtrip',
      );

      final inc = Incident(
        id: 'inc_roundtrip',
        topic: 'prod',
        openedAt: openedAt,
        messages: const [msg],
      );

      final json = inc.toJson();
      expect(json['id'], 'inc_roundtrip');
      expect(json['topic'], 'prod');
      expect(json['state'], 'open');
      expect(json['opened_at'], openedAt.toIso8601String());
      expect(json['messages'], isNotEmpty);

      final deserialized = Incident.fromJson(json);
      expect(deserialized.id, inc.id);
      expect(deserialized.topic, inc.topic);
      expect(deserialized.state, inc.state);
      expect(deserialized.openedAt, inc.openedAt);
      expect(deserialized.messages.length, 1);
      expect(deserialized.messages.first.id, 'm_10');
    });

    test('parses updated_at when the server sends it', () {
      final updatedAt = DateTime.utc(2026, 9, 11, 5, 30);
      final inc = Incident.fromJson({
        'id': 'inc_1',
        'topic': 'prod',
        'state': 'acked',
        'opened_at': DateTime.utc(2026, 9, 11, 5).toIso8601String(),
        'acked_at': DateTime.utc(2026, 9, 11, 5, 10).toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      });

      expect(inc.updatedAt, updatedAt);
    });

    test('missing updated_at falls back to the newest of the three times', () {
      final openedAt = DateTime.utc(2026, 9, 11, 5);
      final ackedAt = DateTime.utc(2026, 9, 11, 5, 10);
      final closedAt = DateTime.utc(2026, 9, 11, 5, 20);
      final inc = Incident.fromJson({
        'id': 'inc_1',
        'topic': 'prod',
        'state': 'closed',
        'opened_at': openedAt.toIso8601String(),
        'acked_at': ackedAt.toIso8601String(),
        'closed_at': closedAt.toIso8601String(),
      });

      expect(inc.updatedAt, closedAt);
    });

    test('missing updated_at with only opened_at falls back to opened_at', () {
      final openedAt = DateTime.utc(2026, 9, 11, 5);
      final inc = Incident.fromJson({
        'id': 'inc_1',
        'topic': 'prod',
        'opened_at': openedAt.toIso8601String(),
      });

      expect(inc.updatedAt, openedAt);
    });
  });
}
