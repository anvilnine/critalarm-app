import 'dart:io';

import 'package:critalarm/features/api/crit_alarm_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  late Process serverProcess;
  late int serverPort;
  late String serverUrl;
  late http.Client httpClient;
  late CritAlarmClient defaultClient;

  setUpAll(() async {
    // Pick an available port.
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    serverPort = socket.port;
    await socket.close();
    serverUrl = 'http://localhost:$serverPort';

    // Spawn the plain Node mock server.
    serverProcess = await Process.start(
      'node',
      ['mock-server/server.js'],
      environment: {'PORT': serverPort.toString()},
    );

    // Wait for the mock server to boot.
    final testUri = Uri.parse('$serverUrl/v1/info');
    final tempClient = http.Client();
    var booted = false;
    for (var i = 0; i < 50; i++) {
      try {
        final res = await tempClient.get(testUri);
        if (res.statusCode == 200) {
          booted = true;
          break;
        }
      } on Object catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    tempClient.close();
    if (!booted) {
      serverProcess.kill();
      fail('Mock server failed to boot on port $serverPort');
    }
  });

  tearDownAll(() {
    serverProcess.kill();
  });

  setUp(() {
    httpClient = http.Client();
    defaultClient = CritAlarmClient(
      serverUrl,
      httpClient,
      deviceToken: 'dv_default_token',
      topicToken: 'tk_prod_token',
    );
  });

  tearDown(() {
    httpClient.close();
  });

  group('CritAlarmClient - server info', () {
    test('info() returns 200 with ServerInfo', () async {
      final result = await defaultClient.info();

      expect(result.isSuccess(), isTrue);
      final info = result.getOrNull()!;
      expect(info.name, equals('critalarm'));
      expect(info.version, equals('0.1.0'));
      expect(info.baseUrl, equals(serverUrl));
      expect(info.mode, equals('relay'));
      expect(info.relayContent, equals('none'));
    });
  });

  group('CritAlarmClient - device management', () {
    test(
      'registerDevice() registers a device and returns tokens/caps',
      () async {
        final result = await defaultClient.registerDevice(
          deviceId: 'dev_fresh_123',
          platform: 'ios',
          pushToken: 'apns_token_abc',
          appVersion: '1.0.0',
        );

        expect(result.isSuccess(), isTrue);
        final reg = result.getOrNull()!;
        expect(reg.deviceToken.startsWith('dv_'), isTrue);
        expect(reg.accountId.startsWith('acc_'), isTrue);
        expect(reg.tier, equals('free'));
        expect(reg.caps.devices, equals(1));
        expect(reg.caps.criticalTopics, equals(1));
        expect(reg.caps.p4Daily, equals(50));
      },
    );

    test('updateDevice() updates push token successfully', () async {
      final result = await defaultClient.updateDevice(
        deviceId: 'dev_default',
        pushToken: 'new_push_token_456',
        appVersion: '1.0.1',
      );

      expect(result.isSuccess(), isTrue);
    });

    test('subscribe() and unsubscribe() manage topic subscriptions', () async {
      final subResult = await defaultClient.subscribe(
        'dev_default',
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(subResult.isSuccess(), isTrue);

      final unsubResult = await defaultClient.unsubscribe(
        'dev_default',
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(unsubResult.isSuccess(), isTrue);
    });
  });

  group('CritAlarmClient - topics', () {
    test('listTopics() lists topics owned by the account', () async {
      final result = await defaultClient.listTopics();

      expect(result.isSuccess(), isTrue);
      final topics = result.getOrNull()!;
      expect(topics.any((t) => t.name == 'prod'), isTrue);
    });

    test(
      'createTopic() creates a topic with critical: false and one-time token',
      () async {
        final topicName = 'billing_${DateTime.now().millisecondsSinceEpoch}';
        final result = await defaultClient.createTopic(topicName);

        expect(result.isSuccess(), isTrue);
        final topicWithToken = result.getOrNull()!;
        expect(topicWithToken.name, equals(topicName));
        // Apple entitlement commitment: critical must default to false.
        expect(topicWithToken.critical, isFalse);
        expect(topicWithToken.token.startsWith('tk_'), isTrue);

        // Verify created topic is listed without returning the token again.
        final listResult = await defaultClient.listTopics();
        expect(listResult.isSuccess(), isTrue);
        final listedTopic = listResult.getOrNull()!.firstWhere(
          (t) => t.name == topicName,
        );
        expect(listedTopic.critical, isFalse);
      },
    );

    test('patchTopic() updates topic settings', () async {
      final result = await defaultClient.patchTopic(
        'prod',
        critical: true,
        repeatIntervalS: 45,
        maxRingS: 3600,
        deskTimerS: 900,
      );

      expect(result.isSuccess(), isTrue);
      final updated = result.getOrNull()!;
      expect(updated.critical, isTrue);
      expect(updated.repeatIntervalS, equals(45));
      expect(updated.maxRingS, equals(3600));
      expect(updated.deskTimerS, equals(900));
    });

    test('deleteTopic() deletes an existing topic', () async {
      final topicName = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final createRes = await defaultClient.createTopic(topicName);
      expect(createRes.isSuccess(), isTrue);

      final deleteRes = await defaultClient.deleteTopic(topicName);
      expect(deleteRes.isSuccess(), isTrue);
    });
  });

  group('CritAlarmClient - test alarm and incidents', () {
    test('testAlarm() triggers an alarm and returns an incident ID', () async {
      // Ensure topic is critical
      await defaultClient.patchTopic('prod', critical: true);

      final result = await defaultClient.testAlarm('prod');

      expect(result.isSuccess(), isTrue);
      final incidentId = result.getOrNull()!;
      expect(incidentId.startsWith('inc_'), isTrue);
    });

    test('listIncidents() and getIncident() fetch incident details', () async {
      // Trigger an incident first
      final alarmRes = await defaultClient.testAlarm('prod');
      expect(alarmRes.isSuccess(), isTrue);
      final incidentId = alarmRes.getOrNull()!;

      final listResult = await defaultClient.listIncidents(
        limit: 10,
        state: 'open',
        topic: 'prod',
      );
      expect(listResult.isSuccess(), isTrue);
      expect(listResult.getOrNull()!.any((i) => i.id == incidentId), isTrue);

      final getResult = await defaultClient.getIncident(incidentId);
      expect(getResult.isSuccess(), isTrue);
      final incident = getResult.getOrNull()!;
      expect(incident.id, equals(incidentId));
      expect(incident.topic, equals('prod'));
      expect(incident.state, equals('open'));
      expect(incident.messages.isNotEmpty, isTrue);
    });

    test('ack() transitions incident from open to acked', () async {
      final alarmRes = await defaultClient.testAlarm('prod');
      final incidentId = alarmRes.getOrNull()!;

      final ackRes = await defaultClient.ack(incidentId);

      expect(ackRes.isSuccess(), isTrue);
      final incident = ackRes.getOrNull()!;
      expect(incident.state, equals('acked'));
      expect(incident.ackedAt, isNotNull);
      expect(incident.deskTimerFiresAt, isNotNull);
    });

    test('close() transitions incident from acked to closed', () async {
      final alarmRes = await defaultClient.testAlarm('prod');
      final incidentId = alarmRes.getOrNull()!;

      await defaultClient.ack(incidentId);
      final closeRes = await defaultClient.close(incidentId);

      expect(closeRes.isSuccess(), isTrue);
      final incident = closeRes.getOrNull()!;
      expect(incident.state, equals('closed'));
      expect(incident.closedAt, isNotNull);
    });
  });

  group('CritAlarmClient - poll', () {
    test('poll() returns newline-delimited JSON messages', () async {
      final result = await defaultClient.poll('prod');

      expect(result.isSuccess(), isTrue);
      final messages = result.getOrNull()!;
      expect(messages.isNotEmpty, isTrue);
      expect(messages.first.topic, equals('prod'));
      expect(messages.first.incidentId, isNotNull);
    });
  });

  group('CritAlarmClient - error handling and security contracts', () {
    test('a 401 response body maps to ApiFailure with code 40101', () async {
      final unauthenticatedClient = CritAlarmClient(
        serverUrl,
        httpClient,
      );

      final result = await unauthenticatedClient.listTopics();

      expect(result.isError(), isTrue);
      final failure = result.exceptionOrNull();
      expect(failure, isA<ApiFailure>());
      final apiFailure = failure!;
      expect(apiFailure.code, equals(40101));
      expect(apiFailure.http, equals(401));
      expect(apiFailure.error, equals('unauthorized'));
    });

    test(
      'a topic belonging to another account returns 404, never 403',
      () async {
        final otherAccountClient = CritAlarmClient(
          serverUrl,
          httpClient,
          deviceToken: 'dv_other_account_token_999',
        );

        // 'prod' belongs to acc_default, so other account must get 404
        final result = await otherAccountClient.patchTopic(
          'prod',
          critical: true,
        );

        expect(result.isError(), isTrue);
        final failure = result.exceptionOrNull()!;
        expect(failure.http, equals(404));
        expect(failure.code, equals(40401));
      },
    );

    test('testAlarm on non-critical topic returns 409', () async {
      final topicName = 'non_crit_${DateTime.now().millisecondsSinceEpoch}';
      final createRes = await defaultClient.createTopic(topicName);
      expect(createRes.isSuccess(), isTrue);

      final testRes = await defaultClient.testAlarm(topicName);

      expect(testRes.isError(), isTrue);
      final failure = testRes.exceptionOrNull()!;
      expect(failure.http, equals(409));
    });

    test('ack on non-open incident returns 409', () async {
      final alarmRes = await defaultClient.testAlarm('prod');
      final incidentId = alarmRes.getOrNull()!;

      await defaultClient.ack(incidentId);
      // Second ack must return 409
      final secondAck = await defaultClient.ack(incidentId);

      expect(secondAck.isError(), isTrue);
      final failure = secondAck.exceptionOrNull()!;
      expect(failure.http, equals(409));
    });
  });
}
