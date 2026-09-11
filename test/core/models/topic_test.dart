import 'package:critalarm/core/models/topic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Topic', () {
    test('defaults match specification and Apple commitments', () {
      const topic = Topic(name: 'prod-db');

      expect(topic.name, 'prod-db');
      expect(topic.critical, isFalse); // Non-negotiable Apple commitment
      expect(topic.repeatIntervalS, 30);
      expect(topic.maxRingS, 1800);
      expect(topic.deskTimerS, 600);
      expect(topic.relayContent, 'none');
      expect(topic.createdAt, isNull);
      expect(topic.token, isNull);
    });

    test('copyWith updates properties while keeping unchanged fields', () {
      final topic = Topic(
        name: 'alerts',
        createdAt: DateTime.utc(2026, 9, 10, 12),
      );

      final updated = topic.copyWith(
        critical: true,
        repeatIntervalS: 60,
        token: 'tk_test_123',
      );

      expect(updated.name, 'alerts');
      expect(updated.critical, isTrue);
      expect(updated.repeatIntervalS, 60);
      expect(updated.maxRingS, 1800);
      expect(updated.deskTimerS, 600);
      expect(updated.token, 'tk_test_123');
      expect(updated.createdAt, DateTime.utc(2026, 9, 10, 12));
    });

    test('serializes to JSON with snake_case keys', () {
      final created = DateTime.utc(2026, 9, 10, 12);
      final topic = Topic(
        name: 'uptime',
        critical: true,
        repeatIntervalS: 45,
        maxRingS: 900,
        deskTimerS: 300,
        relayContent: 'full',
        createdAt: created,
        token: 'tk_xyz',
      );

      final json = topic.toJson();

      expect(json['name'], 'uptime');
      expect(json['critical'], isTrue);
      expect(json['repeat_interval_s'], 45);
      expect(json['max_ring_s'], 900);
      expect(json['desk_timer_s'], 300);
      expect(json['relay_content'], 'full');
      expect(json['created_at'], created.toIso8601String());
      expect(json['token'], 'tk_xyz');
    });

    test('deserializes from JSON with ISO 8601 string created_at', () {
      final json = {
        'name': 'nas',
        'critical': false,
        'repeat_interval_s': 30,
        'max_ring_s': 1800,
        'desk_timer_s': 600,
        'relay_content': 'none',
        'created_at': '2026-09-10T15:30:00.000Z',
      };

      final topic = Topic.fromJson(json);

      expect(topic.name, 'nas');
      expect(topic.critical, isFalse);
      expect(topic.createdAt, DateTime.utc(2026, 9, 10, 15, 30));
      expect(topic.token, isNull);
    });

    test('deserializes from JSON with unix timestamp created_at', () {
      final json = {
        'name': 'kuma',
        'critical': true,
        'created_at': 1757462400,
      };

      final topic = Topic.fromJson(json);

      expect(topic.name, 'kuma');
      expect(topic.critical, isTrue);
      expect(
        topic.createdAt,
        DateTime.fromMillisecondsSinceEpoch(1757462400 * 1000, isUtc: true),
      );
    });
  });
}
