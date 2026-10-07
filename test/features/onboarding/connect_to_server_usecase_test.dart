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
}
