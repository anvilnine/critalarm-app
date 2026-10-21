import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/storage/shared_prefs_api_session_store.dart';
import 'package:critalarm/features/account/data/repositories/http_identity_repository.dart';
import 'package:critalarm/features/account/data/services/identity_token_store.dart';
import 'package:critalarm/features/account/data/services/provider_sign_in.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _NoSheets implements ProviderSignIn {
  int signOuts = 0;

  @override
  bool supports(IdentityProvider provider) => true;

  @override
  Future<ProviderCredential> signIn(IdentityProvider provider) =>
      throw StateError('no sheet in this test');

  @override
  Future<void> signOut() async => signOuts++;
}

/// What a backup of a signed-in phone carries: who signed in, never the
/// token.
const _restoredSignIn = <String, Object>{
  'identity_provider': 'google',
  'identity_email': 'someone@example.test',
  'identity_account_id': 'acct_1',
  'identity_providers': 'google,apple',
  'theme_mode': 'dark',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _NoSheets sheets;
  late int bumps;

  Future<({HttpIdentityRepository repo, SharedPreferences prefs})> make(
    Map<String, Object> values,
  ) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    sheets = _NoSheets();
    bumps = 0;
    final changes = AccountIdentityChanges()..addListener(() => bumps++);
    return (
      prefs: prefs,
      repo: HttpIdentityRepository(
        httpClient: MockClient((_) async => http.Response('', 500)),
        sessions: SharedPrefsApiSessionStore(prefs),
        prefs: prefs,
        providers: sheets,
        tokens: PrefsIdentityTokenStore(prefs),
        identityChanges: changes,
      ),
    );
  }

  test('a sign-in with no token reads as signed out', () async {
    final made = await make(_restoredSignIn);
    expect(await made.repo.readIdentity(), isNotNull);
    expect(await made.repo.readSession(), isNull);

    await made.repo.forgetRestoredSignIn();

    expect(await made.repo.readIdentity(), isNull);
    expect(made.prefs.getString('identity_provider'), isNull);
    expect(made.prefs.getString('identity_email'), isNull);
    expect(made.prefs.getString('identity_account_id'), isNull);
    expect(made.prefs.getString('identity_providers'), isNull);
    expect(made.prefs.getString('theme_mode'), 'dark');
    expect(bumps, 1);
    // Nothing is sent anywhere: the provider is left alone at launch.
    expect(sheets.signOuts, 0);
  });

  test('a phone that holds its token stays signed in', () async {
    final made = await make({
      ..._restoredSignIn,
      identitySessionTokenKey: 'sess_here',
    });

    await made.repo.forgetRestoredSignIn();

    final identity = await made.repo.readIdentity();
    expect(identity?.accountId, 'acct_1');
    expect((await made.repo.readSession())?.token, 'sess_here');
    expect(bumps, 0);
  });

  test('nobody signed in: nothing changes', () async {
    final made = await make({'theme_mode': 'dark'});

    await made.repo.forgetRestoredSignIn();

    expect(made.prefs.getKeys(), {'theme_mode'});
    expect(bumps, 0);
  });

  test('a provider alone, with no account id yet, goes too', () async {
    final made = await make({'identity_provider': 'apple'});

    await made.repo.forgetRestoredSignIn();

    expect(made.prefs.getString('identity_provider'), isNull);
    expect(bumps, 1);
  });
}
