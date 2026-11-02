import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/features/account/data/repositories/api_account_repository.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart'
    show PurchasesErrorCode;
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

/// What the store's SDK throws: a [PlatformException] whose code is the
/// index of a [PurchasesErrorCode].
PlatformException _storeError(PurchasesErrorCode code) =>
    PlatformException(code: code.index.toString(), message: code.name);

final class _Harness {
  late final SharedPreferences prefs;
  late final DeviceIdentityStore devices;
  late final ApiAccountRepository account;
  late final _MemoryConnectionRepository connections;
  late final FakeIdentityRepository identities;
  late final MockApiClient api;
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
    api = MockApiClient(server);
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

      test('the store answering already-anonymous is not a failure', () async {
        h.storeError = _storeError(
          PurchasesErrorCode.logOutWithAnonymousUserError,
        );

        await entry.value(h);

        expect(h.storeLogOuts, 1);
        expect(h.forgets, 1);
        expect(h.deviceId, isNot(oldId));
      });

      test('a network error stops before the fresh account', () async {
        h.storeError = _storeError(PurchasesErrorCode.networkError);

        await expectLater(
          entry.value(h),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              PurchasesErrorCode.networkError.index.toString(),
            ),
          ),
        );

        // Nothing moved: same device, same connection, nothing forgotten.
        expect(h.deviceId, oldId);
        expect(h.forgets, 0);
        expect(h.connections.connection, isNotNull);
      });

      test('an error that is not a store code stops it too', () async {
        h.storeError = StateError('boom');

        await expectLater(entry.value(h), throwsStateError);

        expect(h.deviceId, oldId);
        expect(h.forgets, 0);
      });

      test(
        'a store code that is not a number is not the anonymous answer',
        () async {
          h.storeError = PlatformException(code: 'not-a-number');

          await expectLater(entry.value(h), throwsA(isA<PlatformException>()));

          expect(h.deviceId, oldId);
          expect(h.forgets, 0);
        },
      );
    });
  }
}
