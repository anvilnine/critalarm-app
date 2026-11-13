import 'dart:convert';

import 'package:critalarm/core/api/account_results.dart';
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

/// Rule 1: proof on link, the identity cap, and removing a way to sign in
/// (api.md §3.7, 1.28.0).
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
    Object? body,
    int statusCode, {
    void Function(http.Request)? onRequest,
  }) {
    var deadCredential = 0;
    addTearDown(() => expect(deadCredential, 0));
    return HttpApiClient(
      MockClient((request) async {
        onRequest?.call(request);
        return http.Response(
          body == null ? '' : jsonEncode(body),
          statusCode,
          headers: {'content-type': 'application/json'},
        );
      }),
      sessionStore,
      onDeadCredential: () async => deadCredential++,
    );
  }

  group('rule 1: the wire format', () {
    test(
      'intent link carries proof_token, intent sign_in never does',
      () async {
        final bodies = <Map<String, dynamic>>[];
        final client = clientAnswering(
          {'account_id': 'acc_1', 'outcome': 'linked'},
          200,
          onRequest: (r) =>
              bodies.add(jsonDecode(r.body) as Map<String, dynamic>),
        );

        await client.linkAccount(
          identityToken: 'sess_new',
          intent: AccountLinkIntent.link,
          proofToken: 'sess_held',
        );
        await client.linkAccount(
          identityToken: 'sess_new',
          proofToken: 'sess_held',
        );

        expect(bodies.first['proof_token'], 'sess_held');
        expect(bodies.last.containsKey('proof_token'), isFalse);
      },
    );

    test('409 proof required and 409 cap identities are results of their '
        'own', () async {
      final proof = await clientAnswering({
        'error': 'proof required',
      }, 409).linkAccount(identityToken: 'x', intent: AccountLinkIntent.link);
      final cap = await clientAnswering({
        'error': 'cap',
        'cap': 'identities',
      }, 409).linkAccount(identityToken: 'x', intent: AccountLinkIntent.link);

      expect(proof, const AccountLinkResult.proofRequired());
      expect(cap, const AccountLinkResult.capIdentities());
    });

    test(
      'the delete goes to the row id with the session in the body',
      () async {
        late http.Request captured;
        final client = clientAnswering(
          null,
          204,
          onRequest: (r) => captured = r,
        );

        final result = await client.removeAccountIdentity(
          identityId: 'idn_2',
          identityToken: 'sess_held',
        );

        expect(captured.method, 'DELETE');
        expect(
          captured.url.toString(),
          'https://server.example/v1/account/identities/idn_2',
        );
        expect(captured.headers['authorization'], 'Bearer dv_device');
        expect(jsonDecode(captured.body), {'identity_token': 'sess_held'});
        expect(result, const AccountIdentityRemoveResult.removed());
      },
    );

    test('every documented answer to the delete reads back', () async {
      Future<AccountIdentityRemoveResult> answer(Object? body, int status) =>
          clientAnswering(body, status).removeAccountIdentity(
            identityId: 'idn_2',
            identityToken: 'sess_held',
          );

      expect(
        await answer({'error': 'unauthorized'}, 401),
        const AccountIdentityRemoveResult.unauthorized(),
      );
      expect(
        await answer({'error': 'recent sign-in required'}, 403),
        const AccountIdentityRemoveResult.recentSignInRequired(),
      );
      expect(
        await answer({'error': 'not found'}, 404),
        const AccountIdentityRemoveResult.notFound(),
      );
      expect(
        await answer({'error': 'last identity'}, 409),
        const AccountIdentityRemoveResult.lastIdentity(),
      );
      expect(
        await answer({'error': 'live incident', 'incident_id': 'inc_7'}, 409),
        const AccountIdentityRemoveResult.liveIncident(incidentId: 'inc_7'),
      );
    });
  });

  group('rule 1: the mock server answers as the contract writes it', () {
    late MockServer server;
    late HttpApiClient client;
    late DateTime clock;

    setUp(() {
      server = MockServer(
        serverInfo: const ServerInfo(
          version: '0.1.0',
          baseUrl: 'https://server.example',
          relayUrl: 'https://relay.example',
          mode: ServerModes.hosted,
        ),
      );
      clock = DateTime.utc(2026, 11, 13, 12);
      server.identityClock = () => clock;
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

    Future<List<AccountIdentityRow>> rows([String? token]) =>
        client.listAccountIdentities(identityToken: token);

    test('adding without proof, or with a session not on the account, is '
        '409 proof required', () async {
      await client.linkAccount(identityToken: 'sess_a');

      final none = await client.linkAccount(
        identityToken: 'sess_b',
        intent: AccountLinkIntent.link,
      );
      final stranger = await client.linkAccount(
        identityToken: 'sess_b',
        intent: AccountLinkIntent.link,
        proofToken: 'sess_nobody',
      );

      expect(none, const AccountLinkResult.proofRequired());
      expect(stranger, const AccountLinkResult.proofRequired());
      expect(await rows(), hasLength(1));
    });

    test('two of one provider sit on one account', () async {
      server.identityProfiles['sess_a'] = MockIdentityProfile(
        provider: 'google',
        email: 'work@example.com',
      );
      server.identityProfiles['sess_b'] = MockIdentityProfile(
        provider: 'google',
        email: 'home@example.com',
      );
      await client.linkAccount(identityToken: 'sess_a');
      final added = await client.linkAccount(
        identityToken: 'sess_b',
        intent: AccountLinkIntent.link,
        proofToken: 'sess_a',
      );

      expect(added, isA<AccountLinkLinked>());
      final list = await rows('sess_a');
      expect(list.map((r) => r.provider), ['google', 'google']);
      expect(list.first.current, isTrue);
    });

    test('a seventh identity is 409 cap identities', () async {
      await client.linkAccount(identityToken: 'sess_0');
      for (var i = 1; i < 6; i++) {
        await client.linkAccount(
          identityToken: 'sess_$i',
          intent: AccountLinkIntent.link,
          proofToken: 'sess_0',
        );
      }

      final seventh = await client.linkAccount(
        identityToken: 'sess_6',
        intent: AccountLinkIntent.link,
        proofToken: 'sess_0',
      );

      expect(seventh, const AccountLinkResult.capIdentities());
      expect(await rows(), hasLength(6));
    });

    Future<void> twoIdentities() async {
      await client.linkAccount(identityToken: 'sess_a');
      await client.linkAccount(
        identityToken: 'sess_b',
        intent: AccountLinkIntent.link,
        proofToken: 'sess_a',
      );
    }

    test('a fresh session removes another identity', () async {
      await twoIdentities();
      final b = (await rows('sess_a')).last;

      final result = await client.removeAccountIdentity(
        identityId: b.id,
        identityToken: 'sess_a',
      );

      expect(result, const AccountIdentityRemoveResult.removed());
      final left = await rows('sess_a');
      expect(left, hasLength(1));
      // The session that asked is kept: it is of an identity still there.
      expect(left.single.current, isTrue);
    });

    test('a session older than 300 seconds is 403 recent sign-in required, '
        'and a new one goes through', () async {
      await twoIdentities();
      final b = (await rows('sess_a')).last;
      clock = clock.add(const Duration(seconds: 301));

      final stale = await client.removeAccountIdentity(
        identityId: b.id,
        identityToken: 'sess_a',
      );
      final fresh = server.mintSession('sess_a');
      final again = await client.removeAccountIdentity(
        identityId: b.id,
        identityToken: fresh,
      );

      expect(stale, const AccountIdentityRemoveResult.recentSignInRequired());
      expect(again, const AccountIdentityRemoveResult.removed());
      // The new session is of an identity on the account, so it reads as
      // current.
      expect((await rows(fresh)).single.current, isTrue);
    });

    test(
      'removing the identity that asked takes its sessions with it',
      () async {
        await twoIdentities();
        final a = (await rows('sess_a')).first;

        final result = await client.removeAccountIdentity(
          identityId: a.id,
          identityToken: 'sess_a',
        );

        expect(result, const AccountIdentityRemoveResult.removed());
        final left = await rows('sess_a');
        expect(left, hasLength(1));
        expect(left.single.current, isFalse);
        expect(left.single.email, isNull);
      },
    );

    test('a removed identity sessions stop working as proof', () async {
      await twoIdentities();
      final b = (await rows('sess_a')).last;
      await client.removeAccountIdentity(
        identityId: b.id,
        identityToken: 'sess_a',
      );

      final result = await client.removeAccountIdentity(
        identityId: (await rows()).single.id,
        identityToken: 'sess_b',
      );

      expect(result, const AccountIdentityRemoveResult.unauthorized());
    });

    test('the last identity, an unknown row, a stranger session and an open '
        'alarm are refused', () async {
      await client.linkAccount(identityToken: 'sess_a');
      final a = (await rows()).single;

      expect(
        await client.removeAccountIdentity(
          identityId: a.id,
          identityToken: 'sess_a',
        ),
        const AccountIdentityRemoveResult.lastIdentity(),
      );
      await client.linkAccount(
        identityToken: 'sess_b',
        intent: AccountLinkIntent.link,
        proofToken: 'sess_a',
      );
      expect(
        await client.removeAccountIdentity(
          identityId: 'idn_nope',
          identityToken: 'sess_a',
        ),
        const AccountIdentityRemoveResult.notFound(),
      );
      expect(
        await client.removeAccountIdentity(
          identityId: a.id,
          identityToken: 'sess_nobody',
        ),
        const AccountIdentityRemoveResult.unauthorized(),
      );
      server.createTopic(name: 'prod_down', critical: true);
      final incidentId = server
          .publishMessage('prod_down', message: 'down', priority: 5)
          .incidentId!;
      expect(
        await client.removeAccountIdentity(
          identityId: a.id,
          identityToken: 'sess_a',
        ),
        AccountIdentityRemoveResult.liveIncident(incidentId: incidentId),
      );
    });
  });
}
