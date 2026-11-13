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

/// Rule 1: `GET /v1/account/identities` (api.md §3.7, 1.28.0).
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

  HttpApiClient clientAnswering(
    Object body,
    int statusCode, {
    void Function(http.Request)? onRequest,
  }) {
    return HttpApiClient(
      MockClient((request) async {
        onRequest?.call(request);
        return http.Response(
          jsonEncode(body),
          statusCode,
          headers: {'content-type': 'application/json'},
        );
      }),
      sessionStore,
    );
  }

  group('rule 1: the wire format', () {
    test('the session goes in X-Identity-Token, dv_ in the header', () async {
      late http.Request captured;
      final client = clientAnswering(
        {'identities': <Object>[]},
        200,
        onRequest: (request) => captured = request,
      );

      await client.listAccountIdentities(identityToken: 'sess_held');

      expect(captured.method, 'GET');
      expect(
        captured.url.toString(),
        'https://server.example/v1/account/identities',
      );
      expect(captured.headers['authorization'], 'Bearer dv_device');
      expect(captured.headers['x-identity-token'], 'sess_held');
      expect(captured.body, isEmpty);
    });

    test('no session held, no X-Identity-Token header', () async {
      late http.Request captured;
      final client = clientAnswering(
        {'identities': <Object>[]},
        200,
        onRequest: (request) => captured = request,
      );

      await client.listAccountIdentities();

      expect(captured.headers.containsKey('x-identity-token'), isFalse);
    });

    test('a row reads every field the contract writes', () async {
      final rows = await clientAnswering({
        'identities': [
          {
            'id': 'idn_2',
            'provider': 'apple',
            'email_hidden': true,
            'linked_at': 1763000500,
          },
          {
            'id': 'idn_1',
            'provider': 'google',
            'email_hint': 'z•••@gmail.com',
            'email': 'zed@gmail.com',
            'email_hidden': false,
            'linked_at': 1763000000,
            'current': true,
          },
        ],
      }, 200).listAccountIdentities(identityToken: 'sess_held');

      // Oldest first.
      expect(rows.map((r) => r.id), ['idn_1', 'idn_2']);
      expect(
        rows.first,
        AccountIdentityRow(
          id: 'idn_1',
          provider: 'google',
          email: 'zed@gmail.com',
          emailHint: 'z•••@gmail.com',
          linkedAt: DateTime.fromMillisecondsSinceEpoch(
            1763000000 * 1000,
            isUtc: true,
          ),
          current: true,
        ),
      );
      expect(rows.last.emailHidden, isTrue);
      expect(rows.last.emailHint, isNull);
      expect(rows.last.email, isNull);
      expect(rows.last.current, isFalse);
    });

    test('a bad device token is a 401', () async {
      final client = clientAnswering({'error': 'unauthorized'}, 401);

      await expectLater(
        client.listAccountIdentities(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
    });
  });

  group('rule 1: the mock server answers as the contract writes it', () {
    late MockServer server;
    late HttpApiClient client;

    setUp(() {
      server = MockServer(
        serverInfo: const ServerInfo(
          version: '0.1.0',
          baseUrl: 'https://server.example',
          relayUrl: 'https://relay.example',
          mode: ServerModes.hosted,
        ),
      );
      client = HttpApiClient(server.httpClient, sessionStore);
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
    });

    test('an account with no identity lists nothing', () async {
      expect(await client.listAccountIdentities(), isEmpty);
    });

    test('a device token alone gets the hint and no address', () async {
      server.identityProfiles['sess_zed'] = MockIdentityProfile(
        provider: 'google',
        email: 'zed@gmail.com',
      );
      await client.linkAccount(identityToken: 'sess_zed');

      final rows = await client.listAccountIdentities();

      expect(rows, hasLength(1));
      expect(rows.single.provider, 'google');
      expect(rows.single.emailHint, 'z•••@gmail.com');
      expect(rows.single.email, isNull);
      expect(rows.single.current, isFalse);
    });

    test('a session of an identity on it unmasks and marks current', () async {
      server.identityProfiles['sess_zed'] = MockIdentityProfile(
        provider: 'google',
        email: 'zed@gmail.com',
      );
      await client.linkAccount(identityToken: 'sess_zed');

      final rows = await client.listAccountIdentities(
        identityToken: 'sess_zed',
      );

      expect(rows.single.email, 'zed@gmail.com');
      expect(rows.single.current, isTrue);
    });

    test('a session of no identity on it masks, and is never a 401', () async {
      await client.linkAccount(identityToken: 'sess_zed');

      final rows = await client.listAccountIdentities(
        identityToken: 'sess_somebody_else',
      );

      expect(rows.single.email, isNull);
      expect(rows.single.current, isFalse);
    });

    test(
      'an Apple relay address is hidden, with or without a session',
      () async {
        server.identityProfiles['sess_apple'] = MockIdentityProfile(
          provider: 'apple',
          email: 'abc123@privaterelay.appleid.com',
        );
        await client.linkAccount(identityToken: 'sess_apple');

        for (final token in [null, 'sess_apple']) {
          final row = (await client.listAccountIdentities(
            identityToken: token,
          )).single;
          expect(row.emailHidden, isTrue);
          expect(row.emailHint, isNull);
          expect(row.email, isNull);
        }
      },
    );

    test('rows come back oldest first', () async {
      var clock = DateTime.utc(2026, 11);
      server.identityClock = () => clock;
      await client.linkAccount(identityToken: 'sess_first');
      clock = DateTime.utc(2026, 11, 2);
      await client.linkAccount(
        identityToken: 'sess_second',
        intent: AccountLinkIntent.link,
      );

      final rows = await client.listAccountIdentities(
        identityToken: 'sess_second',
      );

      expect(rows, hasLength(2));
      expect(rows.first.current, isFalse);
      expect(rows.last.current, isTrue);
      expect(rows.first.linkedAt.isBefore(rows.last.linkedAt), isTrue);
    });
  });
}
