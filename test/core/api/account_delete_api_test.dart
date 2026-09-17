import 'dart:convert';

import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/http_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/server_info.dart';
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
        baseUri: Uri.parse('https://server.example'),
        relayUri: Uri.parse('https://relay.example'),
        mode: ServerMode.hosted,
        managementCredential: 'dv_device',
      ),
    );
  });

  /// A server that answers the delete with one scripted response.
  HttpApiClient clientAnswering(
    String body,
    int statusCode, {
    void Function(http.Request)? onRequest,
    Future<void> Function()? onDeadCredential,
  }) {
    return HttpApiClient(
      MockClient((request) async {
        onRequest?.call(request);
        return http.Response(
          body,
          statusCode,
          headers: {'content-type': 'application/json'},
        );
      }),
      sessionStore,
      onDeadCredential: onDeadCredential,
    );
  }

  group('the wire format', () {
    test('sends dv_ in the header and identity_token in the body', () async {
      late http.Request captured;
      final client = clientAnswering(
        '',
        204,
        onRequest: (request) => captured = request,
      );

      await client.deleteAccount(identityToken: 'session_abc');

      expect(captured.method, 'DELETE');
      expect(captured.url.toString(), 'https://server.example/v1/account');
      expect(captured.headers['authorization'], 'Bearer dv_device');
      expect(jsonDecode(captured.body), {'identity_token': 'session_abc'});
    });

    test('with no identity it sends no body at all', () async {
      late http.Request captured;
      final client = clientAnswering(
        '',
        204,
        onRequest: (request) => captured = request,
      );

      await client.deleteAccount();

      expect(captured.headers['authorization'], 'Bearer dv_device');
      // Not a null and not an empty string: the field is simply absent, so
      // the server reads an account with no identity rather than an identity
      // token that does not match.
      expect(captured.body, '');
      expect(captured.headers.containsKey('content-type'), isFalse);
    });
  });

  group('every answer maps to its own row', () {
    test('204 is deleted', () async {
      final client = clientAnswering('', 204);

      final result = await client.deleteAccount();

      expect(result, const AccountDeleteResult.deleted());
    });

    test('409 live incident keeps the incident id', () async {
      final client = clientAnswering(
        jsonEncode({'error': 'live incident', 'incident_id': 'inc_42'}),
        409,
      );

      final result = await client.deleteAccount();

      expect(
        result,
        const AccountDeleteResult.liveIncident(incidentId: 'inc_42'),
      );
    });

    test('401 is unauthorized', () async {
      final client = clientAnswering(
        jsonEncode({'error': 'unauthorized'}),
        401,
      );

      final result = await client.deleteAccount(identityToken: 'session_abc');

      expect(result, const AccountDeleteResult.unauthorized());
    });

    test('the tolerated 401 does not read as a dead credential', () async {
      var recoveries = 0;
      final client = clientAnswering(
        jsonEncode({'error': 'unauthorized'}),
        401,
        onDeadCredential: () async => recoveries++,
      );

      await client.deleteAccount(identityToken: 'session_abc');

      // This 401 is a refusal about the identity, not a device token the
      // server has forgotten. Starting the phone over here would throw away
      // an account that is still there.
      expect(recoveries, 0);
    });
  });

  group('a 401 on the device token', () {
    test('asks for a recovery, then still throws', () async {
      var recoveries = 0;
      final client = clientAnswering(
        jsonEncode({'error': 'unauthorized'}),
        401,
        onDeadCredential: () async => recoveries++,
      );

      await expectLater(
        client.getTopics(),
        throwsA(isA<ApiException>()),
      );
      expect(recoveries, 1);
    });
  });

  group('the mock server answers the same rows', () {
    late MockServer server;
    late HttpApiClient client;

    Future<void> registerDevice() async {
      final response = server.registerDevice(
        const DeviceRegistration(
          deviceId: 'dev_1',
          platform: 'ios',
          pushToken: 'push',
          appVersion: '0.1.0',
        ),
      );
      sessionStore.session = ApiSession(
        baseUri: Uri.parse('https://server.example'),
        relayUri: Uri.parse('https://relay.example'),
        mode: ServerMode.hosted,
        managementCredential: response.deviceToken!,
      );
    }

    MockServer serverInMode(String mode) => MockServer(
      serverInfo: ServerInfo(
        version: '0.1.0',
        baseUrl: 'https://server.example',
        relayUrl: 'https://relay.example',
        mode: mode,
      ),
    );

    setUp(() async {
      server = serverInMode(ServerModes.hosted);
      client = HttpApiClient(server.httpClient, sessionStore);
      await registerDevice();
    });

    test('an anonymous account deletes on the device token alone', () async {
      final result = await client.deleteAccount();

      expect(result, const AccountDeleteResult.deleted());
    });

    test('a signed-in account needs its identity', () async {
      await client.linkAccount(identityToken: 'session_abc');

      expect(
        await client.deleteAccount(),
        const AccountDeleteResult.unauthorized(),
      );
      expect(
        await client.deleteAccount(identityToken: 'session_other'),
        const AccountDeleteResult.unauthorized(),
      );
      expect(
        await client.deleteAccount(identityToken: 'session_abc'),
        const AccountDeleteResult.deleted(),
      );
    });

    test('an open alarm blocks and names itself', () async {
      server.createTopic(name: 'prod', critical: true);
      final published = server.publishMessage(
        'prod',
        message: 'db01 is down',
        priority: 5,
      );

      final result = await client.deleteAccount();

      expect(
        result,
        AccountDeleteResult.liveIncident(incidentId: published.incidentId!),
      );
    });

    test('an acked alarm does not block, unlike a merge', () async {
      server.createTopic(name: 'prod', critical: true);
      final published = server.publishMessage(
        'prod',
        message: 'db01 is down',
        priority: 5,
      );
      server.ackIncident(published.incidentId!);

      // Nothing is ringing once it is acknowledged, and api.md §3.7 says a
      // person must never be stuck unable to leave.
      expect(await client.deleteAccount(), const AccountDeleteResult.deleted());
    });

    test('selfhosted answers 501', () async {
      server = serverInMode(ServerModes.selfhosted);
      client = HttpApiClient(server.httpClient, sessionStore);
      await registerDevice();

      await expectLater(
        client.deleteAccount(),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 501),
        ),
      );
    });
  });
}
