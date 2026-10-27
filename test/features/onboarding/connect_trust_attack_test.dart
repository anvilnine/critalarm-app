import 'dart:convert';

import 'package:critalarm/core/api/http_api_client.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/server_info_validator.dart';
import 'package:critalarm/core/push/device_token_relay.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/storage/shared_prefs_api_session_store.dart';
import 'package:critalarm/features/onboarding/data/repositories/in_memory_server_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/connect_to_server_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/establish_api_session_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/model/connect_outcome_message.dart';
import 'package:critalarm/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:critalarm/features/settings/presentation/server_settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_device_keychain.dart';

/// Where the phone's credentials go when a connect or a registration meets
/// a server or a relay it did not choose before. Same harness as
/// connect_trust_test.dart: the real use cases, stores and HTTP client over
/// a fake network.

const _home = 'https://alarm.example.com';
const _homeRelay = 'https://relay.example.com';
const _evil = 'https://evil.example.net';
const _evilRelay = 'https://relay.evil.example.net';
const _deviceToken = 'dv_issued_by_the_home_relay';
const _adminToken = 'ad_the_working_one';
const _joinToken = 'aj_of_the_cloud_account';

final class _PushTokens implements PushTokenProvider {
  @override
  PushTokenKind get kind => PushTokenKind.fcm;

  @override
  Future<String> getToken() async => 'push_token';

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

http.Response _info({
  required String baseUrl,
  required String relayUrl,
  String mode = 'selfhosted',
}) => _json({
  'name': 'critalarm',
  'version': '0.1.0',
  'base_url': baseUrl,
  'relay_url': relayUrl,
  'relay_content': 'none',
  'mode': mode,
});

http.Response _registered([String token = 'dv_from_this_relay']) => _json({
  'device_token': token,
  'account_id': 'acc_new',
  'tier': 'free',
  'caps': <String, dynamic>{},
  'packs': <dynamic>[],
}, 201);

http.Response _refreshed(String accountId) => _json({
  'account_id': accountId,
  'tier': 'free',
  'caps': <String, dynamic>{},
  'packs': <dynamic>[],
});

/// A connection store whose save fails, the way a full disk does.
final class _FailingSave implements ConnectionRepository {
  _FailingSave(this._inner);
  final ConnectionRepository _inner;

  @override
  Future<AppResult<ServerConnection>> getConnection() => _inner.getConnection();

  @override
  Future<AppResult<Unit>> saveConnection(ServerConnection connection) async =>
      const Failure.unexpected(message: 'disk full').toFailure();

  @override
  Future<AppResult<Unit>> clearConnection() => _inner.clearConnection();
}

final class _Phone {
  _Phone(
    this.prefs,
    this.requests,
    this.client,
    this.connect,
    this.register,
    this.establish,
    this.identity,
    this.connections,
  );

  final SharedPreferences prefs;
  final List<http.Request> requests;
  final HttpApiClient client;
  final ConnectToServerUsecase connect;
  final RegisterDeviceUsecase register;
  final EstablishApiSessionUsecase establish;
  final DeviceIdentityStore identity;
  final ConnectionRepository connections;

  SharedPrefsApiSessionStore get sessions => SharedPrefsApiSessionStore(prefs);

  Map<String, Object?> get stores => {
    for (final key in prefs.getKeys().toList()..sort()) key: prefs.get(key),
  };

  /// The relay and the token the native weekly check receipt pairs: the
  /// relay of the saved session, and the device token, sent only when its
  /// issuer (the hosted relay when none is written down) is that relay.
  Future<void> expectNativePairingSafe() async {
    final session = await sessions.read();
    final held = await identity.read();
    final token = held?.deviceToken;
    if (session == null || token == null) return;
    final issuer = held?.tokenRelay ?? hostedRelayUrl;
    expect(
      ServerInfoValidation.isSameAddress(issuer, session.relayUri.toString()),
      isTrue,
      reason:
          'the session names ${session.relayUri} beside a token from $issuer',
    );
  }

