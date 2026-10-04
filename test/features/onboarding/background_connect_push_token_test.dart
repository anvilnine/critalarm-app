import 'dart:async';

import 'package:critalarm/core/account/plan_changes.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/storage/shared_prefs_api_session_store.dart';
import 'package:critalarm/features/onboarding/data/repositories/in_memory_server_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/connect/background_connect.dart';
import 'package:critalarm/features/onboarding/domain/connect/connect_intent_store.dart';
import 'package:critalarm/features/onboarding/domain/usecases/establish_api_session_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const cloudUrl = 'https://api.critalarm.app';

/// The API fake, keeping every registration it was sent.
class _Api extends MockApiClient {
  _Api()
    : super(
        MockServer(
          serverInfo: const ServerInfo(
            version: '0.9.0',
            baseUrl: cloudUrl,
            relayUrl: 'https://relay.critalarm.app',
            mode: ServerModes.hosted,
          ),
        ),
      );

  final registrations = <DeviceRegistration>[];

  @override
  Future<DeviceRegistrationResponse> registerDevice(
    DeviceRegistration registration, {
    Uri? relayUri,
    String? accountJoinToken,
  }) {
    registrations.add(registration);
    return super.registerDevice(
      registration,
      relayUri: relayUri,
      accountJoinToken: accountJoinToken,
    );
  }
}

/// A push token source whose token can turn up later.
class _Tokens implements PushTokenProvider {
  _Tokens(this.kind, {this.token});

  @override
  final PushTokenKind kind;

  String? token;
  int reads = 0;
  final _arrivals = StreamController<String>.broadcast();

  /// The system hands the token over, as it does once it has registered the
  /// phone for remote notifications.
  void arrive(String value) {
    token = value;
    _arrivals.add(value);
  }

  @override
  Future<String> getToken() async {
    reads++;
    return token ?? (throw StateError('push token unavailable'));
  }

  @override
  Stream<String> get tokenRefreshes => _arrivals.stream;
}

void main() {
  late SharedPreferences prefs;
  late ConnectIntentStore intents;
  late _Api api;
  late SharedPrefsConnectionRepository connections;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    intents = ConnectIntentStore(prefs);
    api = _Api();
    connections = SharedPrefsConnectionRepository(prefs);
  });

  BackgroundConnect build(_Tokens tokens, {required String platform}) {
    final identity = DeviceIdentityStore(prefs);
    final connect = BackgroundConnect(
      intents: intents,
      getServerInfo: GetServerInfoUsecase(InMemoryServerRepository(api)),
      establishSession: EstablishApiSessionUsecase(
        SharedPrefsApiSessionStore(prefs),
        RegisterDeviceUsecase(
          api,
          identity,
          tokens,
          platform: () => platform,
          planChanges: PlanChanges(),
        ),
        identity,
      ),
      saveConnection: SaveConnectionUsecase(connections),
      tokens: tokens,
      clock: () => DateTime.utc(2026, 10, 4, 9),
    );
    addTearDown(connect.dispose);
    return connect;
  }

  Future<bool> hasConnection() async =>
      (await connections.getConnection()).getOrNull() != null;

  group('iOS (APNs token)', () {
    test(
      'token already there at Continue: registers on the first try',
      () async {
        final tokens = _Tokens(PushTokenKind.apns, token: 'apns-early');
        final connect = build(tokens, platform: 'ios');

        await connect.start(cloudUrl);
        await connect.settled;

        expect(connect.state.status, BackgroundConnectStatus.connected);
        expect(api.registrations, hasLength(1));
        expect(api.registrations.single.platform, 'ios');
        expect(api.registrations.single.pushToken, 'apns-early');
        expect(await hasConnection(), isTrue);
      },
    );

    test('token unavailable at Continue: waits, registers nothing, saves '
        'no connection', () async {
      final tokens = _Tokens(PushTokenKind.apns);
      final connect = build(tokens, platform: 'ios');

      await connect.start(cloudUrl);
      await connect.settled;

      expect(connect.state.status, BackgroundConnectStatus.waitingForPushToken);
      expect(connect.state.isPending, isTrue);
      expect(api.registrations, isEmpty);
      expect(await hasConnection(), isFalse);
      expect(intents.read()?.serverUrl, cloudUrl);
    });

    test('token arrives after the notifications step: registration runs '
        'with no tap', () async {
      final tokens = _Tokens(PushTokenKind.apns);
      final connect = build(tokens, platform: 'ios');
      await connect.start(cloudUrl);
      await connect.settled;
      expect(connect.state.status, BackgroundConnectStatus.waitingForPushToken);

      // The system hands the token over. Nothing else happens.
      final landed = connect.stream.firstWhere((s) => s.isConnected);
      tokens.arrive('apns-late');
      await landed.timeout(const Duration(seconds: 2));

      expect(api.registrations, hasLength(1));
      expect(api.registrations.single.platform, 'ios');
      expect(api.registrations.single.pushToken, 'apns-late');
      expect(await hasConnection(), isTrue);
      expect(intents.read(), isNull);
    });

    test('token there by the time the permission steps are done: the retry '
        'that follows them registers', () async {
      final tokens = _Tokens(PushTokenKind.apns);
      final connect = build(tokens, platform: 'ios');
      await connect.start(cloudUrl);
      await connect.settled;

      // The token is in hand, but no arrival was announced. Finishing the
      // permission steps, or the app coming back to the front after the
      // system prompt, both end in retryNow.
      tokens.token = 'apns-after-prompt';
      await connect.retryNow();

      expect(connect.state.status, BackgroundConnectStatus.connected);
      expect(api.registrations.single.pushToken, 'apns-after-prompt');
    });

    test('still no token after the permission steps: keeps waiting', () async {
      final tokens = _Tokens(PushTokenKind.apns);
      final connect = build(tokens, platform: 'ios');
      await connect.start(cloudUrl);
      await connect.settled;

      await connect.retryNow();

      expect(connect.state.status, BackgroundConnectStatus.waitingForPushToken);
      expect(api.registrations, isEmpty);
      expect(intents.read()!.attempts, 2);
    });
  });

  group('Android (Firebase Messaging token)', () {
    test('token available at once: registers on the first try and never '
        'waits', () async {
      final tokens = _Tokens(PushTokenKind.fcm, token: 'fcm-token');
      final connect = build(tokens, platform: 'android');
      final seen = <BackgroundConnectStatus>[];
      connect.stream.listen((s) => seen.add(s.status));

      await connect.start(cloudUrl);
      await connect.settled;

      expect(seen, [
        BackgroundConnectStatus.connecting,
        BackgroundConnectStatus.connected,
      ]);
      expect(tokens.reads, 1);
      expect(api.registrations, hasLength(1));
      expect(api.registrations.single.platform, 'android');
      expect(api.registrations.single.pushToken, 'fcm-token');
      expect(await hasConnection(), isTrue);
    });

    test('a build with no Firebase: the fetch fails, the connect waits, and '
        'a later retry registers', () async {
      final tokens = _Tokens(PushTokenKind.fcm);
      final connect = build(tokens, platform: 'android');

      await connect.start(cloudUrl);
      await connect.settled;
      expect(connect.state.status, BackgroundConnectStatus.waitingForPushToken);
      expect(api.registrations, isEmpty);

      tokens.token = 'fcm-late';
      await connect.retryNow();

      expect(connect.state.status, BackgroundConnectStatus.connected);
      expect(api.registrations.single.platform, 'android');
      expect(api.registrations.single.pushToken, 'fcm-late');
    });
  });
}
