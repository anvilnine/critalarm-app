import 'package:critalarm/core/ack/ack_queue.dart';
import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/sync/message_sync_service.dart';
import 'package:critalarm/features/account/data/repositories/api_account_repository.dart';
import 'package:critalarm/features/account/domain/entities/account_identity.dart';
import 'package:critalarm/features/account/domain/entities/identity_provider.dart';
import 'package:critalarm/features/account/presentation/cubits/account_cubit.dart';
import 'package:critalarm/features/account/presentation/cubits/account_state.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:critalarm/features/search/data/repositories/shared_prefs_recent_searches_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    account = ApiAccountRepository(
      api: api,
      sessions: sessions,
      devices: devices,
      register: register,
      identities: identities,
      connections: connections,
      acks: AckQueue(prefs, api),
      messageCursors: MessageSyncService(prefs, api),
      recentSearches: SharedPrefsRecentSearchesRepository(prefs),
      signOutBilling: () async => billingLogOuts++,
      stopAlarm: () async => alarmStops++,
    );
  }

  AccountCubit get cubit =>
      AccountCubit(identities: identities, account: account);
}

void main() {
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
      expect(harness.sessions.session?.managementCredential,
          harness.deviceToken);
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
