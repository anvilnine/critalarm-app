import 'dart:convert';

import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/http_api_client.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final class _MemoryApiSessionStore implements ApiSessionStore {
  _MemoryApiSessionStore(this.session);

  ApiSession? session;

  @override
  Future<void> clear() async => session = null;

  @override
  Future<ApiSession?> read() async => session;

  @override
  Future<void> write(ApiSession session) async => this.session = session;
}

void main() {
  late _MemoryApiSessionStore sessionStore;

  setUp(() {
    sessionStore = _MemoryApiSessionStore(
      ApiSession(
        baseUri: Uri.parse('https://server.example/base'),
        relayUri: Uri.parse('https://relay.example'),
        mode: ServerMode.selfhosted,
        managementCredential: 'ad_secret',
      ),
    );
  });

  test('GET info uses candidate URL without authorization', () async {
    late http.Request captured;
    final client = HttpApiClient(
      MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'name': 'critalarm',
            'version': '0.1.0',
            'base_url': 'https://canonical.example',
            'relay_url': 'https://relay.example',
            'relay_content': 'none',
            'mode': 'selfhosted',
          }),
          200,
        );
      }),
      sessionStore,
    );

    final info = await client.getServerInfo(
      Uri.parse('https://candidate.example/prefix'),
    );

    expect(captured.method, 'GET');
    expect(captured.url.toString(), 'https://candidate.example/prefix/v1/info');
    expect(captured.headers, isNot(contains('authorization')));
    expect(info.baseUrl, 'https://canonical.example');
  });

  test(
    'management request reads the latest session and sends bearer auth',
    () async {
      final requests = <http.Request>[];
      final client = HttpApiClient(
        MockClient((request) async {
          requests.add(request);
          return http.Response('[]', 200);
        }),
        sessionStore,
      );

      await client.getTopics();
      await sessionStore.write(
        ApiSession(
          baseUri: Uri.parse('https://hosted.example'),
          relayUri: Uri.parse('https://hosted.example'),
          mode: ServerMode.hosted,
          managementCredential: 'dv_new',
        ),
      );
      await client.getTopics();

      expect(
        requests[0].url.toString(),
        'https://server.example/base/v1/topics',
      );
      expect(requests[0].headers['authorization'], 'Bearer ad_secret');
      expect(requests[1].url.toString(), 'https://hosted.example/v1/topics');
      expect(requests[1].headers['authorization'], 'Bearer dv_new');
    },
  );

  test(
    'topic and incident requests encode paths and query parameters',
    () async {
      final requests = <http.Request>[];
      final client = HttpApiClient(
        MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/tokens')) {
            return http.Response(
              '{"token":"tk_new","token_id":"tok_new"}',
              201,
            );
          }
          if (request.url.path.endsWith('/ack')) {
            return http.Response(
              '{"id":"inc/a","topic":"prod db","state":"acked", '
              '"messages":[]}',
              200,
            );
          }
          return http.Response('', 204);
        }),
        sessionStore,
      );

      expect((await client.createTopicToken('prod db')).tokenId, 'tok_new');
      await client.deleteTopicToken('prod db', 'token/id');
      await client.ackIncident('inc/a');

      expect(requests[0].url.path, '/base/v1/topics/prod%20db/tokens');
      expect(
        requests[1].url.path,
        '/base/v1/topics/prod%20db/tokens/token%2Fid',
      );
      expect(requests[2].url.path, '/base/v1/incidents/inc%2Fa/ack');
    },
  );

  test('trigger test encodes topic in query and decodes incident id', () async {
    late http.Request captured;
    final client = HttpApiClient(
      MockClient((request) async {
        captured = request;
        return http.Response('{"incident_id":"inc_123"}', 200);
      }),
      sessionStore,
    );

    final id = await client.triggerTest(topic: 'prod db/&');

    expect(captured.method, 'POST');
    expect(captured.url.path, '/base/v1/test');
    expect(captured.url.queryParameters['topic'], 'prod db/&');
    expect(id, 'inc_123');
  });

  test('first device registration uses relay without authorization', () async {
    late http.Request captured;
    final client = HttpApiClient(
      MockClient((request) async {
        captured = request;
        return http.Response(
          '{"device_token":"dv_1","account_id":"acc_1","tier":"free",'
          '"caps":{"devices":1,"critical_topics":1,"p4_daily":50}}',
          201,
        );
      }),
      sessionStore,
    );

    final response = await client.registerDevice(
      const DeviceRegistration(
        deviceId: 'dev_1',
        platform: 'android',
        pushToken: 'fcm_1',
        appVersion: '1.0.0',
      ),
    );

    expect(captured.method, 'POST');
    expect(captured.url.toString(), 'https://relay.example/relay/v1/devices');
    expect(captured.headers, isNot(contains('authorization')));
    expect(jsonDecode(captured.body), {
      'device_id': 'dev_1',
      'platform': 'android',
      'push_token': 'fcm_1',
      'app_version': '1.0.0',
    });
    expect(response.accountId, 'acc_1');
  });

  test('204 response is accepted without JSON decoding', () async {
    final client = HttpApiClient(
      MockClient((_) async => http.Response('', 204)),
      sessionStore,
    );

    await expectLater(client.deleteTopic('prod'), completes);
  });

  test('API error maps status, message, code, and cap', () async {
    final client = HttpApiClient(
      MockClient(
        (_) async => http.Response(
          '{"error":"cap","http":429,"code":42901,'
          '"cap":"critical_topics"}',
          429,
        ),
      ),
      sessionStore,
    );

    await expectLater(
      client.getTopics(),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 429)
            .having((error) => error.message, 'message', 'cap')
            .having((error) => error.code, 'code', 42901)
            .having((error) => error.cap, 'cap', 'critical_topics'),
      ),
    );
  });

  test('malformed successful JSON is rejected', () async {
    final client = HttpApiClient(
      MockClient((_) async => http.Response('{not json', 200)),
      sessionStore,
    );

    await expectLater(client.getTopics(), throwsA(isA<FormatException>()));
  });

  test('transport failure is propagated', () async {
    final client = HttpApiClient(
      MockClient((_) async => throw http.ClientException('offline')),
      sessionStore,
    );

    await expectLater(client.getTopics(), throwsA(isA<http.ClientException>()));
  });
}
