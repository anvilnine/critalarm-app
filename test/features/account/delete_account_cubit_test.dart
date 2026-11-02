import 'package:critalarm/app/account_data.dart';
import 'package:critalarm/app/held_account_scope.dart';
import 'package:critalarm/core/ack/ack_queue.dart';
import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/sound/own_sound_lock_flag.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/core/sync/message_sync_service.dart';
import 'package:critalarm/features/account/data/repositories/api_account_repository.dart';
import 'package:critalarm/features/account/data/repositories/http_identity_repository.dart';
import 'package:critalarm/features/account/domain/entities/account_identity.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:critalarm/features/account/presentation/cubits/account_cubit.dart';
import 'package:critalarm/features/account/presentation/cubits/account_state.dart';
import 'package:critalarm/features/challenges/data/shared_prefs_challenge_choices.dart';
import 'package:critalarm/features/incidents/data/shared_prefs_alarm_style_choices.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:critalarm/features/search/data/repositories/shared_prefs_recent_searches_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' show Sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../app/account_data_fixture.dart';
import 'account_fakes.dart';

/// The pref key [MessageSyncService] keeps a poll cursor under, spelled out
/// here because the service keeps its own prefix private.
const _cursorKey = 'msg_sync_last_id.prod';

final class _FakePushTokenProvider implements PushTokenProvider {
  @override
  PushTokenKind get kind => PushTokenKind.apns;

  @override
  Future<String> getToken() async => 'push_token';

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();
}

final class _MemoryApiSessionStore implements ApiSessionStore {
  ApiSession? session;

  @override
  Future<void> clear() async => session = null;

  @override
  Future<ApiSession?> read() async => session;

  @override
  Future<void> write(ApiSession session) async => this.session = session;
}

final class _MemoryConnectionRepository implements ConnectionRepository {
  ServerConnection? connection = const ServerConnection(
    serverUrl: 'https://server.example',
    adminToken: 'dv_old',
  );

  @override
  Future<AppResult<ServerConnection>> getConnection() async {
    final saved = connection;
    return saved == null
        ? const Failure.unexpected(
            message: 'no connection',
          ).toFailure<ServerConnection>()
        : saved.toSuccess();
  }

  @override
  Future<AppResult<Unit>> saveConnection(ServerConnection next) async {
    connection = next;
    return unit.toSuccess();
  }

  @override
  Future<AppResult<Unit>> clearConnection() async {
    connection = null;
    return unit.toSuccess();
  }
}

/// A client whose delete always breaks, which is what a 5xx or a dropped
/// connection looks like from here.
final class _FailingDeleteApiClient extends MockApiClient {
  _FailingDeleteApiClient(super.server);

  @override
  Future<AccountDeleteResult> deleteAccount({String? identityToken}) =>
      Future<AccountDeleteResult>.error(
        const ApiException(statusCode: 503, message: 'service unavailable'),
      );
}

/// The real [ApiAccountRepository] over a real [DeviceIdentityStore], so a
/// test can look at the credentials on disk rather than at a fake's counters.
final class _Harness {
  _Harness({required this.failDelete});

  final bool failDelete;

  late final SharedPreferences prefs;
  late final MockServer server;
  late final MockApiClient api;
  late final DeviceIdentityStore devices;
  late final _MemoryApiSessionStore sessions;
  late final _MemoryConnectionRepository connections;
  late final FakeIdentityRepository identities;
  late final ApiAccountRepository account;
  late final OwnLookOnDisk ownLook;

  /// The phone's alarm history, with one alarm of the account that is
  /// registered at the start.
  late final LocalStore archive;
  late final HeldAccountScope heldScope;

  /// Alarms held on the phone, for every account.
  Future<int> get archivedAlarms async => Sqflite.firstIntValue(
    await archive.db.rawQuery('SELECT COUNT(*) FROM incidents'),
  )!;

  int billingLogOuts = 0;
  int alarmStops = 0;

  String? get deviceId => prefs.getString('device_id');
  String? get deviceToken => prefs.getString('device_token');

