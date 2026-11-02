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
import 'package:critalarm/core/store/services/store_billing.dart';
import 'package:critalarm/features/account/data/repositories/api_account_repository.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_fakes.dart';

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
  ServerConnection? connection;

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

/// What `StoreBilling.logOut` throws when the store could not be reached.
const _storeError = StoreBillingException(StoreBillingError.network);

/// A client whose device delete can be made to answer with a given status.
final class _ScriptedDeleteApiClient extends MockApiClient {
  _ScriptedDeleteApiClient(super.server);

  ApiException? deleteFailure;
  int deleteCalls = 0;

  @override
  Future<void> deleteDevice({
    required String deviceId,
    required String deviceToken,
    Uri? relayUri,
  }) {
    deleteCalls++;
    final failure = deleteFailure;
    if (failure != null) return Future<void>.error(failure);
    return super.deleteDevice(deviceId: deviceId, deviceToken: deviceToken);
  }
}

final class _Harness {
  late final SharedPreferences prefs;
  late final DeviceIdentityStore devices;
  late final ApiAccountRepository account;
  late final _MemoryConnectionRepository connections;
  late final FakeIdentityRepository identities;
  late final _ScriptedDeleteApiClient api;
  late final _MemoryApiSessionStore sessions;

  int forgets = 0;
  int storeLogOuts = 0;
  Object? storeError;

  String? get deviceId => prefs.getString('device_id');
  String? get deviceToken => prefs.getString('device_token');

  Future<void> start() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final server = MockServer(
      serverInfo: const ServerInfo(
        version: '0.1.0',
        baseUrl: 'https://server.example',
        relayUrl: 'https://relay.example',
        mode: ServerModes.hosted,
      ),
    );
    api = _ScriptedDeleteApiClient(server);
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
    account = ApiAccountRepository(
      api: api,
      sessions: sessions,
      devices: devices,
      register: register,
      identities: identities,
      connections: connections,
      forgetAccountData: () async => forgets++,
      signOutBilling: () {
        storeLogOuts++;
        final error = storeError;
        return error == null ? Future<void>.value() : Future<void>.error(error);
      },
    );
  }
}

void main() {
  for (final entry in <String, Future<void> Function(_Harness)>{
    'signOutDevice': (h) => h.account.signOutDevice(),
    'wipeAfterDelete': (h) => h.account.wipeAfterDelete(),
    'recoverFromDeadCredential': (h) => h.account.recoverFromDeadCredential(),
  }.entries) {
    group(entry.key, () {
      late _Harness h;
      late String? oldId;

      setUp(() async {
        h = _Harness();
        await h.start();
        oldId = h.deviceId;
      });

      test('success logs the store out and starts a fresh account', () async {
        await entry.value(h);

        expect(h.storeLogOuts, 1);
        expect(h.forgets, 1);
        expect(h.deviceId, isNot(oldId));
        expect(h.deviceToken, isNotNull);
      });

      // "Already anonymous" is the store's own business: StoreBilling.logOut
      // returns quietly for it (revenuecat_billing_test.dart). Here any throw
      // stops the sign-out.
      for (final MapEntry(key: label, value: error) in <String, Object>{
        'a store error': _storeError,
        'an app fault': StateError('boom'),
        'a raw platform error': PlatformException(code: 'not-a-number'),
      }.entries) {
        test('$label stops before the fresh account', () async {
          h.storeError = error;

          await expectLater(entry.value(h), throwsA(same(error)));

          // Nothing moved: same device, same connection, nothing forgotten.
          expect(h.deviceId, oldId);
          expect(h.forgets, 0);
          expect(h.connections.connection, isNotNull);
        });
      }
    });
  }

  group('signOutDevice retry after a store failure', () {
    late _Harness h;
    late String? oldId;

    setUp(() async {
      h = _Harness();
      await h.start();
      oldId = h.deviceId;
    });

    // The first press deletes the device on the server and then stops on the
    // store. The second finds the server no longer knows the device.
    for (final status in [401, 404]) {
      test(
        'a $status on the delete is already deleted, so a retry finishes',
        () async {
          h.storeError = _storeError;
          await expectLater(
            h.account.signOutDevice(),
            throwsA(isA<StoreBillingException>()),
          );
          expect(h.api.deleteCalls, 1);
          expect(h.deviceId, oldId);
          expect(h.forgets, 0);

          // The mock server dropped the device on the first press; a real one
          // answers either status for a device it has forgotten.
          h.api.deleteFailure = ApiException(
            statusCode: status,
            message: 'gone',
          );
          h.storeError = null;

          await h.account.signOutDevice();

          expect(h.api.deleteCalls, 2);
          expect(h.storeLogOuts, 2);
          expect(h.forgets, 1);
          expect(h.deviceId, isNot(oldId));
          expect(h.deviceToken, isNotNull);
        },
      );
    }

    test(
      'without a scripted answer the mock server already says 401',
      () async {
        h.storeError = _storeError;
        await expectLater(
          h.account.signOutDevice(),
          throwsA(isA<StoreBillingException>()),
        );
        h.storeError = null;

        await h.account.signOutDevice();

        expect(h.deviceId, isNot(oldId));
      },
    );

    test('a 500 on the delete still stops before the store logout', () async {
      h.api.deleteFailure = const ApiException(
        statusCode: 500,
        message: 'server error',
      );

      await expectLater(
        h.account.signOutDevice(),
        throwsA(isA<ApiException>()),
      );

      expect(h.storeLogOuts, 0);
      expect(h.forgets, 0);
      expect(h.deviceId, oldId);
    });
  });
}