  List<http.Request> carrying(String secret) => [
    for (final request in requests)
      if (request.url.toString().contains(secret) ||
          request.headers.values.any((value) => value.contains(secret)) ||
          request.body.contains(secret))
        request,
  ];

  /// The Settings > Server "Edit server" sheet, wired as lib/app/di.dart
  /// wires it.
  SettingsCubit settings() => SettingsCubit(
    identityStore: identity,
    apiSessions: sessions,
    getServerInfo: GetServerInfoUsecase(InMemoryServerRepository(client)),
    establishSession: establish,
    saveConnectionUsecase: SaveConnectionUsecase(connections),
    connectionRepository: connections,
  );
}

/// [saved] is everything the phone holds. [useKeychain] gives it the iPhone
/// identity store over the fake Keychain.
Future<_Phone> _phone(
  Map<String, http.Response Function(http.Request request)> routes, {
  Map<String, Object> saved = const {},
  bool isConnected = true,
  bool saveFails = false,
  bool useKeychain = false,
  http.Client? network,
}) async {
  SharedPreferences.setMockInitialValues({
    if (isConnected) ...{
      'api_session': '$_home|$_homeRelay|selfhosted|$_adminToken',
      'server_url': _home,
      'admin_token': _adminToken,
      'device_id': 'dev_this_phone',
      'device_token': _deviceToken,
      'device_token_relay': _homeRelay,
      'account_id': 'acc_home',
    },
    ...saved,
  });
  final prefs = await SharedPreferences.getInstance();
  final requests = <http.Request>[];
  final sessions = SharedPrefsApiSessionStore(prefs);
  final identity = useKeychain
      ? KeychainDeviceIdentityStore(prefs)
      : DeviceIdentityStore(prefs);
  final client = HttpApiClient(
    network ??
        MockClient((request) async {
          requests.add(request);
          final route =
              routes['${request.method} ${request.url.origin}'
                  '${request.url.path}'];
          return route?.call(request) ?? http.Response('{"error":"nope"}', 404);
        }),
    sessions,
  );
  final register = RegisterDeviceUsecase(
    client,
    identity,
    _PushTokens(),
    platform: () => useKeychain ? 'ios' : 'android',
    readSessionRelay: () async => (await sessions.read())?.relayUri,
  );
  final establish = EstablishApiSessionUsecase(sessions, register, identity);
  final ConnectionRepository stored = SharedPrefsConnectionRepository(prefs);
  final connections = saveFails ? _FailingSave(stored) : stored;
  final connect = ConnectToServerUsecase(
    GetServerInfoUsecase(InMemoryServerRepository(client)),
    establish,
    SaveConnectionUsecase(connections),
    readSavedServerUrl: () async =>
        (await connections.getConnection()).getOrNull()?.serverUrl,
    proveAdminToken: client.checkManagementCredential,
    readRelayTrust: establish.relayTrust,
  );
  return _Phone(
    prefs,
    requests,
    client,
    connect,
    register,
    establish,
    identity,
    connections,
  );
}

/// A phone on Crit Alarm Cloud: the relay at [_homeRelay] is also its
/// server, and the device token is its management credential.
const _onCloud = <String, Object>{
  'api_session': '$_homeRelay|$_homeRelay|hosted|$_deviceToken',
  'server_url': _homeRelay,
  'admin_token': _deviceToken,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('guarantee 1, the device token stays with its issuer', () {
    test('typed by hand, a server that says it is hosted and names the '
        'issuing relay as its relay is refused before the device token is '
        'sent anywhere, and nothing saved changes', () async {
      final phone = await _phone({
        'GET $_evil/v1/info': (_) =>
            _info(baseUrl: _evil, relayUrl: _homeRelay, mode: 'hosted'),
        'PATCH $_homeRelay/relay/v1/devices/dev_this_phone': (_) =>
            _refreshed('acc_home'),
        'GET $_evil/v1/topics': (_) => _json(<dynamic>[]),
        'GET $_homeRelay/v1/topics': (_) => _json(<dynamic>[]),
      }, saved: _onCloud);
      final before = phone.stores;

      final outcome = await phone.connect(serverUrl: _evil, adminToken: '');

      expect(outcome, isA<RegisteredElsewhere>());
      expect(phone.carrying(_deviceToken), isEmpty);
      expect(phone.stores, before);
      // The next management call still goes to the server the token is for.
      await phone.client.getTopics();
      expect(phone.carrying(_deviceToken).map((r) => r.url.origin).toSet(), {
        _homeRelay,
      });
    });

    test('Settings > Edit server does not hand the same hosted answer the '
        'device token either', () async {
      final phone = await _phone({
        'GET $_evil/v1/info': (_) =>
            _info(baseUrl: _evil, relayUrl: _homeRelay, mode: 'hosted'),
        'PATCH $_homeRelay/relay/v1/devices/dev_this_phone': (_) =>
            _refreshed('acc_home'),
        'GET $_evil/v1/topics': (_) => _json(<dynamic>[]),
      }, saved: _onCloud);
      final settings = phone.settings();
      addTearDown(settings.close);

      await settings.saveConnection(serverUrl: _evil, adminToken: 'x');
      try {
        await phone.client.getTopics();
      } on Object catch (_) {}

      expect(
        phone.carrying(_deviceToken).map((r) => r.url.origin).toSet(),
        {_homeRelay},
      );
    });
  });

  group('guarantee 4, a failed connect changes nothing saved', () {
    test('a connection that cannot be saved leaves the session as it '
        'was', () async {
      final phone = await _phone({
        'GET $_evil/v1/info': (_) =>
            _info(baseUrl: _evil, relayUrl: _homeRelay),
        'GET $_evil/v1/incidents': (_) => _json(<dynamic>[]),
      }, saveFails: true);
      final before = phone.stores;

      final outcome = await phone.connect(
        serverUrl: _evil,
        adminToken: 'ad_other',
        pinToAddress: true,
      );

      expect(outcome, isA<ConnectionNotSaved>());
      expect(phone.stores, before);
    });

    test('typed by hand, a hosted server whose relay answers with a token '
        'the session cannot hold leaves the identity as it was', () async {
      final phone = await _phone({
        'GET $_evil/v1/info': (_) =>
            _info(baseUrl: _evil, relayUrl: _evilRelay, mode: 'hosted'),
        'POST $_evilRelay/relay/v1/devices': (_) => _registered('dv_a|b'),
      }, isConnected: false);
      final before = phone.stores;

      final outcome = await phone.connect(serverUrl: _evil, adminToken: '');

      expect(outcome, isNot(isA<Connected>()));
      expect(phone.stores, before);
    });
  });

  group('Settings > Edit server', () {
    test('a wrong admin token is not saved', () async {
      final phone = await _phone({
        'GET $_home/v1/info': (_) =>
            _info(baseUrl: _home, relayUrl: _homeRelay),
        'GET $_home/v1/incidents': (request) =>
            request.headers['authorization'] == 'Bearer $_adminToken'
            ? _json(<dynamic>[])
            : _json({'error': 'unauthorized'}, 401),
      });
      final before = phone.stores;
      final settings = phone.settings();
      addTearDown(settings.close);

      await settings.saveConnection(serverUrl: _home, adminToken: 'ad_wrong');

      expect(phone.stores, before);
    });

    test('a server on another relay is refused and the saved connection '
        'stays', () async {
      final phone = await _phone({
        'GET $_evil/v1/info': (_) =>
            _info(baseUrl: _evil, relayUrl: _evilRelay),
        'GET $_evil/v1/incidents': (_) => _json(<dynamic>[]),
      });
      final before = phone.stores;
      final settings = phone.settings();
      addTearDown(settings.close);

      await settings.saveConnection(serverUrl: _evil, adminToken: 'x');

      expect(phone.stores, before);
      expect(settings.state.isConnected, isFalse);
    });
  });

  group('Settings > Edit server says why it did not save', () {
    test('a wrong admin token is a line for the token field, and the sheet '
        'is told it did not land', () async {
      final phone = await _phone({
        'GET $_home/v1/info': (_) =>
            _info(baseUrl: _home, relayUrl: _homeRelay),
        'GET $_home/v1/incidents': (_) => _json({'error': 'no'}, 401),
      });
      final settings = phone.settings();
      addTearDown(settings.close);

      final outcome = await settings.saveConnection(
        serverUrl: _home,
        adminToken: 'ad_wrong',
      );

      expect(outcome, isA<AdminTokenRefused>());
      expect(editServerErrorIsOnToken(outcome!), isTrue);
      expect(
        settings.state.errorMessage,
        'The server did not accept this admin token. Not connected.',
      );
      expect(settings.state.isSavingConnection, isFalse);
      expect(settings.state.isConnected, isFalse);
    });

    test('a refused server is a line for the address field', () async {
      final phone = await _phone({
        'GET $_evil/v1/info': (_) =>
            _info(baseUrl: _evil, relayUrl: _evilRelay),
      });
      final settings = phone.settings();
      addTearDown(settings.close);

      final outcome = await settings.saveConnection(
        serverUrl: _evil,
        adminToken: 'x',
      );

      expect(outcome, isA<RelayDiffers>());
      expect(editServerErrorIsOnToken(outcome!), isFalse);
      expect(settings.state.errorMessage, isNotEmpty);
    });

    test('a connect that lands saves the address the server reported and '
        'clears an old error', () async {
      final phone = await _phone({
        'GET $_home/v1/info': (_) =>
            _info(baseUrl: _home, relayUrl: _homeRelay),
        'GET $_home/v1/incidents': (request) =>
            request.headers['authorization'] == 'Bearer ad_rotated'
            ? _json(<dynamic>[])
            : _json({'error': 'no'}, 401),
      });
      final settings = phone.settings();
      addTearDown(settings.close);

      await settings.saveConnection(serverUrl: _home, adminToken: 'ad_wrong');
      final outcome = await settings.saveConnection(
        serverUrl: '$_home/',
        adminToken: 'ad_rotated',
      );

      expect(outcome, isA<Connected>());
      expect(settings.state.errorMessage, isNull);
      expect(settings.state.isConnected, isTrue);
      expect(settings.state.serverUrl, _home);
      expect(phone.prefs.getString('admin_token'), 'ad_rotated');
    });
  });

  group('guarantee 5, the admin token is in no outcome', () {
    test('a token with a character a header cannot carry is refused before '
        'any request carries it, and is in no outcome or message', () async {
      const pasted = '$_adminToken\u200B';
      final phone = await _phone({
        'GET $_home/v1/info': (_) =>
            _info(baseUrl: _home, relayUrl: _homeRelay),
        'GET $_home/v1/incidents': (_) => _json(<dynamic>[]),
      });
      final before = phone.stores;

      final outcome = await phone.connect(serverUrl: _home, adminToken: pasted);

      expect(outcome, isA<AdminTokenRefused>());
      expect(
        phone.requests.where((r) => r.headers.containsKey('authorization')),
        isEmpty,
      );
      expect(connectOutcomeMessage(outcome), isNot(contains(_adminToken)));
      expect(phone.stores, before);
    });
  });

  // A relay credential with no issuer written beside it counts as issued by
  // the hosted relay. It goes there only, and the phone registers fresh
  // anywhere else.
  group('a relay credential with no issuer written down', () {
    test('typed by hand on a phone whose device token has no recorded '
        'issuer and no session, a self-hosted server with a relay of its '
        'own does not get the token', () async {
      final phone = await _phone(
        {
          'GET $_evil/v1/info': (_) =>
              _info(baseUrl: _evil, relayUrl: _evilRelay),
          'GET $_evil/v1/incidents': (_) => _json(<dynamic>[]),
          'PATCH $_evilRelay/relay/v1/devices/dev_this_phone': (_) =>
              _refreshed('acc_x'),
          'POST $_evilRelay/relay/v1/devices': (_) => _registered(),
        },
        isConnected: false,
        saved: {
          'device_id': 'dev_this_phone',
          'device_token': _deviceToken,
          'account_id': 'acc_home',
        },
      );

      await phone.connect(serverUrl: _evil, adminToken: 'x');
      // The next launch or resume.
      try {
        await phone.register(appVersion: '1.0.0');
      } on Object catch (_) {}

      expect(phone.carrying(_deviceToken), isEmpty);
      // It registered there as a new device.
      expect(
        phone.requests.map((r) => '${r.method} ${r.url}'),
        contains('POST $_evilRelay/relay/v1/devices'),
      );
      expect(phone.prefs.getString('device_id'), isNot('dev_this_phone'));
    });

    test('a link on an iPhone that holds a synced join token and no device '
        'token does not send the join token to the relay the link server '
        'names', () async {
      final keychain = FakeDeviceKeychain()
        ..install()
        ..seedAccount(accountId: 'acc_cloud', joinToken: _joinToken);
      addTearDown(keychain.remove);
      final phone = await _phone(
        {
          'GET $_evil/v1/info': (_) =>
              _info(baseUrl: _evil, relayUrl: _evilRelay),
          'GET $_evil/v1/incidents': (_) => _json(<dynamic>[]),
          'POST $_evilRelay/relay/v1/devices': (_) => _registered(),
        },
        isConnected: false,
        useKeychain: true,
      );

      final outcome = await phone.connect(
        serverUrl: _evil,
        adminToken: 'x',
        pinToAddress: true,
      );
      // The next launch or resume registers on the relay of the session.
      if (outcome is Connected) {
        try {
          await phone.register(appVersion: '1.0.0');
        } on Object catch (_) {}
      }

      expect(
        phone.carrying(_joinToken).map((r) => '${r.method} ${r.url}'),
        isEmpty,
      );
      expect(outcome, isA<Connected>());
      expect(
        phone.requests.map((r) => '${r.method} ${r.url}'),
        contains('POST $_evilRelay/relay/v1/devices'),
      );
      // The synced account item, which every handset on the Apple ID reads,
      // is the hosted account still.
      expect(keychain.account, {
        'account_id': 'acc_cloud',
        'account_join_token': _joinToken,
      });
    });

    test('a link on an iPhone still carrying the old shared device row '
        "does not send that row's device token to the relay the link "
        'server names', () async {
      final keychain = FakeDeviceKeychain()
        ..install()
        ..seedCombined(
          deviceId: 'dev_shared',
          deviceToken: _deviceToken,
          accountId: 'acc_cloud',
          accountJoinToken: _joinToken,
        );
      addTearDown(keychain.remove);
      final phone = await _phone(
        {
          'GET $_evil/v1/info': (_) =>
              _info(baseUrl: _evil, relayUrl: _evilRelay),
          'GET $_evil/v1/incidents': (_) => _json(<dynamic>[]),
          'POST $_evilRelay/relay/v1/devices': (_) => _registered(),
          'DELETE $_evilRelay/relay/v1/devices/dev_shared': (_) =>
              http.Response('', 204),
        },
        isConnected: false,
        useKeychain: true,
      );

      final outcome = await phone.connect(
        serverUrl: _evil,
        adminToken: 'x',
        pinToAddress: true,
      );
      if (outcome is Connected) {
        try {
          await phone.register(appVersion: '1.0.0');
        } on Object catch (_) {}
      }

      expect(
        phone.carrying(_deviceToken).map((r) => '${r.method} ${r.url}'),
        isEmpty,
      );
      expect(
        phone.carrying(_joinToken).map((r) => '${r.method} ${r.url}'),
        isEmpty,
      );
      // The shared row is still owed a release on the hosted relay.
      expect(keychain.device?['retired_device_id'], 'dev_shared');
      expect(keychain.device?['retired_device_token'], _deviceToken);
    });

    test('on the hosted relay the join token and the shared row are used as '
        'before', () async {
      final keychain = FakeDeviceKeychain()
        ..install()
        ..seedCombined(
          deviceId: 'dev_shared',
          deviceToken: _deviceToken,
          accountId: 'acc_cloud',
          accountJoinToken: _joinToken,
        );
      addTearDown(keychain.remove);
      final phone = await _phone(
        {
          'POST $hostedRelayUrl/relay/v1/devices': (_) => _registered(),
          'DELETE $hostedRelayUrl/relay/v1/devices/dev_shared': (_) =>
              http.Response('', 204),
        },
        isConnected: false,
        useKeychain: true,
        saved: {
          'api_session':
              'https://api.critalarm.app|$hostedRelayUrl|hosted|$_deviceToken',
        },
      );

      await phone.register(appVersion: '1.0.0');

      expect(
        phone.carrying(_joinToken).map((r) => '${r.method} ${r.url}'),
        ['POST $hostedRelayUrl/relay/v1/devices'],
      );
      expect(
        phone.carrying(_deviceToken).map((r) => '${r.method} ${r.url}'),
        ['DELETE $hostedRelayUrl/relay/v1/devices/dev_shared'],
      );
      expect(keychain.device?['retired_device_id'], isNull);
    });
  });

  group('a phone with no saved server', () {
    test(
      'typed by hand, a server that says it is hosted and names the '
      'hosted relay does not get the device token from before the update',
      () async {
        final phone = await _phone(
          {
            'GET $_evil/v1/info': (_) =>
                _info(baseUrl: _evil, relayUrl: hostedRelayUrl, mode: 'hosted'),
            'PATCH $hostedRelayUrl/relay/v1/devices/dev_this_phone': (_) =>
                _refreshed('acc_home'),
            'POST $hostedRelayUrl/relay/v1/devices': (_) => _registered(),
            'GET $_evil/v1/topics': (_) => _json(<dynamic>[]),
          },
          isConnected: false,
          saved: {
            'device_id': 'dev_this_phone',
            'device_token': _deviceToken,
            'account_id': 'acc_home',
          },
        );

        final outcome = await phone.connect(serverUrl: _evil, adminToken: '');
        try {
          await phone.client.getTopics();
        } on Object catch (_) {}

        expect(phone.carrying(_deviceToken), isEmpty);
        // It registered as a new device, and that token is what the server
        // holds.
        expect(outcome, isA<Connected>());
        expect(
          (await phone.sessions.read())?.managementCredential,
          'dv_from_this_relay',
        );
        expect(phone.prefs.getString('device_id'), isNot('dev_this_phone'));
        await phone.expectNativePairingSafe();
      },
    );

    test('the same on an iPhone reinstalled with its Keychain, and the '
        'synced join token does not reach that server either', () async {
      final keychain = FakeDeviceKeychain()
        ..install()
        ..seedAccount(accountId: 'acc_cloud', joinToken: _joinToken)
        ..seedDevice(
          deviceId: 'dev_this_phone',
          deviceToken: _deviceToken,
          accountId: 'acc_cloud',
        );
      addTearDown(keychain.remove);
      final phone = await _phone(
        {
          'GET $_evil/v1/info': (_) =>
              _info(baseUrl: _evil, relayUrl: hostedRelayUrl, mode: 'hosted'),
          'PATCH $hostedRelayUrl/relay/v1/devices/dev_this_phone': (_) =>
              _refreshed('acc_cloud'),
          'POST $hostedRelayUrl/relay/v1/devices': (_) => _registered(),
          'GET $_evil/v1/topics': (_) => _json(<dynamic>[]),
        },
        isConnected: false,
        useKeychain: true,
      );

      await phone.connect(serverUrl: _evil, adminToken: '');
      try {
        await phone.client.getTopics();
      } on Object catch (_) {}

      expect(phone.carrying(_deviceToken), isEmpty);
      expect(phone.carrying(_joinToken), isEmpty);
      expect(keychain.account, {
        'account_id': 'acc_cloud',
        'account_join_token': _joinToken,
      });
      await phone.expectNativePairingSafe();
    });

    test('a link to a self-hosted server with a relay of its own drops the '
        'device token from before the update at once, so the saved relay is '
        'never paired with it', () async {
      final phone = await _phone(
        {
          'GET $_evil/v1/info': (_) =>
              _info(baseUrl: _evil, relayUrl: _evilRelay),
          'GET $_evil/v1/incidents': (_) => _json(<dynamic>[]),
        },
        isConnected: false,
        saved: {
          'device_id': 'dev_this_phone',
          'device_token': _deviceToken,
          'account_id': 'acc_home',
        },
      );

      final outcome = await phone.connect(
        serverUrl: _evil,
        adminToken: 'x',
        pinToAddress: true,
      );

      expect(outcome, isA<Connected>());
      expect(phone.prefs.getString('device_token'), isNull);
      expect(phone.carrying(_deviceToken), isEmpty);
      await phone.expectNativePairingSafe();
    });

    test('the same on an iPhone: the Keychain device item holds no token '
        'once the connect lands', () async {
      final keychain = FakeDeviceKeychain()
        ..install()
        ..seedDevice(
          deviceId: 'dev_this_phone',
          deviceToken: _deviceToken,
          accountId: 'acc_cloud',
        );
      addTearDown(keychain.remove);
      final phone = await _phone(
        {
          'GET $_evil/v1/info': (_) =>
              _info(baseUrl: _evil, relayUrl: _evilRelay),
          'GET $_evil/v1/incidents': (_) => _json(<dynamic>[]),
        },
        isConnected: false,
        useKeychain: true,
      );

      final outcome = await phone.connect(
        serverUrl: _evil,
        adminToken: 'x',
        pinToAddress: true,
      );

      expect(outcome, isA<Connected>());
      expect(keychain.device?['device_token'], isNull);
      expect(keychain.device?['device_id'], isNot('dev_this_phone'));
      await phone.expectNativePairingSafe();
    });

    test('a token that records the hosted relay connects to a self-hosted '
        'server with a relay of its own, starting fresh there', () async {
      final phone = await _phone(
        {
          'GET $_home/v1/info': (_) =>
              _info(baseUrl: _home, relayUrl: _homeRelay),
          'GET $_home/v1/incidents': (_) => _json(<dynamic>[]),
          'POST $_homeRelay/relay/v1/devices': (_) => _registered(),
        },
        isConnected: false,
        saved: {
          'device_id': 'dev_this_phone',
          'device_token': _deviceToken,
          'device_token_relay': hostedRelayUrl,
          'device_token_server': hostedServerUrl,
          'account_id': 'acc_cloud',
        },
      );

      final outcome = await phone.connect(
        serverUrl: _home,
        adminToken: _adminToken,
      );
      await phone.register(appVersion: '1.0.0');

      expect(outcome, isA<Connected>());
      expect(phone.carrying(_deviceToken), isEmpty);
      expect(phone.prefs.getString('device_token'), 'dv_from_this_relay');
      expect(phone.prefs.getString('device_token_relay'), _homeRelay);
      await phone.expectNativePairingSafe();
    });
  });

  group('Settings > Edit server form', () {
    test('on a hosted server is not filled with the device token', () async {
      final phone = await _phone(const {}, saved: _onCloud);
      final settings = phone.settings();
      addTearDown(settings.close);

      await settings.load();

      expect(settings.state.isConnected, isTrue);
      expect(settings.state.adminToken ?? '', isEmpty);
      expect('${settings.state}', isNot(contains(_deviceToken)));
    });

    test('after a connect to a hosted server is not filled with the new '
        'device token', () async {
      final phone = await _phone(
        {
          'GET $hostedServerUrl/v1/info': (_) => _info(
            baseUrl: hostedServerUrl,
            relayUrl: hostedRelayUrl,
            mode: 'hosted',
          ),
          'POST $hostedRelayUrl/relay/v1/devices': (_) => _registered(),
        },
        isConnected: false,
      );
      final settings = phone.settings();
      addTearDown(settings.close);

      final outcome = await settings.saveConnection(
        serverUrl: hostedServerUrl,
        adminToken: '',
      );

      expect(outcome, isA<Connected>());
      expect(settings.state.adminToken ?? '', isEmpty);
    });

    test('on a self-hosted server is filled with the admin token', () async {
      final phone = await _phone(const {});
      final settings = phone.settings();
      addTearDown(settings.close);

      await settings.load();

      expect(settings.state.adminToken, _adminToken);
    });
  });
}
