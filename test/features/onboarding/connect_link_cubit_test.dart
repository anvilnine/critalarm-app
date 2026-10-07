import 'dart:async';

import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/links/app_link.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/telemetry/connect_link_analytics.dart';
import 'package:critalarm/core/telemetry/telemetry_gate.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/usecases/connect_to_server_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/connect_link_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/connect_link_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

const _token = 'tk_s3cretValue';

const _info = ServerInfo(
  version: '0.1.0',
  baseUrl: 'https://alarm.example.com',
  relayUrl: 'https://relay.example.com',
);

class _MockConnect extends Mock implements ConnectToServerUsecase {}

class _MockGetConnection extends Mock implements GetConnectionUsecase {}

class _Gate extends NoopTelemetryGate {
  final events = <(String, Map<String, Object?>?)>[];

  /// `name` or `name:result`, one per event.
  List<String> get lines => [
    for (final (name, params) in events)
      params == null ? name : '$name:${params['result']}',
  ];

  @override
  Future<void> logEvent(String name, [Map<String, Object?>? parameters]) async {
    events.add((name, parameters));
  }
}

ConnectLink _link({String url = 'https://alarm.example.com'}) =>
    ConnectLink(serverUrl: Uri.parse(url), token: _token);

void main() {
  late _MockConnect connect;
  late _MockGetConnection getConnection;
  late _Gate gate;
  late List<String> printed;
  late DebugPrintCallback realDebugPrint;
  late int connectedCalls;

  ConnectLinkCubit build([ConnectLink? link]) => ConnectLinkCubit(
    link ?? _link(),
    connectToServer: connect,
    readConnection: getConnection,
    events: ConnectLinkAnalytics(gate),
    afterConnected: () async => connectedCalls++,
  );

  setUp(() {
    connect = _MockConnect();
    getConnection = _MockGetConnection();
    gate = _Gate();
    printed = [];
    connectedCalls = 0;
    realDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => printed.add(message ?? '');
    when(
      () => getConnection(any()),
    ).thenAnswer((_) async => const Failure.notFound().toFailure());
    when(
      () => connect(
        serverUrl: any(named: 'serverUrl'),
        adminToken: any(named: 'adminToken'),
      ),
    ).thenAnswer((_) async => const Connected(_info));
  });

  setUpAll(() {
    registerFallbackValue(const NoParams());
  });

  tearDown(() => debugPrint = realDebugPrint);

  /// Everything the cubit says outside itself, as one string.
  String everything(ConnectLinkCubit cubit, List<ConnectLinkState> states) => [
    ...printed,
    cubit.toString(),
    for (final s in states) ...[
      s.toString(),
      s.host,
      s.address,
      s.replacingHost ?? '',
      s.errorMessage ?? '',
    ],
    for (final (name, params) in gate.events) '$name $params',
  ].join('\n');

  group('what the sheet shows', () {
    test('the host and the full address, and a first connection', () async {
      final cubit = build(_link(url: 'https://alarm.example.com:8443/api'));
      await cubit.open();
      expect(cubit.state.host, 'alarm.example.com:8443');
      expect(cubit.state.address, 'https://alarm.example.com:8443/api');
      expect(cubit.state.isPlainHttp, isFalse);
      expect(cubit.state.replacingHost, isNull);
      await cubit.close();
    });

    test('says which server it replaces', () async {
      when(() => getConnection(any())).thenAnswer(
        (_) async => const ServerConnection(
          serverUrl: 'https://old.example.com',
          adminToken: 'tk_old',
        ).toSuccess(),
      );
      final cubit = build();
      await cubit.open();
      expect(cubit.state.replacingHost, 'old.example.com');
      expect(cubit.state.toString(), isNot(contains('tk_old')));
      await cubit.close();
    });

    test('a plain http address is marked', () async {
      final cubit = build(_link(url: 'http://192.168.1.5:8080'));
      expect(cubit.state.isPlainHttp, isTrue);
      expect(cubit.state.host, '192.168.1.5:8080');
      await cubit.close();
    });

    test('an IPv6 host keeps its brackets', () {
      expect(
        ConnectLinkCubit.hostLabel(Uri.parse('http://[::1]:8080')),
        '[::1]:8080',
      );
    });
  });

  group('connecting', () {
    test('opening connects nothing', () async {
      final cubit = build();
      await cubit.open();
      verifyNever(
        () => connect(
          serverUrl: any(named: 'serverUrl'),
          adminToken: any(named: 'adminToken'),
        ),
      );
      expect(cubit.state.phase, ConnectLinkPhase.ready);
      await cubit.close();
    });

    test('Connect calls the shared use case with the address and the '
        'token', () async {
      final cubit = build();
      await cubit.connect();
      verify(
        () =>
            connect(serverUrl: 'https://alarm.example.com', adminToken: _token),
      ).called(1);
      expect(cubit.state.phase, ConnectLinkPhase.connected);
      expect(connectedCalls, 1);
      await cubit.close();
    });

    test(
      'shows progress, then the same words the manual screen shows',
      () async {
        final answer = Completer<ConnectOutcome>();
        when(
          () => connect(
            serverUrl: any(named: 'serverUrl'),
            adminToken: any(named: 'adminToken'),
          ),
        ).thenAnswer((_) => answer.future);
        final cubit = build();
        final states = <ConnectLinkPhase>[];
        final sub = cubit.stream.listen((s) => states.add(s.phase));
        final done = cubit.connect();
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.isConnecting, isTrue);
        answer.complete(const ServerIncompatible('9.9.9'));
        await done;
        await Future<void>.delayed(Duration.zero);
        expect(states, [ConnectLinkPhase.connecting, ConnectLinkPhase.failed]);
        expect(cubit.state.errorMessage, contains('9.9.9'));
        await sub.cancel();
        await cubit.close();
      },
    );

    test('a second tap while connecting does nothing', () async {
      final answer = Completer<ConnectOutcome>();
      when(
        () => connect(
          serverUrl: any(named: 'serverUrl'),
          adminToken: any(named: 'adminToken'),
        ),
      ).thenAnswer((_) => answer.future);
      final cubit = build();
      final first = cubit.connect();
      await cubit.connect();
      answer.complete(const Connected(_info));
      await first;
      verify(
        () => connect(
          serverUrl: any(named: 'serverUrl'),
          adminToken: any(named: 'adminToken'),
        ),
      ).called(1);
      await cubit.close();
    });

    test('a failure can be tried again', () async {
      var calls = 0;
      when(
        () => connect(
          serverUrl: any(named: 'serverUrl'),
          adminToken: any(named: 'adminToken'),
        ),
      ).thenAnswer(
        (_) async => ++calls == 1
            ? const ServerUnreachable(Failure.unexpected())
            : const Connected(_info),
      );
      final cubit = build();
      await cubit.connect();
      expect(cubit.state.isFailed, isTrue);
      expect(connectedCalls, 0);
      await cubit.connect();
      expect(cubit.state.isConnected, isTrue);
      await cubit.close();
    });

    test('after it lands there is no token left to connect with', () async {
      final cubit = build();
      await cubit.connect();
      await cubit.connect();
      verify(
        () => connect(
          serverUrl: any(named: 'serverUrl'),
          adminToken: any(named: 'adminToken'),
        ),
      ).called(1);
      await cubit.close();
    });

    test('an error text that holds the token is never shown', () async {
      when(
        () => connect(
          serverUrl: any(named: 'serverUrl'),
          adminToken: any(named: 'adminToken'),
        ),
      ).thenAnswer(
        (_) async => ConnectTransportError(StateError('bad $_token')),
      );
      final cubit = build();
      await cubit.connect();
      expect(cubit.state.isFailed, isTrue);
      expect(cubit.state.errorMessage, isNotEmpty);
      expect(cubit.state.errorMessage, isNot(contains(_token)));
      await cubit.close();
    });

    test('a throw outside the use case is a failure, not a crash', () async {
      when(
        () => connect(
          serverUrl: any(named: 'serverUrl'),
          adminToken: any(named: 'adminToken'),
        ),
      ).thenThrow(StateError('boom $_token'));
      final cubit = build();
      await cubit.connect();
      expect(cubit.state.isFailed, isTrue);
      expect(cubit.state.errorMessage, isNot(contains(_token)));
      await cubit.close();
    });
  });

  group('the token', () {
    test('is in no state, log line, or analytics event, through every '
        'ending', () async {
      for (final outcome in <ConnectOutcome>[
        const Connected(_info),
        const ServerUnreachable(Failure.unexpected(message: 'refused')),
        const ServerIncompatible('9.9.9'),
        const ConnectionNotSaved(Failure.database()),
        ConnectTransportError(Exception('socket')),
        const AdminTokenMissing(_info),
      ]) {
        when(
          () => connect(
            serverUrl: any(named: 'serverUrl'),
            adminToken: any(named: 'adminToken'),
          ),
        ).thenAnswer((_) async => outcome);
        printed.clear();
        gate.events.clear();
        final cubit = build();
        final states = <ConnectLinkState>[cubit.state];
        final sub = cubit.stream.listen(states.add);
        await runZoned(
          () async {
            await cubit.open();
            await cubit.connect();
            cubit.notNow();
            await cubit.close();
          },
          zoneSpecification: ZoneSpecification(
            print: (_, _, _, line) => printed.add(line),
          ),
        );
        await sub.cancel();
        expect(
          everything(cubit, states),
          isNot(contains(_token)),
          reason: '$outcome',
        );
      }
    });

    test('is not in the state even when asked to print it', () {
      final cubit = build();
      expect('${cubit.state}', isNot(contains(_token)));
      expect('${[cubit.state]}', isNot(contains(_token)));
      expect('${{'state': cubit.state}}', isNot(contains(_token)));
      unawaited(cubit.close());
    });
  });

  group('analytics', () {
    test('opened and how it ended, with no address', () async {
      final cubit = build();
      await cubit.open();
      await cubit.connect();
      await cubit.close();
      await Future<void>.delayed(Duration.zero);
      expect(gate.lines, [
        'connect_link_opened',
        'connect_link_ended:connected',
      ]);
      expect(
        gate.events.map((e) => '${e.$1} ${e.$2}').join(),
        isNot(contains('example.com')),
      );
    });

    test('Not now', () async {
      final cubit = build();
      await cubit.open();
      cubit.notNow();
      await cubit.close();
      await Future<void>.delayed(Duration.zero);
      expect(gate.lines.last, 'connect_link_ended:not_now');
    });

    test('a failure the person leaves', () async {
      when(
        () => connect(
          serverUrl: any(named: 'serverUrl'),
          adminToken: any(named: 'adminToken'),
        ),
      ).thenAnswer((_) async => const ServerUnreachable(Failure.unexpected()));
      final cubit = build();
      await cubit.connect();
      cubit.notNow();
      await cubit.close();
      await Future<void>.delayed(Duration.zero);
      expect(gate.lines.last, 'connect_link_ended:failed');
    });

    test('an alarm that takes the screen', () async {
      final cubit = build()..interrupted();
      await cubit.close();
      await Future<void>.delayed(Duration.zero);
      expect(gate.lines.last, 'connect_link_ended:interrupted');
    });

    test('one ending is reported once', () async {
      final cubit = build()
        ..notNow()
        ..notNow();
      await cubit.close();
      await Future<void>.delayed(Duration.zero);
      expect(
        gate.events.where((e) => e.$1 == ConnectLinkEvents.ended),
        hasLength(1),
      );
    });
  });
}
