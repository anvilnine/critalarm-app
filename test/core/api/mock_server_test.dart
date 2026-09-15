import 'dart:convert';

import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockServer server;

  setUp(() {
    server = MockServer();
  });

  group('MockServer endpoints', () {
    test('/v1/info returns server info', () {
      final info = server.getInfo();

      expect(info.name, 'critalarm');
      expect(info.version, '0.1.0');
      expect(info.baseUrl, 'https://alerts.example.com');
      expect(info.relayUrl, 'https://relay.critalarm.app');
      expect(info.relayContent, 'none');
      expect(info.mode, ServerModes.selfhosted);
    });

    test(
      '/v1/topics POST creates topic with critical: false and token once',
      () {
        final created = server.createTopic(name: 'prod-db');

        expect(created.name, 'prod-db');
        expect(created.critical, isFalse); // Apple entitlement commitment
        expect(created.repeatIntervalS, 30);
        expect(created.maxRingS, 1800);
        expect(created.deskTimerS, 600);
        expect(created.token, isNotNull);
        expect(created.token, startsWith('tk_'));

        // GET /v1/topics does not expose token
        final topics = server.getTopics();
        expect(topics.length, 1);
        expect(topics.first.name, 'prod-db');
        expect(topics.first.token, isNull);
      },
    );

    test('/v1/topics POST rejects invalid topic names with 400', () {
      expect(
        () => server.createTopic(name: 'invalid name with spaces!'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });

    test('/v1/topics/{name} PATCH updates fields', () {
      server.createTopic(name: 'test-topic');

      final updated = server.updateTopic(
        'test-topic',
        critical: true,
        repeatIntervalS: 45,
        maxRingS: 3600,
        deskTimerS: 900,
      );

      expect(updated.critical, isTrue);
      expect(updated.repeatIntervalS, 45);
      expect(updated.maxRingS, 3600);
      expect(updated.deskTimerS, 900);
      expect(updated.token, isNull);
    });

    test('/v1/topics/{name} PATCH on unknown topic throws 404', () {
      expect(
        () => server.updateTopic('unknown', critical: true),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404),
        ),
      );
    });

    test('/v1/topics/{name} DELETE removes topic', () {
      server.createTopic(name: 'to-delete');
      expect(server.getTopics(), hasLength(1));

      server.deleteTopic('to-delete');
      expect(server.getTopics(), isEmpty);
    });

    test('/v1/topics/{name}/tokens POST mints token and DELETE removes it', () {
      server.createTopic(name: 'prod');

      final token2 = server.createTopicToken('prod');
      expect(token2.token, startsWith('tk_'));
      expect(token2.tokenId, startsWith('tok_'));

      server.deleteTopicToken('prod', token2.tokenId);
    });

    test('/v1/test throws 409 if topic is not critical', () {
      server.createTopic(name: 'non-crit');

      expect(
        () => server.triggerTest(topic: 'non-crit'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });

    test('/v1/test succeeds and opens incident when topic is critical', () {
      server.createTopic(name: 'crit-topic', critical: true);

      final incidentId = server.triggerTest(topic: 'crit-topic');
      expect(incidentId, startsWith('inc_'));

      final incidents = server.getIncidents();
      expect(incidents, hasLength(1));
      expect(incidents.first.id, incidentId);
      expect(incidents.first.topic, 'crit-topic');
      expect(incidents.first.state, IncidentStates.open);
      expect(incidents.first.messages.first.title, 'Crit Alarm test');
    });

    test('publish priority 5 on critical topic opens incident', () {
      server.createTopic(name: 'prod', critical: true);

      final msg = server.publishMessage(
        'prod',
        title: 'Database down',
        message: 'PostgreSQL dead',
        priority: 5,
      );

      expect(msg.incidentId, isNotNull);
      final incident = server.getIncident(msg.incidentId!);
      expect(incident.state, IncidentStates.open);
      expect(incident.messages, hasLength(1));
    });

    test(
      'flapping guard: repeated priority 5 joins existing open/acked incident',
      () {
        server.createTopic(name: 'prod', critical: true);

        final msg1 = server.publishMessage(
          'prod',
          title: 'Down 1',
          priority: 5,
        );
        final incId1 = msg1.incidentId!;

        final msg2 = server.publishMessage(
          'prod',
          title: 'Down 2',
          priority: 5,
        );
        expect(msg2.incidentId, incId1);

        final incident = server.getIncident(incId1);
        expect(incident.messages, hasLength(2));
        expect(server.getIncidents(), hasLength(1));
      },
    );

    test('publish priority 4 does not create an incident', () {
      server.createTopic(name: 'prod', critical: true);

      final msg = server.publishMessage(
        'prod',
        title: 'High CPU',
        priority: 4,
      );

      expect(msg.incidentId, isNull);
      expect(server.getIncidents(), isEmpty);
    });

    test(
      'publish on non-critical topic does not create incident for priority 5',
      () {
        server.createTopic(name: 'non-crit');

        final msg = server.publishMessage(
          'non-crit',
          title: 'Something happened',
          priority: 5,
        );

        expect(msg.incidentId, isNull);
        expect(server.getIncidents(), isEmpty);
      },
    );

    test('incident state transitions: open -> acked -> closed', () {
      server.createTopic(name: 'prod', critical: true);
      final msg = server.publishMessage('prod', priority: 5);
      final id = msg.incidentId!;

      // 1. Initial state: open
      var inc = server.getIncident(id);
      expect(inc.state, IncidentStates.open);
      expect(inc.isOpen, isTrue);

      // 2. Ack: open -> acked
      inc = server.ackIncident(id);
      expect(inc.state, IncidentStates.acked);
      expect(inc.isAcked, isTrue);
      expect(inc.ackedAt, isNotNull);
      expect(inc.deskTimerFiresAt, isNotNull);

      // 3. Close: acked -> closed
      inc = server.closeIncident(id);
      expect(inc.state, IncidentStates.closed);
      expect(inc.isClosed, isTrue);
      expect(inc.closedAt, isNotNull);
    });

    test('invalid state transitions return 409', () {
      server.createTopic(name: 'prod', critical: true);
      final msg = server.publishMessage('prod', priority: 5);
      final id = msg.incidentId!;

      // Cannot close directly from open
      expect(
        () => server.closeIncident(id),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );

      // Ack moves to acked
      server.ackIncident(id);

      // Cannot ack again when already acked
      expect(
        () => server.ackIncident(id),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );

      // Close moves to closed
      server.closeIncident(id);

      // Cannot ack or close when closed
      expect(
        () => server.ackIncident(id),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
      expect(
        () => server.closeIncident(id),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });

    test('pollMessages requires poll=1 and filters since', () {
      server
        ..createTopic(name: 'logs')
        ..publishMessage('logs', message: 'line 1')
        ..publishMessage('logs', message: 'line 2');

      // Without poll=1 -> 501
      expect(
        () => server.pollMessages('logs', poll: 0),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 501),
        ),
      );

      final messages = server.pollMessages('logs', poll: 1);
      expect(messages, hasLength(2));
      expect(messages.first.message, 'line 1');
      expect(messages.last.message, 'line 2');
    });

    test('registerDevice returns account_id, device_token, and caps', () {
      const reg = DeviceRegistration(
        deviceId: 'dev_test_uuid',
        platform: 'ios',
        pushToken: 'push_token_xyz',
        appVersion: '1.0.0',
      );

      final response = server.registerDevice(reg);

      expect(response.accountId, startsWith('acc_'));
      expect(response.deviceToken, startsWith('dv_'));
      expect(response.tier, 'free');
      expect(response.caps.devices, 1);
      expect(response.caps.criticalTopics, 2);
      expect(response.caps.p4Daily, 50);
    });
  });

  group('MockServer Fixtures', () {
    test(
      'calm fixture: 4 topics, 0 open incidents, last alert acknowledged',
      () {
        server.loadFixture(FaceState.calm);

        final topics = server.getTopics();
        expect(topics, hasLength(4));
        final names = topics.map((t) => t.name).toSet();
        expect(
          names,
          containsAll(['prod-db', 'nas-backup', 'uptime-kuma', 'home-ha']),
        );

        // 0 open incidents
        final openIncidents = server.getIncidents(state: 'open');
        expect(openIncidents, isEmpty);

        // Last alert was closed
        final allIncidents = server.getIncidents();
        expect(allIncidents, hasLength(1));
        expect(allIncidents.first.state, IncidentStates.closed);
      },
    );

    test('watching fixture: empty state (0 topics)', () {
      server.loadFixture(FaceState.watching);

      expect(server.getTopics(), isEmpty);
      expect(server.getIncidents(), isEmpty);
    });

    test(
      'worried fixture: high priority message open on nas-backup, 1 warning',
      () {
        server.loadFixture(FaceState.worried);

        final topics = server.getTopics();
        expect(topics.map((t) => t.name), contains('nas-backup'));

        final messages = server.pollMessages('nas-backup', poll: 1);
        expect(messages, hasLength(1));
        expect(messages.first.title, 'Backup finished with 2 warnings');
        expect(messages.first.message, 'rsync: 2 files vanished');
        expect(messages.first.priority, 4);

        // No critical incidents open
        expect(server.getIncidents(state: 'open'), isEmpty);
      },
    );

    test(
      'alarmed fixture: critical incident open on prod-db ringing 2 min 14 s',
      () {
        server.loadFixture(FaceState.alarmed);

        final incidents = server.getIncidents(state: 'open');
        expect(incidents, hasLength(1));
        final inc = incidents.first;

        expect(inc.topic, 'prod-db');
        expect(inc.state, IncidentStates.open);
        expect(inc.messages, isNotEmpty);
        expect(inc.messages.first.title, 'Primary database down');
        expect(inc.messages.first.priority, 5);
        expect(inc.messages.length, 5); // 5 repeats over 2 min 14 s
      },
    );

    test('acked fixture: incident acknowledged by Z at 03:14', () {
      server.loadFixture(FaceState.acked);

      final incidents = server.getIncidents(state: 'acked');
      expect(incidents, hasLength(1));
      final inc = incidents.first;

      expect(inc.topic, 'prod-db');
      expect(inc.state, IncidentStates.acked);
      expect(inc.isAcked, isTrue);
      expect(inc.ackedAt, isNotNull);
      expect(inc.ackedAt!.hour, 3);
      expect(inc.ackedAt!.minute, 14);
      expect(inc.deskTimerFiresAt, isNotNull);
    });
  });

  group('MockServer HTTP Client', () {
    test('routes HTTP requests and returns JSON', () async {
      final client = server.httpClient;

      // GET /v1/info
      final infoRes = await client.get(
        Uri.parse('https://alerts.example.com/v1/info'),
      );
      expect(infoRes.statusCode, 200);
      final infoJson = jsonDecode(infoRes.body) as Map<String, dynamic>;
      expect(infoJson['name'], 'critalarm');

      // POST /v1/topics
      final postTopicRes = await client.post(
        Uri.parse('https://alerts.example.com/v1/topics'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'name': 'api-topic', 'critical': true}),
      );
      expect(postTopicRes.statusCode, 201);
      final topicJson = jsonDecode(postTopicRes.body) as Map<String, dynamic>;
      expect(topicJson['name'], 'api-topic');
      expect(topicJson['token'], isNotNull);

      // GET /v1/topics
      final getTopicsRes = await client.get(
        Uri.parse('https://alerts.example.com/v1/topics'),
      );
      expect(getTopicsRes.statusCode, 200);
      final topicsList = jsonDecode(getTopicsRes.body) as List<dynamic>;
      expect(topicsList, hasLength(1));

      // POST /{topic}
      final publishRes = await client.post(
        Uri.parse('https://alerts.example.com/api-topic'),
        headers: {
          'X-Title': 'API test alert',
          'X-Priority': '5',
        },
        body: 'Database unreachable',
      );
      expect(publishRes.statusCode, 200);
      final msgJson = jsonDecode(publishRes.body) as Map<String, dynamic>;
      expect(msgJson['incident_id'], isNotNull);

      // GET /v1/incidents
      final incidentsRes = await client.get(
        Uri.parse('https://alerts.example.com/v1/incidents'),
      );
      expect(incidentsRes.statusCode, 200);
      final incidentsList = jsonDecode(incidentsRes.body) as List<dynamic>;
      expect(incidentsList, hasLength(1));
      final firstInc = incidentsList.first as Map<String, dynamic>;
      final incidentId = firstInc['id'] as String;

      // POST /v1/incidents/{id}/ack
      final ackRes = await client.post(
        Uri.parse('https://alerts.example.com/v1/incidents/$incidentId/ack'),
      );
      expect(ackRes.statusCode, 200);

      // POST /v1/incidents/{id}/close
      final closeRes = await client.post(
        Uri.parse('https://alerts.example.com/v1/incidents/$incidentId/close'),
      );
      expect(closeRes.statusCode, 200);
    });

    test('rejects delayed messages with 400', () async {
      final client = server.httpClient;

      final res = await client.post(
        Uri.parse('https://alerts.example.com/test-topic'),
        headers: {'X-Delay': '10m'},
        body: 'delayed msg',
      );

      expect(res.statusCode, 400);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      expect(body['error'], 'scheduled delivery not supported');
    });
  });
}
