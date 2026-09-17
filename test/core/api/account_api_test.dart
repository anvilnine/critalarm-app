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

  /// A server that answers every account call with one scripted response.
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

  group('the wire format', () {
    test(
      'link sends dv_ in the header and identity_token in the body',
      () async {
        late http.Request captured;
        final client = clientAnswering(
          {'account_id': 'acc_1', 'outcome': 'claimed'},
          200,
          onRequest: (request) => captured = request,
        );

        await client.linkAccount(identityToken: 'session_abc');

        expect(captured.method, 'POST');
        expect(
          captured.url.toString(),
          'https://server.example/v1/account/link',
        );
        expect(captured.headers['authorization'], 'Bearer dv_device');
        final body = jsonDecode(captured.body) as Map<String, dynamic>;
        expect(body['identity_token'], 'session_abc');
        // The other way round is the mistake this test exists to catch.
        expect(body.containsKey('device_token'), isFalse);
        expect(
          captured.headers['authorization'],
          isNot(contains('session_abc')),
        );
      },
    );

    test('merge and switch carry into_account in the body', () async {
      late http.Request captured;
      final merge = clientAnswering(
        {'account_id': 'acc_2', 'merged_from': 'acc_1'},
        200,
        onRequest: (request) => captured = request,
      );
      await merge.mergeAccount(
        identityToken: 'session_abc',
        intoAccount: 'acc_2',
      );
      expect(captured.url.path, '/v1/account/merge');
      expect(
        jsonDecode(captured.body),
        {'identity_token': 'session_abc', 'into_account': 'acc_2'},
      );

      final switched = clientAnswering(
        {'account_id': 'acc_2'},
        200,
        onRequest: (request) => captured = request,
      );
      await switched.switchAccount(
        identityToken: 'session_abc',
        intoAccount: 'acc_2',
      );
      expect(captured.url.path, '/v1/account/switch');
      expect(captured.headers['authorization'], 'Bearer dv_device');
    });
  });

  group('every documented answer', () {
    test('link 200 claimed', () async {
      final result = await clientAnswering({
        'account_id': 'acc_1',
        'outcome': 'claimed',
      }, 200).linkAccount(identityToken: 'session_abc');

      expect(result, const AccountLinkResult.claimed(accountId: 'acc_1'));
    });

    test('link 200 attached', () async {
      final result = await clientAnswering({
        'account_id': 'acc_9',
        'outcome': 'attached',
      }, 200).linkAccount(identityToken: 'session_abc');

      expect(result, const AccountLinkResult.attached(accountId: 'acc_9'));
    });

    test('link 409 choose', () async {
      final result = await clientAnswering({
        'error': 'choose',
        'into_account': 'acc_9',
        'topics': 3,
        'incidents': 12,
      }, 409).linkAccount(identityToken: 'session_abc');

      expect(result, isA<AccountLinkChoose>());
    });

    test('link 409 account has another identity', () async {
      final result = await clientAnswering({
        'error': 'account has another identity',
      }, 409).linkAccount(identityToken: 'session_abc');

      expect(result, const AccountLinkResult.accountHasAnotherIdentity());
    });

    test('link 401', () async {
      final result = await clientAnswering(
        {'error': 'unauthorized'},
        401,
      ).linkAccount(identityToken: 'session_abc');

      expect(result, const AccountLinkResult.unauthorized());
    });

    test('merge 200', () async {
      final result =
          await clientAnswering({
            'account_id': 'acc_9',
            'merged_from': 'acc_1',
          }, 200).mergeAccount(
            identityToken: 'session_abc',
            intoAccount: 'acc_9',
          );

      expect(
        result,
        const AccountMergeResult.merged(
          accountId: 'acc_9',
          mergedFrom: 'acc_1',
        ),
      );
    });

    test('merge 409 live incident', () async {
      final result =
          await clientAnswering({
            'error': 'live incident',
            'incident_id': 'inc_7',
          }, 409).mergeAccount(
            identityToken: 'session_abc',
            intoAccount: 'acc_9',
          );

      expect(
        result,
        const AccountMergeResult.liveIncident(incidentId: 'inc_7'),
      );
    });

    test('merge 409 already merged', () async {
      final result =
          await clientAnswering({
            'error': 'already merged',
          }, 409).mergeAccount(
            identityToken: 'session_abc',
            intoAccount: 'acc_9',
          );

      expect(result, const AccountMergeResult.alreadyMerged());
    });

    test('merge 409 same account', () async {
      final result =
          await clientAnswering({
            'error': 'same account',
          }, 409).mergeAccount(
            identityToken: 'session_abc',
            intoAccount: 'acc_9',
          );

      expect(result, const AccountMergeResult.sameAccount());
    });

    test('switch 200', () async {
      final result =
          await clientAnswering({
            'account_id': 'acc_9',
          }, 200).switchAccount(
            identityToken: 'session_abc',
            intoAccount: 'acc_9',
          );

      expect(result, const AccountSwitchResult.switched(accountId: 'acc_9'));
    });

    test('any 401 on merge and switch', () async {
      final merge = await clientAnswering(
        {'error': 'unauthorized'},
        401,
      ).mergeAccount(identityToken: 'dead', intoAccount: 'acc_9');
      final switched = await clientAnswering(
        {'error': 'unauthorized'},
        401,
      ).switchAccount(identityToken: 'dead', intoAccount: 'acc_9');

      expect(merge, const AccountMergeResult.unauthorized());
      expect(switched, const AccountSwitchResult.unauthorized());
    });
  });

  test('a 409 choose carries every number through to the caller', () async {
    final result =
        await clientAnswering({
              'error': 'choose',
              'into_account': 'acc_9',
              'topics': 3,
              'incidents': 12,
            }, 409).linkAccount(identityToken: 'session_abc')
            as AccountLinkChoose;

    expect(result.intoAccount, 'acc_9');
    expect(result.topics, 3);
    expect(result.incidents, 12);
  });

  group('the mock server answers the same rows', () {
    late MockServer server;
    late HttpApiClient client;
    late String deviceAccount;

    /// Registers a handset and points the session at its device token, the
    /// way a real launch does.
    Future<void> registerDevice() async {
      final response = server.registerDevice(
        const DeviceRegistration(
          deviceId: 'dev_1',
          platform: 'ios',
          pushToken: 'push',
          appVersion: '0.1.0',
        ),
      );
      deviceAccount = response.accountId;
      sessionStore.session = ApiSession(
        baseUri: Uri.parse('https://server.example'),
        relayUri: Uri.parse('https://relay.example'),
        mode: ServerMode.hosted,
        managementCredential: response.deviceToken!,
      );
    }

    setUp(() async {
      server = MockServer(
        serverInfo: const ServerInfo(
          version: '0.1.0',
          baseUrl: 'https://server.example',
          relayUrl: 'https://relay.example',
          mode: ServerModes.hosted,
        ),
      );
      client = HttpApiClient(server.httpClient, sessionStore);
      await registerDevice();
    });

    test('a new identity claims the account the handset brought', () async {
      final result = await client.linkAccount(identityToken: 'session_abc');

      expect(result, isA<AccountLinkClaimed>());
    });

    test('an empty account attaches with no prompt', () async {
      server.identityAccounts['session_abc'] = 'acc_9';

      final result = await client.linkAccount(identityToken: 'session_abc');

      expect(result, const AccountLinkResult.attached(accountId: 'acc_9'));
    });

    test('an account with topics raises the prompt with real counts', () async {
      server
        ..identityAccounts['session_abc'] = 'acc_9'
        ..createTopic(name: 'prod')
        ..createTopic(name: 'staging');

      final result = await client.linkAccount(identityToken: 'session_abc');

      expect(result, isA<AccountLinkChoose>());
      expect((result as AccountLinkChoose).topics, 2);
      expect(result.intoAccount, 'acc_9');
    });

    test('a handset somebody else signed in on refuses', () async {
      await client.linkAccount(identityToken: 'session_abc');

      final result = await client.linkAccount(identityToken: 'session_other');

      expect(result, const AccountLinkResult.accountHasAnotherIdentity());
    });

    test('an unknown device token is a 401', () async {
      sessionStore.session = ApiSession(
        baseUri: Uri.parse('https://server.example'),
        relayUri: Uri.parse('https://relay.example'),
        mode: ServerMode.hosted,
        managementCredential: 'dv_nobody',
      );

      final result = await client.linkAccount(identityToken: 'session_abc');

      expect(result, const AccountLinkResult.unauthorized());
    });

    test('merge folds one account into the other', () async {
      server.identityAccounts['session_abc'] = 'acc_9';
      server.createTopic(name: 'prod');

      final result = await client.mergeAccount(
        identityToken: 'session_abc',
        intoAccount: 'acc_9',
      );

      expect(result, isA<AccountMerged>());
      expect((result as AccountMerged).accountId, 'acc_9');
    });

    test('a ringing alarm refuses the merge and names it', () async {
      server.identityAccounts['session_abc'] = 'acc_9';
      server.createTopic(name: 'prod', critical: true);
      final incidentId = server.triggerTest(topic: 'prod');

      final result = await client.mergeAccount(
        identityToken: 'session_abc',
        intoAccount: 'acc_9',
      );

      expect(result, AccountMergeResult.liveIncident(incidentId: incidentId));
    });

    test('an account already merged away answers already merged', () async {
      server.identityAccounts['session_abc'] = 'acc_9';
      server.createTopic(name: 'prod');
      // Another device on the same account got there first.
      server.tombstonedAccounts.add(deviceAccount);

      final result = await client.mergeAccount(
        identityToken: 'session_abc',
        intoAccount: 'acc_9',
      );

      expect(result, const AccountMergeResult.alreadyMerged());
    });

    test('one account on both sides answers same account', () async {
      final account =
          (await client.linkAccount(identityToken: 'session_abc')
                  as AccountLinkClaimed)
              .accountId;

      final result = await client.mergeAccount(
        identityToken: 'session_abc',
        intoAccount: account,
      );

      expect(result, const AccountMergeResult.sameAccount());
    });

    test('switch joins the identity account', () async {
      server.identityAccounts['session_abc'] = 'acc_9';
      server.createTopic(name: 'prod');

      final result = await client.switchAccount(
        identityToken: 'session_abc',
        intoAccount: 'acc_9',
      );

      expect(result, const AccountSwitchResult.switched(accountId: 'acc_9'));
    });

    test('a self-hosted server refuses every account route', () async {
      server.serverInfo = const ServerInfo(
        version: '0.1.0',
        baseUrl: 'https://server.example',
        relayUrl: 'https://relay.example',
      );

      await expectLater(
        client.linkAccount(identityToken: 'session_abc'),
        throwsA(
          isA<Object>().having(
            (error) => error.toString(),
            'message',
            contains('501'),
          ),
        ),
      );
    });

    test('deleting the device leaves it unable to call again', () async {
      final token = sessionStore.session!.managementCredential;

      await client.deleteDevice(deviceId: 'dev_1', deviceToken: token);

      final result = await client.linkAccount(identityToken: 'session_abc');
      expect(result, const AccountLinkResult.unauthorized());
    });
  });
}
