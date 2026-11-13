import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/storage/shared_prefs_api_session_store.dart';
import 'package:critalarm/features/account/data/repositories/http_identity_repository.dart';
import 'package:critalarm/features/account/data/services/identity_token_store.dart';
import 'package:critalarm/features/account/data/services/provider_sign_in.dart';
import 'package:critalarm/features/account/domain/entities/account_identity.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _NoSheets implements ProviderSignIn {
  @override
  bool supports(IdentityProvider provider) => true;

  @override
  Future<ProviderCredential> signIn(IdentityProvider provider) =>
      throw StateError('no sheet in this test');

  @override
  Future<void> signOut() async {}
}

const _channel = MethodChannel('app.critalarm/device_identity');

/// Rule 2: the session token read and written without the preferences that
/// name who it belongs to.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? keychain;
  var keychainFails = false;

  setUp(() {
    keychain = null;
    keychainFails = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          if (keychainFails) throw PlatformException(code: 'keychain');
          final args = (call.arguments as Map).cast<String, Object?>();
          switch (call.method) {
            case 'read':
              return keychain;
            case 'write':
              keychain = args['value'] as String?;
            case 'delete':
              keychain = null;
          }
          return null;
        });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null),
  );

  Future<({HttpIdentityRepository repo, SharedPreferences prefs})> make(
    Map<String, Object> values, {
    bool iPhone = true,
  }) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    return (
      prefs: prefs,
      repo: HttpIdentityRepository(
        httpClient: MockClient((_) async => http.Response('', 500)),
        sessions: SharedPrefsApiSessionStore(prefs),
        prefs: prefs,
        providers: _NoSheets(),
        tokens: iPhone
            ? KeychainIdentityTokenStore(prefs)
            : PrefsIdentityTokenStore(prefs),
        identityChanges: AccountIdentityChanges(),
      ),
    );
  }

  test('rule 2: a reinstalled iPhone holds its token with nothing in the '
      'preferences, and it reads', () async {
    keychain = 'sess_keychain';
    final made = await make({});

    // Who it belongs to is gone, so the ordinary read says signed out.
    expect(await made.repo.readSession(), isNull);
    expect(await made.repo.readOwnToken(), 'sess_keychain');
  });

  test('rule 2: a token a backup left in the preferences is dropped, never '
      'moved in', () async {
    final made = await make({identitySessionTokenKey: 'sess_from_backup'});

    expect(await made.repo.readOwnToken(), isNull);
    expect(made.prefs.getString(identitySessionTokenKey), isNull);
    expect(keychain, isNull);
  });

  test('rule 2: a Keychain that will not answer reads as no token', () async {
    keychainFails = true;
    final made = await make({});

    expect(await made.repo.readOwnToken(), isNull);
  });

  test(
    'rule 2: off iOS the token in the preferences is the phone own',
    () async {
      final made = await make({
        identitySessionTokenKey: 'sess_here',
      }, iPhone: false);

      expect(await made.repo.readOwnToken(), 'sess_here');
    },
  );

  test(
    'rule 4: keep puts a session back after a sign-out dropped it',
    () async {
      final made = await make({});
      await made.repo.clearSession();

      await made.repo.keep(
        const IdentitySession(
          token: 'sess_new',
          provider: IdentityProvider.google,
          email: 'new@example.test',
        ),
      );
      await made.repo.saveIdentity(
        const AccountIdentity(
          provider: IdentityProvider.google,
          accountId: 'acc_fresh',
          email: 'new@example.test',
        ),
      );

      final session = await made.repo.readSession();
      expect(session?.token, 'sess_new');
      expect(session?.provider, IdentityProvider.google);
      expect(keychain, 'sess_new');
      expect((await made.repo.readIdentity())?.accountId, 'acc_fresh');
    },
  );
}
