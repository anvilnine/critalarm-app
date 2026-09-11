import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockServer server;
  late MockApiClient client;

  setUp(() {
    server = MockServer();
    client = MockApiClient(server);
  });

  group('MockApiClient state transitions and commitments', () {
    test('topic critical toggle defaults to false', () async {
      final topic = await client.createTopic(name: 'default-topic');

      expect(topic.name, 'default-topic');
      expect(topic.critical, isFalse); // Non-negotiable Apple commitment
    });

    test(
      'create topic returns token once, subsequent get omits token',
      () async {
        final created = await client.createTopic(name: 'token-topic');
        expect(created.token, isNotNull);
        expect(created.token, startsWith('tk_'));

        final list = await client.getTopics();
        final retrieved = list.firstWhere((t) => t.name == 'token-topic');
        expect(retrieved.token, isNull);
      },
    );

    test(
      'test endpoint requires critical: true, returns 409 otherwise',
      () async {
        await client.createTopic(name: 'non-critical');

        expect(
          () => client.triggerTest(topic: 'non-critical'),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
          ),
        );

        // Now enable critical
        await client.updateTopic('non-critical', critical: true);
        final incidentId = await client.triggerTest(topic: 'non-critical');
        expect(incidentId, startsWith('inc_'));
      },
    );

    test('lifecycle state transitions: open -> acked -> closed', () async {
      await client.createTopic(name: 'ops', critical: true);
      final msg = await client.publishMessage('ops', priority: 5);
      final incId = msg.incidentId!;

      // 1. Initial state is open
      var incident = await client.getIncident(incId);
      expect(incident.state, IncidentStates.open);
      expect(incident.isOpen, isTrue);

      // 2. Ack transitions open -> acked
      incident = await client.ackIncident(incId);
      expect(incident.state, IncidentStates.acked);
      expect(incident.isAcked, isTrue);
      expect(incident.ackedAt, isNotNull);
      expect(incident.deskTimerFiresAt, isNotNull);

      // 3. Close transitions acked -> closed
      incident = await client.closeIncident(incId);
      expect(incident.state, IncidentStates.closed);
      expect(incident.isClosed, isTrue);
      expect(incident.closedAt, isNotNull);
    });

    test('invalid state transitions return 409', () async {
      await client.createTopic(name: 'ops', critical: true);
      final msg = await client.publishMessage('ops', priority: 5);
      final incId = msg.incidentId!;

      // Close when open -> 409
      expect(
        () => client.closeIncident(incId),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );

      // Transition to acked
      await client.ackIncident(incId);

      // Ack when already acked -> 409
      expect(
        () => client.ackIncident(incId),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );

      // Transition to closed
      await client.closeIncident(incId);

      // Ack or close when closed -> 409
      expect(
        () => client.ackIncident(incId),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
      expect(
        () => client.closeIncident(incId),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });

    test('registerDevice returns response with account id and caps', () async {
      const reg = DeviceRegistration(
        deviceId: 'dev_client_test',
        platform: 'android',
        pushToken: 'fcm_token_123',
        appVersion: '1.2.0',
      );

      final response = await client.registerDevice(reg);

      expect(response.accountId, startsWith('acc_'));
      expect(response.deviceToken, startsWith('dv_'));
      expect(response.tier, 'free');
      expect(response.caps.devices, 1);
      expect(response.caps.criticalTopics, 1);
      expect(response.caps.p4Daily, 50);
    });

    test('can switch fixtures easily via server', () async {
      client.server.loadFixture(FaceState.calm);
      var topics = await client.getTopics();
      expect(topics.length, 4);

      client.server.loadFixture(FaceState.watching);
      topics = await client.getTopics();
      expect(topics, isEmpty);

      client.server.loadFixture(FaceState.alarmed);
      final incidents = await client.getIncidents(state: 'open');
      expect(incidents.length, 1);
      expect(incidents.first.topic, 'prod-db');
    });
  });
}
