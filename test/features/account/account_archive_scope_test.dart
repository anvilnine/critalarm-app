import 'dart:io';

import 'package:critalarm/app/held_account_scope.dart';
import 'package:critalarm/core/account/account_identity_changes.dart';
import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/storage/shared_prefs_api_session_store.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/features/account/data/repositories/api_account_repository.dart';
import 'package:critalarm/features/account/data/repositories/http_identity_repository.dart';
import 'package:critalarm/features/account/data/services/identity_token_store.dart';
import 'package:critalarm/features/account/data/services/provider_sign_in.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:critalarm/features/account/presentation/cubits/account_cubit.dart';
import 'package:critalarm/features/account/presentation/cubits/account_state.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' show Sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _server = 'https://server.example';

final class _Sheets implements ProviderSignIn {
  @override
  bool supports(IdentityProvider provider) => true;

  @override
  Future<ProviderCredential> signIn(IdentityProvider provider) async =>
      const ProviderCredential(idToken: 'google_id_token');

  @override
  Future<void> signOut() async {}
}

final class _PushToken implements PushTokenProvider {
  @override
  PushTokenKind get kind => PushTokenKind.apns;

  @override
  Future<String> getToken() async => 'push_token';

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();
}

/// The account routes answer what the test scripted, one answer per call.
final class _ScriptedApi extends MockApiClient {
  _ScriptedApi(super.server);

  final links = <AccountLinkResult>[];
  final merges = <AccountMergeResult>[];
  final switches = <AccountSwitchResult>[];

  @override
  Future<AccountLinkResult> linkAccount({
    required String identityToken,
    AccountLinkIntent intent = AccountLinkIntent.signIn,
  }) async => links.removeAt(0);

  @override
  Future<AccountMergeResult> mergeAccount({
    required String identityToken,
    required String intoAccount,
  }) async => merges.removeAt(0);

  @override
  Future<AccountSwitchResult> switchAccount({
    required String identityToken,
    required String intoAccount,
  }) async => switches.removeAt(0);
}

/// The real account cubit, identity repository and account repository over
/// one set of preferences, with the archive scoped the way `di.dart` scopes
/// it. The device registration keeps the anonymous account it had, which is
/// what a link, a switch or a merge leaves it with until the next launch.
final class _Phone {
  late final SharedPreferences prefs;
  late final DeviceIdentityStore devices;
  late final HeldAccountScope scope;
  late final LocalStore store;
  late final _ScriptedApi api;
  late final HttpIdentityRepository identities;
  late final AccountCubit cubit;

  Future<void> start({String? databasePath, bool open = true}) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      SharedPrefsConnectionRepository.serverUrlKey,
      _server,
    );
    await prefs.setString(
      SharedPrefsConnectionRepository.adminTokenKey,
      'dv_1',
    );
    devices = DeviceIdentityStore(prefs);
    await devices.readOrCreate();
    await devices.saveRegistration(
      deviceToken: 'dv_1',
      accountId: 'acc_anon',
      tier: 'free',
    );
    scope = HeldAccountScope(
      prefs: prefs,
      devices: devices,
      serverUrl: () async => _server,
    );
    final changes = AccountIdentityChanges();
    if (open) {
      store = await LocalStore.open(
        factory: databaseFactoryFfi,
        path: databasePath ?? inMemoryDatabasePath,
        scope: scope.call,
        identityChanges: changes,
      );
      addTearDown(store.close);
    }
    api = _ScriptedApi(
      MockServer(
        serverInfo: const ServerInfo(
          version: '0.1.0',
          baseUrl: _server,
          relayUrl: 'https://relay.example',
          mode: ServerModes.hosted,
        ),
      ),
    );
    final sessions = SharedPrefsApiSessionStore(prefs);
    await sessions.write(
      ApiSession(
        baseUri: Uri.parse(_server),
        relayUri: Uri.parse('https://relay.example'),
        mode: ServerMode.hosted,
        managementCredential: 'dv_1',
      ),
    );
    identities = HttpIdentityRepository(
      httpClient: MockClient(
        (_) async => http.Response(
          '{"token":"session_1","user":{"email":"someone@example.test"}}',
          200,
        ),
      ),
      sessions: sessions,
      prefs: prefs,
      providers: _Sheets(),
      tokens: PrefsIdentityTokenStore(prefs),
      identityChanges: changes,
    );
    if (!open) return;
    final account = ApiAccountRepository(
      api: api,
      sessions: sessions,
      devices: devices,
      register: RegisterDeviceUsecase(api, devices, _PushToken()),
      identities: identities,
      connections: SharedPrefsConnectionRepository(prefs),
      forgetMergedAccount: (from, into) async {
        final fromScope = await scope.forAccount(from);
        final intoScope = await scope.forAccount(into);
        if (fromScope != null && intoScope != null) {
          await store.mergeArchive(from: fromScope, into: intoScope);
        }
      },
    );
    cubit = AccountCubit(identities: identities, account: account);
    addTearDown(cubit.close);
  }

  /// Puts an alarm straight into the archive under [account], whoever the
  /// phone is on.
  Future<void> seed(
    String account,
    String id, {
    String state = 'closed',
  }) async {
    await store.db.insert('incidents', {
      'scope': await scope.forAccount(account),
      'id': id,
      'topic': 'prod',
      'state': state,
      'opened_at': 1000,
      'updated_at': 1000,
      'last_message_at': 1000,
      'priority': 3,
      'synced_at': 1000,
    });
  }

  /// What the screens would read now.
  Future<List<String>> visible() async => [
    for (final incident in await store.incidents.page()) incident.id,
  ]..sort();

  Future<int> rowsOf(String account) async => Sqflite.firstIntValue(
    await store.db.rawQuery(
      'SELECT COUNT(*) FROM incidents WHERE scope = ?',
      [await scope.forAccount(account)],
    ),
  )!;

  /// What leaving an account does to the phone: the sign-in is dropped and the
  /// device registers again as a new anonymous account.
  Future<void> signOut() async {
    await identities.clearSession();
    await devices.resetIdentity();
    await devices.saveRegistration(
      deviceToken: 'dv_2',
      accountId: 'acc_anon_2',
      tier: 'free',
    );
  }
}

