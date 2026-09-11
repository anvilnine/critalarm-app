import 'package:critalarm/core/models/message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Message', () {
    test('defaults match specification', () {
      const msg = Message(
        id: 'm_123',
        topic: 'prod',
      );

      expect(msg.id, 'm_123');
      expect(msg.topic, 'prod');
      expect(msg.time, 0);
      expect(msg.expires, isNull);
      expect(msg.event, 'message');
      expect(msg.title, isNull);
      expect(msg.message, 'triggered');
      expect(msg.priority, 3);
      expect(msg.tags, isEmpty);
      expect(msg.click, isNull);
      expect(msg.markdown, isFalse);
      expect(msg.incidentId, isNull);
    });

    test('copyWith works properly', () {
      const msg = Message(
        id: 'm_1',
        topic: 'db',
      );

      final updated = msg.copyWith(
        priority: 5,
        title: 'DB Down',
        incidentId: 'inc_99',
        tags: const ['critical'],
      );

      expect(updated.priority, 5);
      expect(updated.title, 'DB Down');
      expect(updated.incidentId, 'inc_99');
      expect(updated.tags, const ['critical']);
      expect(updated.topic, 'db');
    });

    test('serializes to JSON with incident_id', () {
      const msg = Message(
        id: 'm_7f3k2p9q',
        topic: 'prod',
        time: 1757462400,
        expires: 1757505600,
        title: 'Uptime Kuma',
        message: 'db01 is down',
        priority: 5,
        tags: ['warning'],
        incidentId: 'inc_9a8b7c',
      );

      final json = msg.toJson();

      expect(json['id'], 'm_7f3k2p9q');
      expect(json['time'], 1757462400);
      expect(json['expires'], 1757505600);
      expect(json['event'], 'message');
      expect(json['topic'], 'prod');
      expect(json['title'], 'Uptime Kuma');
      expect(json['message'], 'db01 is down');
      expect(json['priority'], 5);
      expect(json['tags'], const ['warning']);
      expect(json['incident_id'], 'inc_9a8b7c');
    });

    test('deserializes from JSON according to ntfy format with extensions', () {
      final json = {
        'id': 'm_abc',
        'time': 1757462400,
        'event': 'message',
        'topic': 'home',
        'title': 'Door opened',
        'message': 'Front door opened',
        'priority': 4,
        'tags': ['door', 'security'],
        'click': 'https://example.com',
        'markdown': true,
        'incident_id': 'inc_101',
      };

      final msg = Message.fromJson(json);

      expect(msg.id, 'm_abc');
      expect(msg.time, 1757462400);
      expect(msg.topic, 'home');
      expect(msg.title, 'Door opened');
      expect(msg.message, 'Front door opened');
      expect(msg.priority, 4);
      expect(msg.tags, const ['door', 'security']);
      expect(msg.click, 'https://example.com');
      expect(msg.markdown, isTrue);
      expect(msg.incidentId, 'inc_101');
    });
  });
}
