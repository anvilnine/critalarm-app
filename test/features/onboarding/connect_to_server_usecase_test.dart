import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/push/device_token_relay.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/usecases/connect_to_server_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/establish_api_session_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetInfo extends Mock implements GetServerInfoUsecase {}

class _MockEstablish extends Mock implements EstablishApiSessionUsecase {}

class _MockSave extends Mock implements SaveConnectionUsecase {}

const _info = ServerInfo(
  version: '0.1.0',
  baseUrl: 'https://alarm.example.com',
  relayUrl: 'https://relay.example.com',
);

void main() {
  late _MockGetInfo getInfo;
  late _MockEstablish establish;
  late _MockSave save;
  late List<String> calls;
  late ConnectToServerUsecase connect;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://x.example.com'));
    registerFallbackValue(_info);
    registerFallbackValue(
      const ServerConnection(serverUrl: '', adminToken: ''),
    );
  });

  setUp(() {
    calls = [];
    getInfo = _MockGetInfo();
    establish = _MockEstablish();
    save = _MockSave();
    when(() => getInfo(any())).thenAnswer((_) async {
      calls.add('info');
      return _info.toSuccess();
    });
    when(() => establish(any(), any())).thenAnswer((invocation) async {
      calls.add('session');
      return ApiSession(
        baseUri: Uri.parse(_info.baseUrl),
        relayUri: Uri.parse(_info.relayUrl),
        mode: ServerMode.selfhosted,
        managementCredential: invocation.positionalArguments[1] as String,
      );
    });
    when(() => save(any())).thenAnswer((_) async {
      calls.add('save');
      return unit.toSuccess();
    });
    connect = ConnectToServerUsecase(
      getInfo,
      establish,
      save,
      cancelPendingConnect: () async => calls.add('cancel'),
    );
  });

  test('drops a pending cloud connect first, then asks, then saves', () async {
    final outcome = await connect(
      serverUrl: ' https://alarm.example.com ',
      adminToken: ' tk_one ',
    );
    expect(outcome, isA<Connected>());
    expect(calls, ['cancel', 'info', 'session', 'save']);
    final saved =
        verify(() => save(captureAny())).captured.single as ServerConnection;
    expect(saved.adminToken, 'tk_one');
    expect(saved.serverUrl, 'https://alarm.example.com');
  });

  test(
    'a server that does not answer is unreachable and saves nothing',
    () async {
      when(
        () => getInfo(any()),
      ).thenAnswer((_) async => const Failure.unexpected().toFailure());
      final outcome = await connect(
        serverUrl: 'https://alarm.example.com',
        adminToken: 'tk_one',
      );
      expect(outcome, isA<ServerUnreachable>());
      verifyNever(() => save(any()));
    },
  );

  test('a version this app does not speak is refused', () async {
    when(() => getInfo(any())).thenAnswer(
      (_) async => _info.copyWith(version: '99.0.0').toSuccess(),
    );
    final outcome = await connect(
      serverUrl: 'https://alarm.example.com',
      adminToken: 'tk_one',
    );
    expect(outcome, isA<ServerIncompatible>());
    verifyNever(() => establish(any(), any()));
  });

  test('a self-hosted server with no token asks for one', () async {
    final outcome = await connect(
      serverUrl: 'https://alarm.example.com',
      adminToken: '  ',
    );
    expect(outcome, isA<AdminTokenMissing>());
    verifyNever(() => save(any()));
  });

  test('a connection that cannot be saved says so', () async {
    when(
      () => save(any()),
    ).thenAnswer((_) async => const Failure.database().toFailure());
    final outcome = await connect(
      serverUrl: 'https://alarm.example.com',
      adminToken: 'tk_one',
    );
    expect(outcome, isA<ConnectionNotSaved>());
  });

  test('a throw on the way is a transport error', () async {
    when(() => establish(any(), any())).thenThrow(Exception('socket'));
    final outcome = await connect(
      serverUrl: 'https://alarm.example.com',
      adminToken: 'tk_one',
    );
    expect(outcome, isA<ConnectTransportError>());
  });

  group('the address the server reports', () {
    Future<ConnectOutcome> run({
      required String asked,
      required String reported,
      bool pin = false,
    }) {
      when(() => getInfo(any())).thenAnswer(
        (_) async => _info.copyWith(baseUrl: reported).toSuccess(),
      );
      return connect(serverUrl: asked, adminToken: 'tk_one', pinToAddress: pin);
    }

    test('a link that is pinned refuses another host, and connects '
        'nothing', () async {
      final outcome = await run(
        asked: 'https://alarm.example.com',
        reported: 'https://other.example.com',
        pin: true,
      );
      expect(outcome, isA<ServerAddressDiffers>());
      expect((outcome as ServerAddressDiffers).host, 'other.example.com');
      verifyNever(() => establish(any(), any()));
      verifyNever(() => save(any()));
    });

    test('a link that is pinned refuses another port', () async {
      final outcome = await run(
        asked: 'https://alarm.example.com',
        reported: 'https://alarm.example.com:8443',
        pin: true,
      );
      expect(outcome, isA<ServerAddressDiffers>());
      expect((outcome as ServerAddressDiffers).host, 'alarm.example.com:8443');
      verifyNever(() => save(any()));
    });

    test('the same address with a trailing slash, other letter case or the '
        'usual port written out is not a mismatch', () async {
      for (final reported in [
        'https://alarm.example.com/',
        'https://ALARM.example.com',
        'https://alarm.example.com:443',
      ]) {
        final outcome = await run(
          asked: 'https://alarm.example.com',
          reported: reported,
          pin: true,
        );
        expect(outcome, isA<Connected>(), reason: reported);
      }
      for (final reported in [
        'https://alarm.example.com/one',
        'https://alarm.example.com/one/',
      ]) {
        final outcome = await run(
          asked: 'https://alarm.example.com/one',
          reported: reported,
          pin: true,
        );
        expect(outcome, isA<Connected>(), reason: reported);
      }
    });

    test('a link that is pinned refuses another base path, and connects '
        'nothing', () async {
      final outcome = await run(
        asked: 'https://alarm.example.com/one',
        reported: 'https://alarm.example.com/two',
        pin: true,
      );
      expect(outcome, isA<ServerAddressDiffers>());
      expect(
        (outcome as ServerAddressDiffers).host,
        'https://alarm.example.com/two',
      );
      verifyNever(() => establish(any(), any()));
      verifyNever(() => save(any()));
    });

    test('typed in setup, another base path is followed and saved', () async {
      final outcome = await run(
        asked: 'https://alarm.example.com/one',
        reported: 'https://alarm.example.com/two',
      );
      expect(outcome, isA<Connected>());
      final saved =
          verify(() => save(captureAny())).captured.single as ServerConnection;
      expect(saved.serverUrl, 'https://alarm.example.com/two');
    });

    test('a link that is pinned refuses anything looser than the address '
        'it showed', () async {
      for (final (asked, reported) in [
        // A path the link did not carry, and a path it did that is gone.
        ('https://alarm.example.com', 'https://alarm.example.com/api/v1'),
        ('https://alarm.example.com/one', 'https://alarm.example.com'),
        // Path letters are not host letters: case counts.
        ('https://alarm.example.com/one', 'https://alarm.example.com/One'),
        ('https://alarm.example.com/one', 'https://alarm.example.com/one//'),
        ('https://alarm.example.com/one', 'https://alarm.example.com/one/x'),
        // Another scheme, also upwards.
        ('http://192.168.1.5:8080', 'https://192.168.1.5:8080'),
        ('https://alarm.example.com', 'https://alarm.example.com?x=1'),
        ('https://alarm.example.com', 'https://alarm.example.com#top'),
        ('https://alarm.example.com', 'https://user@alarm.example.com'),
      ]) {
        final outcome = await run(asked: asked, reported: reported, pin: true);
        expect(outcome, isA<ServerAddressDiffers>(), reason: reported);
        verifyNever(() => save(any()));
      }
    });

    test('a connect link never ends as http when it asked for https', () async {
      final outcome = await run(
        asked: 'https://alarm.example.com',
        reported: 'http://alarm.example.com',
        pin: true,
      );
      expect(outcome, isA<ServerDowngrade>());
      verifyNever(() => establish(any(), any()));
      verifyNever(() => save(any()));
    });

    test('KNOWN BEHAVIOUR AWAITING AN OWNER DECISION: setup follows a '
        'server that reports http for an https address', () async {
      final outcome = await run(
        asked: 'https://alarm.example.com',
        reported: 'http://alarm.example.com',
      );
      expect(outcome, isA<Connected>());
      final saved =
          verify(() => save(captureAny())).captured.single as ServerConnection;
      expect(saved.serverUrl, 'http://alarm.example.com');
    });

    test('an http address may stay http', () async {
      final outcome = await run(
        asked: 'http://192.168.1.5:8080',
        reported: 'http://192.168.1.5:8080',
        pin: true,
      );
      expect(outcome, isA<Connected>());
    });

    test('typed in setup, another host is still accepted as before and '
        'what the server reports is what is saved', () async {
      final outcome = await run(
        asked: 'https://alarm.example.com',
        reported: 'https://other.example.com',
      );
      expect(outcome, isA<Connected>());
      final saved =
          verify(() => save(captureAny())).captured.single as ServerConnection;
      expect(saved.serverUrl, 'https://other.example.com');
    });
  });

  group('connecting to a different server', () {
    ConnectToServerUsecase withSaved(String? saved) => ConnectToServerUsecase(
      getInfo,
      establish,
      save,
      cancelPendingConnect: () async => calls.add('cancel'),
      readSavedServerUrl: () async => saved,
      forgetServerData: () async => calls.add('forget'),
    );

    test('clears what belongs to the old server, after the new one is '
        'saved and before the caller loads anything', () async {
      final outcome = await withSaved('https://old.example.com')(
        serverUrl: 'https://alarm.example.com',
        adminToken: 'tk_one',
      );
      expect(outcome, isA<Connected>());
      expect(calls, ['cancel', 'info', 'session', 'save', 'forget']);
    });

    test('connecting again to the same server clears nothing, whatever '
        'the slash or the letter case', () async {
      for (final saved in [
        'https://alarm.example.com',
        'https://alarm.example.com/',
        ' https://alarm.example.com// ',
      ]) {
        calls.clear();
        final outcome = await withSaved(saved)(
          serverUrl: 'https://alarm.example.com',
          adminToken: 'tk_one',
        );
        expect(outcome, isA<Connected>());
        expect(calls, isNot(contains('forget')), reason: saved);
      }
    });

    test('a phone with no saved server clears, because what it holds has '
        'no known owner', () async {
      await withSaved(null)(
        serverUrl: 'https://alarm.example.com',
        adminToken: 'tk_one',
      );
      expect(calls, contains('forget'));
    });

    test('a connect that did not land clears nothing', () async {
      when(() => save(any())).thenAnswer(
        (_) async => const Failure.database().toFailure(),
      );
      final failedSave = await withSaved('https://old.example.com')(
        serverUrl: 'https://alarm.example.com',
        adminToken: 'tk_one',
      );
      expect(failedSave, isA<ConnectionNotSaved>());

      when(() => getInfo(any())).thenAnswer(
        (_) async =>
            _info.copyWith(baseUrl: 'http://alarm.example.com').toSuccess(),
      );
      final downgrade = await withSaved('https://old.example.com')(
        serverUrl: 'https://alarm.example.com',
        adminToken: 'tk_one',
        pinToAddress: true,
      );
      expect(downgrade, isA<ServerDowngrade>());
      expect(calls, isNot(contains('forget')));
    });
  });

  group('the whole answer is checked', () {
    Future<ConnectOutcome> run(ServerInfo info, {bool pin = false}) {
      when(() => getInfo(any())).thenAnswer((_) async => info.toSuccess());
      return connect(
        serverUrl: 'https://alarm.example.com',
        adminToken: 'tk_one',
        pinToAddress: pin,
      );
    }

    final bad = <String, ServerInfo>{
      'a mode this app does not know': _info.copyWith(mode: 'cluster'),
      'a mode in other letter case': _info.copyWith(mode: 'Hosted'),
      'an empty mode': _info.copyWith(mode: ''),
      'no relay address': _info.copyWith(relayUrl: ''),
      'a relay address that is not http': _info.copyWith(
        relayUrl: 'ftp://relay.example.com',
      ),
      'a relay address with no host': _info.copyWith(relayUrl: 'https://'),
      'a relay address with a user name': _info.copyWith(
        relayUrl: 'https://relay.example.com@other.example.net',
      ),
      'a relay address with a query': _info.copyWith(
        relayUrl: 'https://relay.example.com?to=other',
      ),
      'a base address that is not http': _info.copyWith(
        baseUrl: 'file://alarm.example.com',
      ),
    };

    for (final MapEntry(key: name, value: info) in bad.entries) {
      for (final pin in [false, true]) {
        test('$name is refused, ${pin ? 'from a link' : 'typed'}', () async {
          final outcome = await run(info, pin: pin);
          expect(
            outcome,
            pin ? isNot(isA<Connected>()) : isA<ServerAnswerInvalid>(),
          );
          verifyNever(() => establish(any(), any()));
          verifyNever(() => save(any()));
        });
      }
    }

    test('each of the three modes is a good answer when typed', () async {
      for (final mode in ServerModes.validModes) {
        expect(await run(_info.copyWith(mode: mode)), isA<Connected>());
      }
    });
  });

  group('a link connects to a self-hosted server only', () {
    for (final mode in [ServerModes.hosted, ServerModes.relay]) {
      test('a $mode server is refused before anything is registered or '
          'saved', () async {
        when(() => getInfo(any())).thenAnswer(
          (_) async => _info.copyWith(mode: mode).toSuccess(),
        );
        final outcome = await connect(
          serverUrl: 'https://alarm.example.com',
          adminToken: 'tk_one',
          pinToAddress: true,
        );
        expect(outcome, isA<LinkServerNotSelfHosted>());
        verifyNever(() => establish(any(), any()));
        verifyNever(() => save(any()));
      });
    }

    test('a self-hosted server connects', () async {
      final outcome = await connect(
        serverUrl: 'https://alarm.example.com',
        adminToken: 'tk_one',
        pinToAddress: true,
      );
      expect(outcome, isA<Connected>());
    });
  });

  group('the admin token is proved before anything is saved', () {
    late Future<void> Function(Uri, String) answer;

    ConnectToServerUsecase proving() => ConnectToServerUsecase(
      getInfo,
      establish,
      save,
      proveAdminToken: (baseUri, token) {
        calls.add('prove $baseUri $token');
        return answer(baseUri, token);
      },
    );

    setUp(() => answer = (_, _) async {});

    test('one read on the address the server reported, with the trimmed '
        'token, between the answer and the session', () async {
      final outcome = await proving()(
        serverUrl: 'https://alarm.example.com',
        adminToken: ' tk_one ',
      );
      expect(outcome, isA<Connected>());
      expect(calls, [
        'info',
        'prove https://alarm.example.com tk_one',
        'session',
        'save',
      ]);
    });

    for (final status in [401, 403]) {
      test('a $status is a wrong token, and nothing is saved', () async {
        answer = (_, _) async =>
            throw ApiException(statusCode: status, message: 'no');
        for (final pin in [false, true]) {
          final outcome = await proving()(
            serverUrl: 'https://alarm.example.com',
            adminToken: 'tk_one',
            pinToAddress: pin,
          );
          expect(outcome, isA<AdminTokenRefused>());
        }
        verifyNever(() => establish(any(), any()));
        verifyNever(() => save(any()));
      });
    }

    test('any other status is a server that could not be asked, and what '
        'the server wrote is dropped', () async {
      answer = (_, _) async => throw const ApiException(
        statusCode: 503,
        message: 'down for tk_one',
      );
      final outcome = await proving()(
        serverUrl: 'https://alarm.example.com',
        adminToken: 'tk_one',
      );
      expect(outcome, isA<ServerUnreachable>());
      expect(
        (outcome as ServerUnreachable).failure.toString(),
        isNot(contains('tk_one')),
      );
      verifyNever(() => establish(any(), any()));
      verifyNever(() => save(any()));
    });

    test('a throw is a transport error, as before', () async {
      answer = (_, _) async => throw Exception('socket');
      final outcome = await proving()(
        serverUrl: 'https://alarm.example.com',
        adminToken: 'tk_one',
      );
      expect(outcome, isA<ConnectTransportError>());
      verifyNever(() => establish(any(), any()));
      verifyNever(() => save(any()));
    });

    test('a hosted server takes no admin token, so none is tried', () async {
      when(() => getInfo(any())).thenAnswer(
        (_) async => _info.copyWith(mode: ServerModes.hosted).toSuccess(),
      );
      final outcome = await proving()(
        serverUrl: 'https://alarm.example.com',
        adminToken: 'tk_one',
      );
      expect(outcome, isA<Connected>());
      expect(calls, ['session', 'save']);
    });

    test('a token the saved session cannot hold is a wrong token and is '
        'sent nowhere', () async {
      for (final pin in [false, true]) {
        final outcome = await proving()(
          serverUrl: 'https://alarm.example.com',
          adminToken: 'tk_one|two',
          pinToAddress: pin,
        );
        expect(outcome, isA<AdminTokenRefused>());
      }
      expect(calls, ['info', 'info']);
    });

    test('no outcome of a refused token holds the token', () async {
      answer = (_, _) async => throw const ApiException(
        statusCode: 401,
        message: 'bad token tk_s3cret',
      );
      final outcome = await proving()(
        serverUrl: 'https://alarm.example.com',
        adminToken: 'tk_s3cret',
      );
      expect(outcome, isA<AdminTokenRefused>());
      expect(outcome.toString(), isNot(contains('tk_s3cret')));
    });
  });

  group('the relay the server names', () {
    ConnectToServerUsecase trusting(DeviceTokenRelayTrust trust) =>
        ConnectToServerUsecase(
          getInfo,
          establish,
          save,
          proveAdminToken: (_, _) async => calls.add('prove'),
          readRelayTrust: (relay) async {
            calls.add('trust $relay');
            return trust;
          },
        );

    test('is asked about before the token is tried', () async {
      final outcome = await trusting(DeviceTokenRelayTrust.issuer)(
        serverUrl: 'https://alarm.example.com',
        adminToken: 'tk_one',
        pinToAddress: true,
      );
      expect(outcome, isA<Connected>());
      expect(calls, [
        'info',
        'trust https://relay.example.com',
        'prove',
        'session',
        'save',
      ]);
    });

    test('another relay than the one that issued the device token is '
        'refused, typed or from a link', () async {
      for (final pin in [false, true]) {
        final outcome = await trusting(DeviceTokenRelayTrust.otherRelay)(
          serverUrl: 'https://alarm.example.com',
          adminToken: 'tk_one',
          pinToAddress: pin,
        );
        expect(outcome, isA<RelayDiffers>());
      }
      expect(calls.where((call) => call == 'prove'), isEmpty);
      verifyNever(() => establish(any(), any()));
      verifyNever(() => save(any()));
    });

    test('a token with no known issuer refuses a link', () async {
      final outcome = await trusting(DeviceTokenRelayTrust.unknownIssuer)(
        serverUrl: 'https://alarm.example.com',
        adminToken: 'tk_one',
        pinToAddress: true,
      );
      expect(outcome, isA<RelayUnchecked>());
      verifyNever(() => establish(any(), any()));
      verifyNever(() => save(any()));
    });

    test('a token with no known issuer still connects when typed', () async {
      final outcome = await trusting(DeviceTokenRelayTrust.unknownIssuer)(
        serverUrl: 'https://alarm.example.com',
        adminToken: 'tk_one',
      );
      expect(outcome, isA<Connected>());
    });

    test('a phone with no device token connects', () async {
      final outcome = await trusting(DeviceTokenRelayTrust.noToken)(
        serverUrl: 'https://alarm.example.com',
        adminToken: 'tk_one',
        pinToAddress: true,
      );
      expect(outcome, isA<Connected>());
    });

    test('a session that refuses the relay is the same outcome', () async {
      when(
        () => establish(any(), any()),
      ).thenThrow(const DeviceTokenRelayMismatch());
      final outcome = await connect(
        serverUrl: 'https://alarm.example.com',
        adminToken: 'tk_one',
      );
      expect(outcome, isA<RelayDiffers>());
      verifyNever(() => save(any()));
    });
  });
}