Incident _alarm(String id) => Incident(
  id: id,
  topic: 'prod',
  openedAt: DateTime.utc(2026, 9, 20, 12),
  lastMessageAt: DateTime.utc(2026, 9, 20, 12),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('the archive follows the account the person signed in to', () {
    test('a link that attaches the phone to an account shows that account '
        'and stores under it, before the device registers again', () async {
      final phone = _Phone();
      await phone.start();
      await phone.seed('acc_x', 'x_old');
      await phone.seed('acc_anon', 'anon_old');
      expect(await phone.visible(), ['anon_old']);
      phone.api.links.add(const AccountLinkResult.attached(accountId: 'acc_x'));

      await phone.cubit.signIn(IdentityProvider.google);

      expect(phone.cubit.state.status, AccountStatus.signedIn);
      // The device still says it is the anonymous account.
      expect((await phone.devices.readOrCreate()).accountId, 'acc_anon');
      expect(await phone.visible(), ['x_old']);
      await phone.store.incidents.upsertAll([_alarm('x_new')]);
      expect(await phone.rowsOf('acc_x'), 2);
      expect(await phone.rowsOf('acc_anon'), 1);
    });

    test('signing out of an account and back in to it brings its history '
        'back and hides it in between', () async {
      final phone = _Phone();
      await phone.start();
      await phone.seed('acc_x', 'x_old');
      phone.api.links.addAll(const [
        AccountLinkResult.claimed(accountId: 'acc_x'),
        AccountLinkResult.claimed(accountId: 'acc_x'),
      ]);

      await phone.cubit.signIn(IdentityProvider.google);
      expect(await phone.visible(), ['x_old']);

      await phone.signOut();
      expect(await phone.visible(), isEmpty);
      await phone.store.incidents.upsertAll([_alarm('anon_new')]);
      expect(await phone.rowsOf('acc_anon_2'), 1);

      await phone.cubit.signIn(IdentityProvider.google);

      expect(await phone.visible(), ['x_old']);
      await phone.store.incidents.upsertAll([_alarm('x_new')]);
      expect(await phone.rowsOf('acc_x'), 2);
      expect(await phone.rowsOf('acc_anon_2'), 1);
    });

    test('start fresh shows the account the phone joined and none of the '
        'one it left', () async {
      final phone = _Phone();
      await phone.start();
      await phone.seed('acc_anon', 'anon_old');
      await phone.seed('acc_x', 'x_old');
      phone.api
        ..links.add(
          const AccountLinkResult.choose(
            intoAccount: 'acc_x',
            topics: 1,
            incidents: 1,
          ),
        )
        ..switches.add(const AccountSwitchResult.switched(accountId: 'acc_x'));

      await phone.cubit.signIn(IdentityProvider.google);
      expect(phone.cubit.state.status, AccountStatus.choosing);
      await phone.cubit.startFresh();

      expect(await phone.visible(), ['x_old']);
    });

    test(
      'keep both moves the history of the phone account to the one it '
      'was folded into, and the copy already there wins a clash',
      () async {
        final phone = _Phone();
        await phone.start();
        await phone.seed('acc_anon', 'anon_old');
        await phone.seed('acc_anon', 'both', state: 'open');
        await phone.seed('acc_x', 'x_old');
        await phone.seed('acc_x', 'both');
        phone.api
          ..links.add(
            const AccountLinkResult.choose(
              intoAccount: 'acc_x',
              topics: 1,
              incidents: 2,
            ),
          )
          ..merges.add(
            const AccountMergeResult.merged(
              accountId: 'acc_x',
              mergedFrom: 'acc_anon',
            ),
          );

        await phone.cubit.signIn(IdentityProvider.google);
        await phone.cubit.keepBoth();

        expect(phone.cubit.state.status, AccountStatus.signedIn);
        expect(await phone.visible(), ['anon_old', 'both', 'x_old']);
        expect(await phone.rowsOf('acc_anon'), 0);
        final both = (await phone.store.incidents.page()).firstWhere(
          (i) => i.id == 'both',
        );
        expect(both.state, 'closed');
      },
    );

    test(
      'a file from before scopes keeps its history for the account the '
      'person signed in to, though the device has not registered it yet',
      () async {
        final dir = await Directory.systemTemp.createTemp('critalarm_scope');
        addTearDown(() => dir.delete(recursive: true));
        final path = p.join(dir.path, 'critalarm.db');
        final v3 = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 3,
            onCreate: (db, version) async {
              await db.execute('''
              CREATE TABLE incidents (
                id TEXT PRIMARY KEY, topic TEXT NOT NULL, state TEXT NOT NULL,
                opened_at INTEGER NOT NULL, acked_at INTEGER, closed_at INTEGER,
                updated_at INTEGER, last_message_at INTEGER NOT NULL,
                max_ring_s INTEGER, priority INTEGER NOT NULL,
                synced_at INTEGER NOT NULL
              )
            ''');
              await db.execute('''
              CREATE TABLE messages (
                id TEXT PRIMARY KEY, topic TEXT NOT NULL, incident_id TEXT,
                title TEXT, body TEXT, priority INTEGER NOT NULL, tags TEXT,
                click TEXT, markdown INTEGER NOT NULL DEFAULT 0,
                created_at INTEGER NOT NULL, synced_at INTEGER NOT NULL
              )
            ''');
              await db.execute('''
              CREATE TABLE topics (
                scope TEXT NOT NULL, position INTEGER NOT NULL,
                name TEXT NOT NULL, critical INTEGER NOT NULL DEFAULT 0,
                repeat_interval_s INTEGER NOT NULL, max_ring_s INTEGER NOT NULL,
                desk_timer_s INTEGER NOT NULL, relay_content TEXT NOT NULL,
                created_at_ms INTEGER, synced_at INTEGER NOT NULL,
                PRIMARY KEY (scope, name)
              )
            ''');
            },
          ),
        );
        await v3.insert('incidents', {
          'id': 'old_1',
          'topic': 'prod',
          'state': 'closed',
          'opened_at': 1000,
          'updated_at': 1000,
          'last_message_at': 1000,
          'priority': 3,
          'synced_at': 1000,
        });
        await v3.close();

        final phone = _Phone();
        await phone.start(open: false);
        // Signed in to acc_x; the device registration still names acc_anon.
        await phone.prefs.setString(
          HttpIdentityRepository.accountIdKey,
          'acc_x',
        );
        phone.store = await LocalStore.open(
          factory: databaseFactoryFfi,
          path: path,
          scope: phone.scope.call,
          identityChanges: AccountIdentityChanges(),
        );
        addTearDown(phone.store.close);

        expect(await phone.visible(), ['old_1']);

        // After the next registration the device names the same account, and
        // the history is still there.
        await phone.devices.saveRegistration(
          deviceToken: 'dv_1',
          accountId: 'acc_x',
          tier: 'free',
        );
        expect(await phone.visible(), ['old_1']);

        // Signed out, the same rows are not shown to the anonymous account.
        await phone.prefs.remove(HttpIdentityRepository.accountIdKey);
        await phone.devices.saveRegistration(
          deviceToken: 'dv_2',
          accountId: 'acc_anon_2',
          tier: 'free',
        );
        expect(await phone.visible(), isEmpty);
      },
    );
  });
}
