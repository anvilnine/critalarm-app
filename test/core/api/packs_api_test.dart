import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/http_api_client.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/account_pack.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _Sessions implements ApiSessionStore {
  ApiSession? session = ApiSession(
    baseUri: Uri.parse('https://server.example'),
    relayUri: Uri.parse('https://relay.example'),
    mode: ServerMode.selfhosted,
    managementCredential: 'ad_secret',
  );

  @override
  Future<void> clear() async => session = null;

  @override
  Future<ApiSession?> read() async => session;

  @override
  Future<void> write(ApiSession session) async => this.session = session;
}

final class _Tokens implements PushTokenProvider {
  @override
  PushTokenKind get kind => PushTokenKind.fcm;

  @override
  Future<String> getToken() async => 'push_token';

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();
}

const _registration = DeviceRegistration(
  deviceId: 'dev_1',
  platform: 'android',
  pushToken: 'push_token',
  appVersion: '1.0.0',
);

void main() {
  late MockServer server;
  late _Sessions sessions;
  String? deviceToken;
  final requests = <http.Request>[];

  HttpApiClient client() => HttpApiClient(
    MockClient((request) {
      requests.add(request);
      return server.handleHttpRequest(request);
    }),
    sessions,
    readDeviceToken: () async => deviceToken,
  );

  setUp(() {
    server = MockServer();
    sessions = _Sessions();
    requests.clear();
    deviceToken = null;
  });

  Future<void> register() async {
    final response = await client().registerDevice(_registration);
    deviceToken = response.deviceToken;
    requests.clear();
  }

  group('packs on registration', () {
    test('an account with no pack registers with an empty list', () async {
      final response = await client().registerDevice(_registration);
      expect(response.packs, isEmpty);
    });

    test('an account that holds the pack is told so on registration', () async {
      server.grantedPacks.add('pro');
      final response = await client().registerDevice(_registration);
      expect(response.packs, const [AccountPack(id: 'pro')]);
    });

    test('and again on every re-registration', () async {
      await register();
      server.grantedPacks.add('pro');
      final response = await client().refreshDevice(
        _registration,
        deviceToken!,
      );
      expect(response.packs, const [AccountPack(id: 'pro')]);
    });

    test('a relay that leaves the field out reads as no packs', () {
      final response = DeviceRegistrationResponse.fromJson(const {
        'account_id': 'acc_1',
        'tier': 'hosted',
        'caps': <String, dynamic>{},
      });
      expect(response.packs, isEmpty);
    });

    test(
      'an id the app does not know is kept as sent, not turned into Pro',
      () {
        final response = DeviceRegistrationResponse.fromJson(const {
          'account_id': 'acc_1',
          'caps': <String, dynamic>{},
          'packs': [
            {'id': 'team', 'expires_at': 1759812345},
          ],
        });
        expect(response.packs, const [
          AccountPack(id: 'team', expiresAt: 1759812345),
        ]);
      },
    );

    test('the registration use case hands the packs on', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      server.grantedPacks.add('pro');
      final handed = <DeviceRegistrationResponse>[];
      await RegisterDeviceUsecase(
        MockApiClient(server),
        DeviceIdentityStore(prefs),
        _Tokens(),
        platform: () => 'android',
        onPacks: (response) async => handed.add(response),
      )(appVersion: '1.0.0');
      expect(handed.single.packs, const [AccountPack(id: 'pro')]);
    });

    test(
      'a failure to keep the packs does not fail the registration',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final response = await RegisterDeviceUsecase(
          MockApiClient(server),
          DeviceIdentityStore(prefs),
          _Tokens(),
          platform: () => 'android',
          onPacks: (_) async => throw StateError('disk full'),
        )(appVersion: '1.0.0');
        expect(response.accountId, isNotEmpty);
      },
    );
  });

  group('GET /relay/v1/packs', () {
    test('goes to the relay with the device token', () async {
      await register();
      await client().getPacks();
      expect(requests.single.method, 'GET');
      expect(
        requests.single.url.toString(),
        'https://relay.example/relay/v1/packs',
      );
      expect(requests.single.headers['authorization'], 'Bearer $deviceToken');
    });

    test('answers what is held and never reads the store', () async {
      await register();
      server.storePacks.add('pro');
      final before = await client().getPacks();
      expect(before.packs, isEmpty);
      expect(before.checkedAt, isNull);

      server.grantedPacks.add('pro');
      final after = await client().getPacks();
      expect(after.packs, const [AccountPack(id: 'pro')]);
    });

    test('a token the relay does not know is refused', () async {
      await register();
      deviceToken = 'dv_wrong';
      expect(
        client().getPacks(),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('with no device token there is nobody to ask', () async {
      expect(client().getPacks(), throwsA(isA<NoApiSessionException>()));
      expect(requests, isEmpty);
    });

    test('with no server set up there is nobody to ask', () async {
      await register();
      sessions.session = null;
      expect(client().refreshPacks(), throwsA(isA<NoApiSessionException>()));
    });
  });

  group('POST /relay/v1/packs/refresh', () {
    test(
      'a purchase the relay has not heard of is found by the read',
      () async {
        await register();
        server.storePacks.add('pro');
        final answer = await client().refreshPacks();
        expect(requests.single.method, 'POST');
        expect(
          requests.single.url.toString(),
          'https://relay.example/relay/v1/packs/refresh',
        );
        expect(answer.confirmed, isTrue);
        expect(answer.packs, const [AccountPack(id: 'pro')]);
        expect(answer.checkedAt, isNotNull);
        expect((await client().getPacks()).packs, isNotEmpty);
      },
    );

    test('the store read and nothing on it', () async {
      await register();
      final answer = await client().refreshPacks();
      expect(answer.confirmed, isTrue);
      expect(answer.packs, isEmpty);
    });

    test('the store cannot be read and the pack was already held', () async {
      await register();
      server
        ..grantedPacks.add('pro')
        ..storeReadable = false;
      final answer = await client().refreshPacks();
      expect(answer.confirmed, isFalse);
      expect(answer.packs, const [AccountPack(id: 'pro')]);
    });

    test('the store cannot be read and nothing is held', () async {
      await register();
      server
        ..storePacks.add('pro')
        ..storeReadable = false;
      final answer = await client().refreshPacks();
      expect(answer.confirmed, isFalse);
      expect(answer.packs, isEmpty);
      expect(answer.checkedAt, isNull);
    });

    test('a failed read takes no pack away', () async {
      await register();
      server.storePacks.add('pro');
      await client().refreshPacks();
      server
        ..storePacks.clear()
        ..storeReadable = false;
      final answer = await client().refreshPacks();
      expect(answer.packs, const [AccountPack(id: 'pro')]);
    });

    test('the seventh call in 60 seconds is rate limited', () async {
      await register();
      var now = DateTime.utc(2026, 10, 7, 9);
      server.packsClock = () => now;
      for (var i = 0; i < MockServer.packRefreshLimit; i++) {
        await client().refreshPacks();
        now = now.add(const Duration(seconds: 1));
      }
      await expectLater(
        client().refreshPacks(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 429)
              .having((e) => e.code, 'code', 42901)
              .having((e) => e.message, 'message', 'rate limited'),
        ),
      );
      now = now.add(MockServer.packRefreshWindow);
      expect((await client().refreshPacks()).confirmed, isTrue);
    });

    test('the in-memory client answers the same routes', () async {
      final mock = MockApiClient(server);
      server.storePacks.add('pro');
      expect((await mock.getPacks()).packs, isEmpty);
      expect((await mock.refreshPacks()).packs, isNotEmpty);
      expect((await mock.getPacks()).packs, isNotEmpty);
    });
  });

  test('a 403 pack error keeps the pack it names', () async {
    final refusing = HttpApiClient(
      MockClient(
        (_) async => http.Response('{"error":"pack","pack":"pro"}', 403),
      ),
      sessions,
      readDeviceToken: () async => 'dv_1',
    );
    await expectLater(
      refusing.getPacks(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.message, 'message', 'pack')
            .having((e) => e.pack, 'pack', 'pro')
            .having((e) => e.cap, 'cap', isNull),
      ),
    );
  });

  test('a pack route called with no bearer is refused', () async {
    final response = await MockServer().handleHttpRequest(
      http.Request('GET', Uri.parse('https://relay.example/relay/v1/packs')),
    );
    expect(response.statusCode, 401);
  });
}