  Future<void> start() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    server = MockServer(
      serverInfo: const ServerInfo(
        version: '0.1.0',
        baseUrl: 'https://server.example',
        relayUrl: 'https://relay.example',
        mode: ServerModes.hosted,
      ),
    );
    api = failDelete ? _FailingDeleteApiClient(server) : MockApiClient(server);
    devices = DeviceIdentityStore(prefs);
    sessions = _MemoryApiSessionStore();
    connections = _MemoryConnectionRepository();
    identities = FakeIdentityRepository();
    final register = RegisterDeviceUsecase(
      api,
      devices,
      _FakePushTokenProvider(),
      platform: () => 'ios',
    );
    // A launch that has already happened once: the handset is registered and
    // both saved records carry its credential.
    await register(appVersion: '0.1.0');
    final registered = await devices.readOrCreate();
    api.deviceToken = registered.deviceToken;
    sessions.session = ApiSession(
      baseUri: Uri.parse('https://server.example'),
      relayUri: Uri.parse('https://relay.example'),
      mode: ServerMode.hosted,
      managementCredential: registered.deviceToken!,
    );
    connections.connection = ServerConnection(
      serverUrl: 'https://server.example',
      adminToken: registered.deviceToken!,
    );
    // Local odds and ends that all name something on this account.
    await prefs.setString(_cursorKey, 'm_1');
    await prefs.setString(AckQueue.storageKey, '[]');
    await SharedPrefsRecentSearchesRepository(prefs).add('prod');
    // And what the paid features keep for this account, next to the
    // person's own sounds.
    await writeAll(prefs, accountDataFor(registered.accountId!));
    heldScope = HeldAccountScope(
      prefs: prefs,
      devices: devices,
      serverUrl: () async => 'https://server.example',
    );
    archive = await LocalStore.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
      scope: heldScope.call,
    );
    addTearDown(archive.close);
    await archive.incidents.upsertAll([
      Incident(
        id: 'inc_old',
        topic: 'prod',
        openedAt: DateTime.utc(2026, 9, 20, 12),
        lastMessageAt: DateTime.utc(2026, 9, 20, 12),
      ),
    ]);
    final accountData = AccountData(
      ownLook: (ownLook = await OwnLookOnDisk.seed(prefs)).store,
      acks: AckQueue(prefs, api),
      messageCursors: MessageSyncService(prefs, api),
      recentSearches: SharedPrefsRecentSearchesRepository(prefs),
      challenges: SharedPrefsChallengeChoices(prefs),
      alarmStyles: SharedPrefsAlarmStyleChoices(prefs),
      soundLock: OwnSoundLockFlag(prefs),
      archive: archive,
    );

    account = ApiAccountRepository(
      api: api,
      sessions: sessions,
      devices: devices,
      register: register,
      identities: identities,
      connections: connections,
      forgetAccountData: accountData.forget,
      forgetDeletedAccountData: (accountId) async {
        await accountData.forgetDeleted(
          scope: accountId == null
              ? null
              : await heldScope.forAccount(accountId),
        );
      },
      readAccountId: heldScope.accountId,
      signOutBilling: () async => billingLogOuts++,
      stopAlarm: () async => alarmStops++,
    );
  }

  AccountCubit get cubit =>
      AccountCubit(identities: identities, account: account);
}

