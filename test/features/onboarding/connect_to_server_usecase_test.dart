import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/server_info.dart';
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

    test('the same host with a path, a trailing slash or other letter '
        'case is not a mismatch', () async {
      for (final reported in [
        'https://alarm.example.com/',
        'https://alarm.example.com/api/v1',
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
    });

    test('an https address never ends as http, pinned or not', () async {
      for (final pin in [true, false]) {
        final outcome = await run(
          asked: 'https://alarm.example.com',
          reported: 'http://alarm.example.com',
          pin: pin,
        );
        expect(outcome, isA<ServerDowngrade>(), reason: 'pin=$pin');
      }
      verifyNever(() => establish(any(), any()));
      verifyNever(() => save(any()));
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
      );
      expect(downgrade, isA<ServerDowngrade>());
      expect(calls, isNot(contains('forget')));
    });
  });
}
