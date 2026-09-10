import 'package:critalarm/features/api/models/api_error.dart';
import 'package:critalarm/features/api/models/caps.dart';
import 'package:critalarm/features/api/models/crit_message.dart';
import 'package:critalarm/features/api/models/device_registration.dart';
import 'package:critalarm/features/api/models/incident.dart';
import 'package:critalarm/features/api/models/server_info.dart';
import 'package:critalarm/features/api/models/topic.dart';
import 'package:critalarm/features/api/models/topic_with_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('API Models round-trip serialization', () {
    test('ServerInfo fromJson / toJson', () {
      final json = <String, dynamic>{
        'name': 'critalarm',
        'version': '0.1.0',
        'base_url': 'https://alerts.example.com',
        'relay_url': 'https://relay.critalarm.app',
        'relay_content': 'none',
        'mode': 'selfhosted',
      };
      final model = ServerInfo.fromJson(json);
      expect(model.name, equals('critalarm'));
      expect(model.baseUrl, equals('https://alerts.example.com'));
      expect(model.toJson(), equals(json));
    });

    test('Topic fromJson / toJson defaults critical to false', () {
      final json = <String, dynamic>{
        'name': 'prod',
        'critical': false,
        'repeat_interval_s': 30,
        'max_ring_s': 1800,
        'desk_timer_s': 600,
        'relay_content': 'none',
        'created_at': 1757462400,
      };
      final model = Topic.fromJson(json);
      expect(model.critical, isFalse);
      expect(model.name, equals('prod'));
      expect(model.toJson(), equals(json));
    });

    test('TopicWithToken fromJson / toJson and toTopic', () {
      final json = <String, dynamic>{
        'name': 'prod',
        'critical': false,
        'repeat_interval_s': 30,
        'max_ring_s': 1800,
        'desk_timer_s': 600,
        'relay_content': 'none',
        'created_at': 1757462400,
        'token': 'tk_123',
      };
      final model = TopicWithToken.fromJson(json);
      expect(model.token, equals('tk_123'));
      expect(model.critical, isFalse);
      final plainTopic = model.toTopic();
      expect(plainTopic.name, equals('prod'));
      expect(plainTopic.critical, isFalse);
    });

    test('CritMessage fromJson / toJson with incidentId', () {
      final json = <String, dynamic>{
        'id': 'm_123',
        'time': 1757462400,
        'expires': 1757505600,
        'event': 'message',
        'topic': 'prod',
        'title': 'Test Title',
        'message': 'Test Body',
        'priority': 5,
        'tags': ['warning'],
        'click': null,
        'incident_id': 'inc_999',
      };
      final model = CritMessage.fromJson(json);
      expect(model.id, equals('m_123'));
      expect(model.incidentId, equals('inc_999'));
      expect(model.priority, equals(5));
      expect(model.toJson(), equals(json));
    });

    test('Incident fromJson / toJson', () {
      final json = <String, dynamic>{
        'id': 'inc_9a8b7c',
        'topic': 'prod',
        'state': 'open',
        'opened_at': 1757462400,
        'acked_at': null,
        'closed_at': null,
        'last_message_at': 1757462400,
        'messages': <Map<String, dynamic>>[],
        'desk_timer_fires_at': null,
      };
      final model = Incident.fromJson(json);
      expect(model.id, equals('inc_9a8b7c'));
      expect(model.state, equals('open'));
      expect(model.messages, isEmpty);
      expect(model.toJson(), equals(json));
    });

    test('Caps fromJson / toJson', () {
      final json = <String, dynamic>{
        'devices': 1,
        'critical_topics': 1,
        'p4_daily': 50,
      };
      final model = Caps.fromJson(json);
      expect(model.devices, equals(1));
      expect(model.criticalTopics, equals(1));
      expect(model.p4Daily, equals(50));
      expect(model.toJson(), equals(json));
    });

    test('DeviceRegistration fromJson / toJson', () {
      final json = <String, dynamic>{
        'device_token': 'dv_secret_123',
        'account_id': 'acc_xyz',
        'tier': 'free',
        'caps': {
          'devices': 1,
          'critical_topics': 1,
          'p4_daily': 50,
        },
      };
      final model = DeviceRegistration.fromJson(json);
      expect(model.deviceToken, equals('dv_secret_123'));
      expect(model.tier, equals('free'));
      expect(model.caps.devices, equals(1));
      expect(model.toJson(), equals(json));
    });

    test('ApiError fromJson / toJson', () {
      final json = <String, dynamic>{
        'code': 40101,
        'http': 401,
        'error': 'unauthorized',
      };
      final model = ApiError.fromJson(json);
      expect(model.code, equals(40101));
      expect(model.http, equals(401));
      expect(model.error, equals('unauthorized'));
      expect(model.toJson(), equals(json));
    });
  });
}
