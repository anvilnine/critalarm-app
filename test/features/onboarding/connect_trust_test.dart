import 'dart:async';
import 'dart:convert';

import 'package:critalarm/core/api/http_api_client.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/storage/shared_prefs_api_session_store.dart';
import 'package:critalarm/features/onboarding/data/repositories/in_memory_server_repository.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/connect_to_server_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/establish_api_session_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/model/connect_outcome_message.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_device_keychain.dart';

/// The real use cases, the real stores and the real HTTP client, over a
/// fake network that keeps every request it is sent.

const _home = 'https://alarm.example.com';
const _homeRelay = 'https://relay.example.com';
const _other = 'https://other.example.net';
const _otherRelay = 'https://relay.other.example.net';
const _deviceToken = 'dv_issued_by_the_home_relay';
const _adminToken = 'ad_the_working_one';

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

http.Response _registered() => _json({
  'device_token': 'dv_from_this_relay',
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

final class _Phone {
  _Phone(this.prefs, this.requests, this.client, this.connect, this.register);

  final SharedPreferences prefs;
  final List<http.Request> requests;
  final HttpApiClient client;
  final ConnectToServerUsecase connect;
  final RegisterDeviceUsecase register;

  /// Everything the three stores hold: the session, the saved connection
  /// and the device identity.
  Map<String, Object?> get stores => {
    for (final key in prefs.getKeys().toList()..sort()) key: prefs.get(key),
  };

  /// Every request that carries [secret] anywhere: the address, a header or
  /// the body.
  List<http.Request> carrying(String secret) => [
    for (final request in requests)
      if (request.url.toString().contains(secret) ||
          request.headers.values.any((value) => value.contains(secret)) ||
          request.body.contains(secret))
        request,
  ];
}

/// A phone that is connected to the self-hosted server at [_home], holds a
/// device token from [_homeRelay], and has [routes] for a network.
Future<_Phone> _connectedPhone(
  Map<String, http.Response Function(http.Request request)> routes, {
  Map<String, Object> saved = const {},
  bool isConnected = true,
  bool useKeychain = false,
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
  final connections = SharedPrefsConnectionRepository(prefs);
  final connect = ConnectToServerUsecase(
    GetServerInfoUsecase(InMemoryServerRepository(client)),
    establish,
    SaveConnectionUsecase(connections),
    readSavedServerUrl: () async =>
        (await connections.getConnection()).getOrNull()?.serverUrl,
    proveAdminToken: client.checkManagementCredential,
    readRelayTrust: establish.relayTrust,
  );
  return _Phone(prefs, requests, client, connect, register);
}

void main() {
  group('a link', () {
    test('to a server that answers hosted with a relay of its own sends the '
        'device token nowhere and changes nothing saved', () async {
      final phone = await _connectedPhone({
        'GET $_other/v1/info': (_) =>
            _info(baseUrl: _other, relayUrl: _otherRelay, mode: 'hosted'),
        'POST $_otherRelay/relay/v1/devices': (_) => _registered(),
        'PATCH $_otherRelay/relay/v1/devices/dev_this_phone': (_) =>
            _refreshed('acc_x'),
        'GET $_other/v1/incidents': (_) => _json(<dynamic>[]),
      });
      final before = phone.stores;

      final outcome = await phone.connect(
        serverUrl: _other,
        adminToken: 'x',
        pinToAddress: true,
      );

      expect(outcome, isA<LinkServerNotSelfHosted>());
      expect(phone.carrying(_deviceToken), isEmpty);
      expect(
        phone.requests.map((r) => '${r.method} ${r.url}'),
        ['GET $_other/v1/info'],
      );
      expect(phone.stores, before);
    });

    test('to a self-hosted server that names a relay other than the one '
        'that issued the device token sends the token nowhere and changes '
        'nothing saved', () async {
      final phone = await _connectedPhone({
        'GET $_other/v1/info': (_) =>
            _info(baseUrl: _other, relayUrl: _otherRelay),
        'GET $_other/v1/incidents': (_) => _json(<dynamic>[]),
        'PATCH $_otherRelay/relay/v1/devices/dev_this_phone': (_) =>
            _refreshed('acc_x'),
        'PATCH $_homeRelay/relay/v1/devices/dev_this_phone': (_) =>
            _refreshed('acc_home'),
      });
      final before = phone.stores;

      final outcome = await phone.connect(
        serverUrl: _other,
        adminToken: 'x',
        pinToAddress: true,
      );

      expect(outcome, isA<RelayDiffers>());
      expect(phone.stores, before);

      // What the app does on its next launch or resume: sends the push
      // token to the relay of the saved session.
      await phone.register(appVersion: '1.0.0');
      expect(phone.carrying(_deviceToken).map((r) => r.url.origin), [
        _homeRelay,
      ]);
    });

    test('to the saved server with a wrong token ends in wrong token, and '
        'the old admin token is still the saved one', () async {
      final phone = await _connectedPhone({
        'GET $_home/v1/info': (_) =>
            _info(baseUrl: _home, relayUrl: _homeRelay),
        'GET $_home/v1/incidents': (request) =>
            request.headers['authorization'] == 'Bearer $_adminToken'
            ? _json(<dynamic>[])
            : _json({'error': 'unauthorized'}, 401),
        'GET $_home/v1/topics': (request) =>
            request.headers['authorization'] == 'Bearer $_adminToken'
            ? _json(<dynamic>[])
            : _json({'error': 'unauthorized'}, 401),
      });
      final before = phone.stores;

      final outcome = await phone.connect(
        serverUrl: _home,
        adminToken: 'ad_wrong',
        pinToAddress: true,
      );

      expect(outcome, isA<AdminTokenRefused>());
      expect(phone.stores, before);
      expect(phone.prefs.getString('admin_token'), _adminToken);
      expect(
        phone.prefs.getString('api_session'),
        endsWith('|$_adminToken'),
      );
      expect(phone.carrying(_deviceToken), isEmpty);

      // The next management call goes out with the old token and the
      // server takes it.
      phone.requests.clear();
      expect(await phone.client.getTopics(), isEmpty);
      expect(
        phone.requests.single.headers['authorization'],
        'Bearer $_adminToken',
      );
    });

    test('with a token that begins like a device token and is refused '
        'leaves the identity alone', () async {
      final phone = await _connectedPhone({
        'GET $_home/v1/info': (_) =>
            _info(baseUrl: _home, relayUrl: _homeRelay),
        'GET $_home/v1/incidents': (_) => _json({'error': 'no'}, 401),
      });
      final before = phone.stores;

      final outcome = await phone.connect(
        serverUrl: _home,
        adminToken: 'dv_not_this_phone',
        pinToAddress: true,
      );

      expect(outcome, isA<AdminTokenRefused>());
      expect(phone.stores, before);
    });

    test('with the right token connects, and the proof went to the server '
        'in the link', () async {
      final phone = await _connectedPhone({
        'GET $_home/v1/info': (_) =>
            _info(baseUrl: _home, relayUrl: _homeRelay),
        'GET $_home/v1/incidents': (_) => _json(<dynamic>[]),
      });

      final outcome = await phone.connect(
        serverUrl: _home,
        adminToken: 'ad_rotated',
        pinToAddress: true,
      );

      expect(outcome, isA<Connected>());
      expect(phone.prefs.getString('admin_token'), 'ad_rotated');
      expect(phone.carrying('ad_rotated').map((r) => '${r.method} ${r.url}'), [
        'GET $_home/v1/incidents?limit=1',
      ]);
      expect(phone.carrying(_deviceToken), isEmpty);
    });

    test('on a phone whose device token has no known issuer is refused '
        'and changes nothing', () async {
      final phone = await _connectedPhone(
        {
          'GET $_other/v1/info': (_) =>
              _info(baseUrl: _other, relayUrl: _otherRelay),
          'GET $_other/v1/incidents': (_) => _json(<dynamic>[]),
        },
        isConnected: false,
        saved: {'device_id': 'dev_this_phone', 'device_token': _deviceToken},
      );
      final before = phone.stores;

      final outcome = await phone.connect(
        serverUrl: _other,
        adminToken: 'x',
        pinToAddress: true,
      );

      expect(outcome, isA<RelayUnchecked>());
      expect(phone.stores, before);
      expect(phone.carrying(_deviceToken), isEmpty);
    });

    test('on a phone that holds nothing connects and mints nothing before '
        'it is connected', () async {
      final phone = await _connectedPhone(
        {
          'GET $_other/v1/info': (_) =>
              _info(baseUrl: _other, relayUrl: _otherRelay),
          'GET $_other/v1/incidents': (_) => _json({'error': 'no'}, 403),
        },
        isConnected: false,
      );

      final outcome = await phone.connect(
        serverUrl: _other,
        adminToken: 'ad_wrong',
        pinToAddress: true,
      );

      expect(outcome, isA<AdminTokenRefused>());
      expect(phone.stores, isEmpty);
    });
  });

  group('typed by hand', () {
    test(
      'a wrong token ends in wrong token and nothing saved changes',
      () async {
        final phone = await _connectedPhone({
          'GET $_home/v1/info': (_) =>
              _info(baseUrl: _home, relayUrl: _homeRelay),
          'GET $_home/v1/incidents': (_) => _json({'error': 'no'}, 401),
        });
        final before = phone.stores;

        final outcome = await phone.connect(
          serverUrl: _home,
          adminToken: 'ad_mistyped',
        );

        expect(outcome, isA<AdminTokenRefused>());
        expect(phone.stores, before);
      },
    );

    test('a server that cannot be asked about the token ends as a failed '
        'connect does today, and nothing saved changes', () async {
      final phone = await _connectedPhone({
        'GET $_home/v1/info': (_) =>
            _info(baseUrl: _home, relayUrl: _homeRelay),
        'GET $_home/v1/incidents': (_) => throw http.ClientException('down'),
      });
      final before = phone.stores;

      final outcome = await phone.connect(
        serverUrl: _home,
        adminToken: 'ad_any',
      );

      expect(outcome, isA<ConnectTransportError>());
      expect(phone.stores, before);
    });

    test('a hosted server on another relay is refused, the device token '
        'stays home and nothing saved changes', () async {
      final phone = await _connectedPhone({
        'GET $_other/v1/info': (_) =>
            _info(baseUrl: _other, relayUrl: _otherRelay, mode: 'hosted'),
        'POST $_otherRelay/relay/v1/devices': (_) => _registered(),
        'PATCH $_otherRelay/relay/v1/devices/dev_this_phone': (_) =>
            _refreshed('acc_x'),
      });
      final before = phone.stores;

      final outcome = await phone.connect(serverUrl: _other, adminToken: '');

      expect(outcome, isA<RelayDiffers>());
      expect(phone.carrying(_deviceToken), isEmpty);
      expect(phone.stores, before);
    });

    test('a server that says it is hosted and names the relay that issued '
        'the device token is refused: the token is the credential for one '
        'server, and nothing saved changes', () async {
      final phone = await _connectedPhone({
        'GET $_other/v1/info': (_) =>
            _info(baseUrl: _other, relayUrl: '$_homeRelay/', mode: 'hosted'),
        'PATCH $_homeRelay/relay/v1/devices/dev_this_phone': (_) =>
            _refreshed('acc_home'),
      });
      final before = phone.stores;

      final outcome = await phone.connect(serverUrl: _other, adminToken: '');

      expect(outcome, isA<RegisteredElsewhere>());
      expect(phone.carrying(_deviceToken), isEmpty);
      expect(phone.stores, before);
    });

    test('a phone with no device token connects to a hosted server, and '
        'the new token is kept with its relay and its server', () async {
      final phone = await _connectedPhone({
        'GET $_other/v1/info': (_) =>
            _info(baseUrl: _other, relayUrl: _otherRelay, mode: 'hosted'),
        'POST $_otherRelay/relay/v1/devices': (_) => _registered(),
      }, isConnected: false);

      final outcome = await phone.connect(serverUrl: _other, adminToken: '');

      expect(outcome, isA<Connected>());
      expect(phone.prefs.getString('device_token'), 'dv_from_this_relay');
      expect(phone.prefs.getString('device_token_relay'), _otherRelay);
      expect(phone.prefs.getString('device_token_server'), _other);
      expect(
        phone.prefs.getString('api_session'),
        '$_other|$_otherRelay|hosted|dv_from_this_relay',
      );
    });

    test('a phone on a hosted server connects to that server again with '
        'the token it holds', () async {
      final phone = await _connectedPhone(
        {
          'GET $_other/v1/info': (_) =>
              _info(baseUrl: _other, relayUrl: _homeRelay, mode: 'hosted'),
          'PATCH $_homeRelay/relay/v1/devices/dev_this_phone': (_) =>
              _refreshed('acc_home'),
        },
        saved: {
          'api_session': '$_other|$_homeRelay|hosted|$_deviceToken',
          'server_url': _other,
          'admin_token': _deviceToken,
        },
      );

      final outcome = await phone.connect(
        serverUrl: '$_other/',
        adminToken: '',
      );

      expect(outcome, isA<Connected>());
      expect(phone.carrying(_deviceToken).map((r) => r.url.origin), [
        _homeRelay,
      ]);
      expect(phone.prefs.getString('device_token_server'), _other);
    });

    test('a phone that moves from a hosted server to its own and back keeps '
        'its token and its account', () async {
      final phone = await _connectedPhone(
        {
          'GET $_other/v1/info': (_) =>
              _info(baseUrl: _other, relayUrl: _homeRelay, mode: 'hosted'),
          'GET $_home/v1/info': (_) =>
              _info(baseUrl: _home, relayUrl: _homeRelay),
          'GET $_home/v1/incidents': (_) => _json(<dynamic>[]),
          'PATCH $_homeRelay/relay/v1/devices/dev_this_phone': (_) =>
              _refreshed('acc_home'),
        },
        saved: {
          'api_session': '$_other|$_homeRelay|hosted|$_deviceToken',
          'server_url': _other,
          'admin_token': _deviceToken,
        },
      );
      // As an older version left it: no issuer and no server beside the
      // token.
      await phone.prefs.remove('device_token_relay');

      expect(
        await phone.connect(serverUrl: _home, adminToken: _adminToken),
        isA<Connected>(),
      );
      expect(phone.prefs.getString('device_token_server'), _other);
      expect(phone.prefs.getString('device_token_relay'), _homeRelay);
      expect(
        await phone.connect(serverUrl: _other, adminToken: ''),
        isA<Connected>(),
      );

      expect(phone.prefs.getString('device_token'), _deviceToken);
      expect(phone.prefs.getString('account_id'), 'acc_home');
      expect(
        phone.prefs.getString('api_session'),
        '$_other|$_homeRelay|hosted|$_deviceToken',
      );
    });
  });

  group('a phone that updates with a device token saved before the issuer '
      'was kept', () {
    test('keeps the token, refreshes on the saved relay and now knows the '
        'issuer', () async {
      final phone = await _connectedPhone({
        'PATCH $_homeRelay/relay/v1/devices/dev_this_phone': (_) =>
            _refreshed('acc_home'),
      });
      await phone.prefs.remove('device_token_relay');

      await phone.register(appVersion: '1.0.0');

      expect(phone.requests.single.method, 'PATCH');
      expect(
        phone.requests.single.headers['authorization'],
        'Bearer $_deviceToken',
      );
      expect(phone.prefs.getString('device_token'), _deviceToken);
      expect(phone.prefs.getString('device_id'), 'dev_this_phone');
      expect(phone.prefs.getString('device_token_relay'), _homeRelay);
    });

    test('on an iPhone, keeps the token from its Keychain item, refreshes '
        'on the saved relay and now knows the issuer', () async {
      final keychain = FakeDeviceKeychain()
        ..install()
        ..seedDevice(
          deviceId: 'dev_this_phone',
          deviceToken: _deviceToken,
          accountId: 'acc_home',
        );
      addTearDown(keychain.remove);
      final phone = await _connectedPhone(
        {
          'PATCH $_homeRelay/relay/v1/devices/dev_this_phone': (_) =>
              _refreshed('acc_home'),
        },
        useKeychain: true,
        isConnected: false,
        saved: {
          'api_session': '$_home|$_homeRelay|selfhosted|$_adminToken',
          'server_url': _home,
          'admin_token': _adminToken,
        },
      );

      await phone.register(appVersion: '1.0.0');

      expect(phone.requests.single.method, 'PATCH');
      expect(
        phone.requests.single.headers['authorization'],
        'Bearer $_deviceToken',
      );
      expect(keychain.device?['device_token'], _deviceToken);
      expect(keychain.device?['device_id'], 'dev_this_phone');
      expect(keychain.device?['device_token_relay'], _homeRelay);
    });

    test('its token still goes nowhere but the saved relay', () async {
      final phone = await _connectedPhone({
        'PATCH $_otherRelay/relay/v1/devices/dev_this_phone': (_) =>
            _refreshed('acc_x'),
      });
      await phone.prefs.remove('device_token_relay');
      final before = phone.stores;

      await expectLater(
        phone.register(appVersion: '1.0.0', relayUri: Uri.parse(_otherRelay)),
        throwsA(isA<Exception>()),
      );

      expect(phone.requests, isEmpty);
      expect(phone.stores, before);
    });
  });

  group('neither token', () {
    test('is in a log line, an outcome or its message, through every '
        'refused connect', () async {
      const linkToken = 'ad_from_the_link';
      final scenarios =
          <
            String,
            (
              Map<String, http.Response Function(http.Request request)>,
              String,
              bool,
            )
          >{
            'a link to a hosted server': (
              {
                'GET $_other/v1/info': (_) => _info(
                  baseUrl: _other,
                  relayUrl: _otherRelay,
                  mode: 'hosted',
                ),
              },
              _other,
              true,
            ),
            'a link to a server on another relay': (
              {
                'GET $_other/v1/info': (_) =>
                    _info(baseUrl: _other, relayUrl: _otherRelay),
              },
              _other,
              true,
            ),
            'a link with a token the server refuses and echoes': (
              {
                'GET $_home/v1/info': (_) =>
                    _info(baseUrl: _home, relayUrl: _homeRelay),
                'GET $_home/v1/incidents': (request) => _json({
                  'error': 'bad ${request.headers['authorization']}',
                }, 401),
              },
              _home,
              true,
            ),
            'a server that fails the proof and echoes the token': (
              {
                'GET $_home/v1/info': (_) =>
                    _info(baseUrl: _home, relayUrl: _homeRelay),
                'GET $_home/v1/incidents': (request) => _json({
                  'error': 'bad ${request.headers['authorization']}',
                }, 500),
              },
              _home,
              false,
            ),
            'a typed hosted server that would take the device token': (
              {
                'GET $_other/v1/info': (_) => _info(
                  baseUrl: _other,
                  relayUrl: _homeRelay,
                  mode: 'hosted',
                ),
              },
              _other,
              false,
            ),
            'a relay that refuses the refresh and echoes the device token': (
              {
                'GET $_home/v1/info': (_) =>
                    _info(baseUrl: _home, relayUrl: _homeRelay, mode: 'hosted'),
                'PATCH $_homeRelay/relay/v1/devices/dev_this_phone':
                    (request) => _json({
                      'error': 'bad ${request.headers['authorization']}',
                    }, 400),
              },
              _home,
              false,
            ),
          };
      for (final MapEntry(key: name, value: (routes, url, isLink))
          in scenarios.entries) {
        final printed = <String>[];
        final realDebugPrint = debugPrint;
        debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
        try {
          final phone = await _connectedPhone(routes);
          final before = phone.stores;
          final outcome = await runZoned(
            () => phone.connect(
              serverUrl: url,
              adminToken: linkToken,
              pinToAddress: isLink,
            ),
            zoneSpecification: ZoneSpecification(
              print: (_, _, _, line) => printed.add(line),
            ),
          );
          expect(outcome, isNot(isA<Connected>()), reason: name);
          expect(phone.stores, before, reason: name);
          final seen = [
            ...printed,
            '$outcome',
            if (outcome is ConnectTransportError) ...[
              '${outcome.error}',
              '${outcome.error.server}',
            ],
            if (outcome is ServerUnreachable) '${outcome.failure}',
            connectOutcomeMessage(outcome) ?? '',
          ].join('\n');
          expect(seen, isNot(contains(linkToken)), reason: name);
          expect(seen, isNot(contains(_adminToken)), reason: name);
          expect(seen, isNot(contains(_deviceToken)), reason: name);
        } finally {
          debugPrint = realDebugPrint;
        }
      }
    });
  });
}