void main() {
  sqfliteFfiInit();

  group('against the real repository', () {
    test('204 wipes what is here and registers fresh', () async {
      final harness = _Harness(failDelete: false);
      await harness.start();
      final oldId = harness.deviceId;
      final oldToken = harness.deviceToken;
      final cubit = harness.cubit;
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.deleteAccount();

      expect(cubit.state.status, AccountStatus.deleted);
      // A new device id and a credential that is not the dead one, because
      // every /v1/ route authenticates on the device token alone.
      expect(harness.deviceId, isNot(oldId));
      expect(harness.deviceToken, isNotNull);
      expect(harness.deviceToken, isNot(oldToken));
      // Both saved records carry the new one, or everything answers 401 until
      // a restart and a re-onboard.
      expect(
        harness.sessions.session?.managementCredential,
        harness.deviceToken,
      );
      expect(harness.connections.connection?.adminToken, harness.deviceToken);
      // The store goes back to an anonymous user before anything else.
      expect(harness.billingLogOuts, 1);
      // And the leftovers that named the old account are gone.
      expect(harness.prefs.getString(_cursorKey), isNull);
      expect(harness.prefs.getString(AckQueue.storageKey), isNull);
      expect(
        harness.prefs.getStringList('search_recent_queries'),
        anyOf(isNull, isEmpty),
      );
      // No challenge choice, no look choice and none of the three notes.
      expectAccountDataGone(harness.prefs);
      // And no own photo: the file, its record and its accent.
      await harness.ownLook.expectGone();
      // The recordings and what rings where are the person's, not a plan's.
      expectOwnSoundsKept(harness.prefs);
      // The account is gone, so its alarm history goes too.
      expect(await harness.archivedAlarms, 0);
    });

    // A sign-in that attaches or switches the account saves it with the
    // identity at once, while the device registration still names the
    // anonymous account it had.
    test('deleting a signed-in account takes the archive of that account, '
        'not the anonymous one the device still names', () async {
      final harness = _Harness(failDelete: false);
      await harness.start();
      await harness.prefs.setString(
        HttpIdentityRepository.accountIdKey,
        'acc_x',
      );
      await harness.archive.incidents.upsertAll([
        Incident(
          id: 'inc_x',
          topic: 'prod',
          openedAt: DateTime.utc(2026, 9, 20, 12),
          lastMessageAt: DateTime.utc(2026, 9, 20, 12),
        ),
      ]);
      expect(await harness.archivedAlarms, 2);
      final cubit = harness.cubit;
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.deleteAccount();

      expect(cubit.state.status, AccountStatus.deleted);
      expect(
        Sqflite.firstIntValue(
          await harness.archive.db.rawQuery(
            'SELECT COUNT(*) FROM incidents WHERE id = ?',
            ['inc_x'],
          ),
        ),
        0,
      );
      // The anonymous account's own row is not the deleted account's.
      expect(await harness.archivedAlarms, 1);
    });

    test('a 5xx leaves every local credential exactly as it was', () async {
      final harness = _Harness(failDelete: true);
      await harness.start();
      final oldId = harness.deviceId;
      final oldToken = harness.deviceToken;
      final cubit = harness.cubit;
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.deleteAccount();

      // This is the rule the whole task turns on: a wipe on a call that never
      // landed leaves a live account nobody can reach and a phone that has
      // forgotten it.
      expect(harness.deviceId, oldId);
      expect(harness.deviceToken, oldToken);
      expect(harness.sessions.session?.managementCredential, oldToken);
      expect(harness.connections.connection?.adminToken, oldToken);
      expect(harness.prefs.getString(_cursorKey), 'm_1');
      expect(harness.prefs.getString(AckQueue.storageKey), '[]');
      expect(harness.prefs.getStringList('search_recent_queries'), ['prod']);
      expectAccountDataKept(harness.prefs);
      await harness.ownLook.expectKept();
      expect(await harness.archivedAlarms, 1);
      expect(harness.billingLogOuts, 0);
      expect(cubit.state.status, AccountStatus.signedOut);
      expect(cubit.state.errorMessage, isNotNull);
    });

    test('an open alarm blocks, and the retry after the ack works', () async {
      final harness = _Harness(failDelete: false);
      await harness.start();
      final oldId = harness.deviceId;
      final oldToken = harness.deviceToken;
      harness.server.createTopic(name: 'prod', critical: true);
      final published = harness.server.publishMessage(
        'prod',
        message: 'db01 is down',
        priority: 5,
      );
      final cubit = harness.cubit;
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.deleteAccount();

      expect(cubit.state.liveIncidentId, published.incidentId);
      expect(cubit.state.status, AccountStatus.signedOut);
      // Nothing local moved, which is what lets the retry work.
      expect(harness.deviceId, oldId);
      expect(harness.deviceToken, oldToken);

      harness.server.ackIncident(published.incidentId!);
      await cubit.deleteAccount();

      // No restart in between.
      expect(cubit.state.status, AccountStatus.deleted);
      expect(cubit.state.liveIncidentId, isNull);
      expect(harness.deviceToken, isNot(oldToken));
    });

    test('a dead credential on another route starts the phone over', () async {
      final harness = _Harness(failDelete: false);
      await harness.start();
      final oldId = harness.deviceId;

      await harness.account.recoverFromDeadCredential();

      expect(harness.alarmStops, 1);
      expect(harness.deviceId, isNot(oldId));
      expect(harness.deviceToken, isNotNull);
      expect(
        harness.sessions.session?.managementCredential,
        harness.deviceToken,
      );
      expectAccountDataGone(harness.prefs);
      expectOwnSoundsKept(harness.prefs);
      // The credential died, not the account. The history stays.
      expect(await harness.archivedAlarms, 1);
    });

    // Signing out registers a new anonymous account and logs the store in to
    // it. Without the store log-out first, a paid handset hands its
    // subscription to whoever picks the phone up next.
    test('signing out logs the store out before the new account', () async {
      final harness = _Harness(failDelete: false);
      await harness.start();
      final oldId = harness.deviceId;

      await harness.account.signOutDevice();

      expect(harness.billingLogOuts, 1);
      expect(harness.deviceId, isNot(oldId));
      expect(harness.deviceToken, isNotNull);
    });

    // The phone lands on a new anonymous account. Nothing the old account
    // chose or paid for may be waiting there.
    test('signing out drops what belonged to the account and keeps own '
        'sounds', () async {
      final harness = _Harness(failDelete: false);
      await harness.start();
      expectAccountDataKept(harness.prefs);
      await harness.ownLook.expectKept();

      await harness.account.signOutDevice();

      expectAccountDataGone(harness.prefs);
      expectOwnSoundsKept(harness.prefs);
      await harness.ownLook.expectGone();
      // The history stays for the account to find again. The new anonymous
      // account the phone lands on reads none of it.
      expect(await harness.archivedAlarms, 1);
      expect(await harness.archive.incidents.count(), 0);
    });
  });

  group('against a fake repository', () {
    late FakeIdentityRepository identities;

    setUp(() => identities = FakeIdentityRepository());

    AccountCubit cubitFor(FakeAccountRepository account) =>
        AccountCubit(identities: identities, account: account);

    test('an anonymous account deletes with no sign-in first', () async {
      final account = FakeAccountRepository(linkAnswers: const []);
      final cubit = cubitFor(account);
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.deleteAccount();

      expect(cubit.state.status, AccountStatus.deleted);
      expect(account.wipeCalls, 1);
      // No provider sheet, and no identity token in the body.
      expect(identities.signInCalls, 0);
      expect(account.deleteIdentityTokens, [null]);
    });

    test('a signed-in account sends its identity token', () async {
      final account = FakeAccountRepository(linkAnswers: const []);
      identities
        ..saved = const AccountIdentity(
          provider: IdentityProvider.google,
          accountId: 'acc_1',
        )
        ..session = const IdentitySession(
          token: 'session_live',
          provider: IdentityProvider.google,
        );
      final cubit = cubitFor(account);
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.deleteAccount();

      expect(account.deleteIdentityTokens, ['session_live']);
      expect(cubit.state.status, AccountStatus.deleted);
    });

    test('401 signs in once more, retries once, then gives up', () async {
      final account = FakeAccountRepository(linkAnswers: const [])
        ..deleteAnswers = const [
          AccountDeleteResult.unauthorized(),
          AccountDeleteResult.unauthorized(),
        ];
      identities
        ..saved = const AccountIdentity(
          provider: IdentityProvider.google,
          accountId: 'acc_1',
        )
        ..session = const IdentitySession(
          token: 'session_dead',
          provider: IdentityProvider.google,
        );
      final cubit = cubitFor(account);
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.deleteAccount();

      // One more trip through the provider sheet, one more delete, then stop.
      expect(identities.clearCalls, 1);
      expect(identities.signInCalls, 1);
      expect(account.deleteIdentityTokens, ['session_dead', 'session_1']);
      expect(account.wipeCalls, 0);
      expect(cubit.state.status, AccountStatus.signedIn);
      expect(cubit.state.errorMessage, isNotNull);
    });

    test('401 with nobody signed in does not open a provider sheet', () async {
      final account = FakeAccountRepository(linkAnswers: const [])
        ..deleteAnswers = const [AccountDeleteResult.unauthorized()];
      final cubit = cubitFor(account);
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.deleteAccount();

      // There is no session to renew, so signing in would be asking the
      // person to fix something that is not broken on their side.
      expect(identities.signInCalls, 0);
      expect(account.deleteIdentityTokens.length, 1);
      expect(account.wipeCalls, 0);
      expect(cubit.state.status, AccountStatus.signedOut);
      expect(cubit.state.errorMessage, isNotNull);
    });

    test('a thrown network error wipes nothing', () async {
      final account = FakeAccountRepository(linkAnswers: const [])
        ..deleteError = Exception('connection closed');
      final cubit = cubitFor(account);
      addTearDown(cubit.close);
      await cubit.load();

      await cubit.deleteAccount();

      expect(account.wipeCalls, 0);
      expect(cubit.state.status, AccountStatus.signedOut);
      expect(cubit.state.errorMessage, isNotNull);
    });
  });
}
