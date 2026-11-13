import 'package:critalarm/app/launch_sign_in.dart';
import 'package:critalarm/app/moved_phone_reset.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/backup/backup_host.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/storage/shared_prefs_api_session_store.dart';
import 'package:critalarm/features/account/data/repositories/http_identity_repository.dart';
import 'package:critalarm/features/account/data/services/identity_token_store.dart';
import 'package:critalarm/features/account/data/services/provider_sign_in.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:critalarm/features/account/domain/usecases/sign_in_restore.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_connection_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/account/account_fakes.dart';

final class _Host implements BackupHost {
  _Host(this.verdict);

  InstallMarkerVerdict verdict;

  @override
  Future<InstallMarkerVerdict> installMarker() async => verdict;

  @override
  Future<void> settleInstallMarker() async =>
      verdict = InstallMarkerVerdict.same;

  @override
  Future<void> excludeFromBackup(String path) async {}
}

final class _NoSheets implements ProviderSignIn {
  @override
  bool supports(IdentityProvider provider) => true;

  @override
  Future<ProviderCredential> signIn(IdentityProvider provider) =>
      throw StateError('no sheet in this test');

  @override
  Future<void> signOut() async {}
}

/// Rule 2 at launch: the moved-phone reset runs first, and the restore never
/// runs on a phone it calls moved.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<
    ({
      MovedPhoneReset reset,
      SignInRestore restore,
      HttpIdentityRepository identities,
      FakeAccountRepository account,
    })
  >
  make(InstallMarkerVerdict verdict, Map<String, Object> prefsValues) async {
    SharedPreferences.setMockInitialValues({
      'api_session':
          'https://api.critalarm.app|https://relay.critalarm.app|hosted|dv_x',
      'server_url': 'https://api.critalarm.app',
      'admin_token': 'dv_x',
      ...prefsValues,
    });
    final prefs = await SharedPreferences.getInstance();
    final identities = HttpIdentityRepository(
      httpClient: MockClient((_) async => http.Response('', 500)),
      sessions: SharedPrefsApiSessionStore(prefs),
      prefs: prefs,
      providers: _NoSheets(),
      tokens: PrefsIdentityTokenStore(prefs),
      identityChanges: AccountIdentityChanges(),
    );
    final account = FakeAccountRepository(
      linkAnswers: const [AccountLinkResult.alreadyLinked(accountId: 'acc_1')],
    );
    return (
      identities: identities,
      account: account,
      restore: SignInRestore(
        identities: identities,
        account: account,
        accountIdentities: FakeAccountIdentities([
          identityRow(email: 'zed@gmail.com', current: true),
        ]),
        held: identities,
      ),
      reset: MovedPhoneReset(
        host: _Host(verdict),
        forgetAccountData: () async {},
        forgetRestoredSignIn: identities.forgetRestoredSignIn,
        sessions: SharedPrefsApiSessionStore(prefs),
        connections: SharedPrefsConnectionRepository(prefs),
        devices: DeviceIdentityStore(prefs),
        forgetSentPushToken: () async {},
        reconnect: (_) async {},
      ),
    );
  }

  test('rule 2: a phone the install marker calls moved still drops its '
      'sign-in, and the restore does not run', () async {
    // What a backup carries: who signed in, never the token.
    final made = await make(InstallMarkerVerdict.moved, {
      'identity_provider': 'google',
      'identity_email': 'zed@gmail.com',
      'identity_account_id': 'acc_1',
    });

    final moved = await resetThenRestoreSignIn(
      reset: made.reset,
      restore: made.restore,
    );
    await pumpEventQueue();

    expect(moved, isTrue);
    expect(await made.identities.readIdentity(), isNull);
    expect(made.restore.linkSkipped, isTrue);
    expect(made.account.calls, isEmpty);

    // A screen that loads later in the same run sends no session either.
    await made.restore.run();
    expect(made.account.calls, isEmpty);
  });

  test('rule 2: the same phone after a reinstall restores at launch', () async {
    // The token survived; the preferences that name who it belongs to did
    // not.
    final made = await make(InstallMarkerVerdict.same, {
      identitySessionTokenKey: 'sess_kept',
    });

    final moved = await resetThenRestoreSignIn(
      reset: made.reset,
      restore: made.restore,
    );
    await pumpEventQueue();

    expect(moved, isFalse);
    expect(made.account.linkTokens, ['sess_kept']);
    expect(made.account.linkIntents, [AccountLinkIntent.signIn]);
    final identity = await made.identities.readIdentity();
    expect(identity?.email, 'zed@gmail.com');
    expect(identity?.accountId, 'acc_1');
    expect((await made.identities.readSession())?.token, 'sess_kept');
  });
}
