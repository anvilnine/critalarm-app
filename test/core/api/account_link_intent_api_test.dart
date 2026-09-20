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

/// A21 against api.md 1.14.0 §3.7: `intent` on `POST /v1/account/link`, and
/// `POST /v1/account/join-token`.
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

  group('the wire format', () {
    test('sign-in sends intent sign_in', () async {
      late http.Request captured;
      final client = clientAnswering(
        {'account_id': 'acc_1', 'outcome': 'claimed'},
        200,
        onRequest: (request) => captured = request,
      );

      await client.linkAccount(identityToken: 'session_abc');

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['intent'], 'sign_in');
    });

    test('adding a provider sends intent link', () async {
      late http.Request captured;
      final client = clientAnswering(
        {'account_id': 'acc_1', 'outcome': 'linked'},
        200,
        onRequest: (request) => captured = request,
      );

      await client.linkAccount(
        identityToken: 'session_abc',
        intent: AccountLinkIntent.link,
      );

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['intent'], 'link');
      expect(body['identity_token'], 'session_abc');
      expect(captured.headers['authorization'], 'Bearer dv_device');
    });

    test('outcome linked reads back as linked', () async {
      final result = await clientAnswering({
        'account_id': 'acc_1',
        'outcome': 'linked',
      }, 200).linkAccount(identityToken: 'session_abc');

      expect(result, const AccountLinkResult.linked(accountId: 'acc_1'));
    });

    test('outcome already_linked reads back as already linked', () async {
      final result = await clientAnswering({
        'account_id': 'acc_1',
        'outcome': 'already_linked',
      }, 200).linkAccount(identityToken: 'session_abc');

      expect(result, const AccountLinkResult.alreadyLinked(accountId: 'acc_1'));
    });

    test('the two 409 wordings are told apart', () async {
      final taken = await clientAnswering({
        'error': 'identity has another account',
      }, 409).linkAccount(identityToken: 'session_abc');
      final shared = await clientAnswering({
        'error': 'account has another identity',
      }, 409).linkAccount(identityToken: 'session_abc');

      expect(taken, const AccountLinkResult.identityHasAnotherAccount());
      expect(shared, const AccountLinkResult.accountHasAnotherIdentity());
    });

    test('a join code posts to the right path with dv_', () async {
      late http.Request captured;
      final client = clientAnswering(
        {'join_token': 'aj_abc'},
        200,
        onRequest: (request) => captured = request,
      );

      final result = await client.mintAccountJoinToken();

      expect(captured.method, 'POST');
      expect(
        captured.url.toString(),
        'https://server.example/v1/account/join-token',
      );
      expect(captured.headers['authorization'], 'Bearer dv_device');
      expect(result, const AccountJoinTokenResult.minted(joinToken: 'aj_abc'));
    });

    test('a 401 on a join code is read, not thrown', () async {
      final result = await clientAnswering(
        {'error': 'unauthorized'},
        401,
      ).mintAccountJoinToken();

      expect(result, const AccountJoinTokenResult.unauthorized());
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

    test('a second provider links onto the same account', () async {
      final signedIn =
          await client.linkAccount(identityToken: 'session_google')
              as AccountLinkClaimed;

      final added = await client.linkAccount(
        identityToken: 'session_apple',
        intent: AccountLinkIntent.link,
      );

      expect(added, AccountLinkResult.linked(accountId: signedIn.accountId));
    });

    test('linking the same identity twice is already linked', () async {
      final signedIn =
          await client.linkAccount(identityToken: 'session_google')
              as AccountLinkClaimed;

      final again = await client.linkAccount(
        identityToken: 'session_google',
        intent: AccountLinkIntent.link,
      );

      expect(
        again,
        AccountLinkResult.alreadyLinked(accountId: signedIn.accountId),
      );
    });

    test('an identity owned elsewhere refuses the link', () async {
      await client.linkAccount(identityToken: 'session_google');
      server.identityAccounts['session_apple'] = 'acc_9';

      final result = await client.linkAccount(
        identityToken: 'session_apple',
        intent: AccountLinkIntent.link,
      );

      expect(result, const AccountLinkResult.identityHasAnotherAccount());
    });

    test('signing in again with the same identity is already linked', () async {
      final first =
          await client.linkAccount(identityToken: 'session_google')
              as AccountLinkClaimed;

      // No intent at all, which is the sign-in screen's call. Before 1.14.0
      // this answered `claimed` a second time.
      final again = await client.linkAccount(identityToken: 'session_google');

      expect(
        again,
        AccountLinkResult.alreadyLinked(accountId: first.accountId),
      );
    });

    test('signing in on a handset somebody else claimed still 409s', () async {
      await client.linkAccount(identityToken: 'session_google');

      final result = await client.linkAccount(identityToken: 'session_other');

      expect(result, const AccountLinkResult.accountHasAnotherIdentity());
    });

    test('an account with two identities deletes on either one', () async {
      await client.linkAccount(identityToken: 'session_google');
      await client.linkAccount(
        identityToken: 'session_apple',
        intent: AccountLinkIntent.link,
      );

      final result = await client.deleteAccount(
        identityToken: 'session_apple',
      );

      expect(result, const AccountDeleteResult.deleted());
    });

    test('minting hands back a fresh aj_ every time', () async {
      final first = await client.mintAccountJoinToken();
      final second = await client.mintAccountJoinToken();

      expect(first, isA<AccountJoinTokenMinted>());
      expect(second, isA<AccountJoinTokenMinted>());
      expect(
        (second as AccountJoinTokenMinted).joinToken,
        isNot((first as AccountJoinTokenMinted).joinToken),
      );
      expect(second.joinToken, startsWith('aj_'));
    });

    test('a new code retires the one before it', () async {
      final first =
          await client.mintAccountJoinToken() as AccountJoinTokenMinted;

      await client.mintAccountJoinToken();

      expect(server.accountJoinTokens.containsKey(first.joinToken), isFalse);
    });

    test('a device token nobody holds is a 401', () async {
      sessionStore.session = ApiSession(
        baseUri: Uri.parse('https://server.example'),
        relayUri: Uri.parse('https://relay.example'),
        mode: ServerMode.hosted,
        managementCredential: 'dv_nobody',
      );

      final result = await client.mintAccountJoinToken();

      expect(result, const AccountJoinTokenResult.unauthorized());
    });
  });
}
