import 'dart:async';

import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/push/push_token_provider.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/onboarding/domain/connect/background_connect.dart';
import 'package:critalarm/features/onboarding/domain/connect/connect_intent_store.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/usecases/establish_api_session_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _GetServerInfo extends Mock implements GetServerInfoUsecase {}

class _EstablishSession extends Mock implements EstablishApiSessionUsecase {}

class _SaveConnection extends Mock implements SaveConnectionUsecase {}

/// Writes at once, as the prefs cache does, and holds the answer back
/// until the gate is completed.
class _SlowIntents extends ConnectIntentStore {
  _SlowIntents(super._prefs);

  Completer<void>? gate;

  @override
  Future<void> save(ConnectIntent intent) async {
    final written = super.save(intent);
    await gate?.future;
    await written;
  }
}

class _Tokens implements PushTokenProvider {
  @override
  PushTokenKind get kind => PushTokenKind.fcm;

  @override
  Future<String> getToken() async => 'push-token';

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();
}

const cloudUrl = 'https://api.critalarm.app';

const cloudInfo = ServerInfo(
  version: '0.9.0',
  baseUrl: cloudUrl,
  relayUrl: 'https://relay.critalarm.app',
  mode: ServerModes.hosted,
);

AppResult<ServerInfo> offline() =>
    const Failure.unexpected(message: 'no route').toFailure();

void main() {
  late SharedPreferences prefs;
  late ConnectIntentStore intents;
  late _GetServerInfo getServerInfo;
  late _EstablishSession establishSession;
  late _SaveConnection saveConnection;
  late DateTime now;
  late List<BackgroundConnectState> seen;
  late int landed;
  late int abandoned;
  late int removed;

  setUpAll(() {
    registerFallbackValue(Uri.parse(cloudUrl));
    registerFallbackValue(cloudInfo);
    registerFallbackValue(
      const ServerConnection(serverUrl: '', adminToken: ''),
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    intents = ConnectIntentStore(prefs);
    getServerInfo = _GetServerInfo();
    establishSession = _EstablishSession();
    saveConnection = _SaveConnection();
    now = DateTime.utc(2026, 10, 4, 9);
    seen = [];
    landed = 0;
    abandoned = 0;
    removed = 0;

    when(() => getServerInfo(any())).thenAnswer(
      (_) async => cloudInfo.toSuccess(),
    );
    when(
      () => establishSession(
        any(),
        any(),
        pushToken: any(named: 'pushToken'),
      ),
    ).thenAnswer(
      (_) async => ApiSession(
        baseUri: Uri.parse(cloudUrl),
        relayUri: Uri.parse('https://relay.critalarm.app'),
        mode: ServerMode.hosted,
        managementCredential: 'dv_minted',
      ),
    );
    when(() => saveConnection(any())).thenAnswer((_) async => unit.toSuccess());
  });

  BackgroundConnect build({SharedPreferences? on, ConnectIntentStore? store}) {
    final connect = BackgroundConnect(
      intents: store ?? (on == null ? intents : ConnectIntentStore(on)),
      getServerInfo: getServerInfo,
      establishSession: establishSession,
      saveConnection: saveConnection,
      tokens: _Tokens(),
      onConnected: () async => landed++,
      onAbandoned: () async => abandoned++,
      removeConnection: () async => removed++,
      clock: () => now,
    );
    connect.stream.listen(seen.add);
    addTearDown(connect.dispose);
    return connect;
  }

  List<BackgroundConnectStatus> statuses() =>
      seen.map((s) => s.status).toList();

  test('starts idle, with nothing pending', () {
    final connect = build();
    expect(connect.state.status, BackgroundConnectStatus.idle);
    expect(connect.state.isPending, isFalse);
    expect(connect.hasTimer, isFalse);
  });

  test('success on the first try saves the connection', () async {
    final connect = build();

    await connect.start(cloudUrl);
    // Start answers as soon as the intent is on disk. The connect itself
    // is still to come.
    expect(connect.state.status, BackgroundConnectStatus.connecting);
    expect(connect.state.isPending, isTrue);
    await connect.settled;

    expect(statuses(), [
      BackgroundConnectStatus.connecting,
      BackgroundConnectStatus.connected,
    ]);
    expect(connect.state.isConnected, isTrue);
    expect(connect.state.serverUrl, cloudUrl);
    verify(
      () => saveConnection(
        const ServerConnection(serverUrl: cloudUrl, adminToken: 'dv_minted'),
      ),
    ).called(1);
    verify(
      () => establishSession(cloudInfo, '', pushToken: 'push-token'),
    ).called(1);
    expect(landed, 1);
  });

  test('the intent is cleared on success and the timer stops', () async {
    final connect = build();

    await connect.start(cloudUrl);
    expect(intents.read()?.serverUrl, cloudUrl);
    expect(connect.hasTimer, isTrue);
    await connect.settled;

    expect(intents.read(), isNull);
    expect(connect.hasTimer, isFalse);
  });

  test('offline keeps the intent and waits for the network', () async {
    when(() => getServerInfo(any())).thenAnswer((_) async => offline());
    final connect = build();

    await connect.start(cloudUrl);
    await connect.settled;

    expect(connect.state.status, BackgroundConnectStatus.waitingForNetwork);
    expect(connect.state.isPending, isTrue);
    final intent = intents.read()!;
    expect(intent.attempts, 1);
    expect(
      intent.nextAttemptAtMs,
      now.add(BackgroundConnect.baseBackoff).millisecondsSinceEpoch,
    );
    verifyNever(() => saveConnection(any()));
    expect(landed, 0);
  });

  test('offline, then success on a timer tick', () async {
    var online = false;
    when(() => getServerInfo(any())).thenAnswer(
      (_) async => online ? cloudInfo.toSuccess() : offline(),
    );
    // A real timer with a short interval. The retry time still comes from
    // the fake clock.
    final connect = BackgroundConnect(
      intents: intents,
      getServerInfo: getServerInfo,
      establishSession: establishSession,
      saveConnection: saveConnection,
      tokens: _Tokens(),
      clock: () => now,
      tickInterval: const Duration(milliseconds: 5),
    );
    connect.stream.listen(seen.add);
    addTearDown(connect.dispose);

    await connect.start(cloudUrl);
    await connect.settled;
    expect(connect.state.status, BackgroundConnectStatus.waitingForNetwork);

    // Ticks pass, but the retry time has not come: nothing is asked.
    clearInteractions(getServerInfo);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    verifyNever(() => getServerInfo(any()));

    // The network is back and the retry time passes. Nobody taps anything.
    online = true;
    now = now.add(BackgroundConnect.baseBackoff);
    await connect.stream
        .firstWhere((s) => s.isConnected)
        .timeout(const Duration(seconds: 2));

    expect(intents.read(), isNull);
    expect(connect.hasTimer, isFalse);
    expect(statuses(), [
      BackgroundConnectStatus.connecting,
      BackgroundConnectStatus.waitingForNetwork,
      BackgroundConnectStatus.connected,
    ]);
  });

  test('a tick before the retry time does nothing', () async {
    when(() => getServerInfo(any())).thenAnswer((_) async => offline());
    final connect = build();
    await connect.start(cloudUrl);
    await connect.settled;
    clearInteractions(getServerInfo);

    now = now.add(const Duration(seconds: 1));
    await connect.tick();
    verifyNever(() => getServerInfo(any()));

    now = now.add(BackgroundConnect.baseBackoff);
    await connect.tick();
    verify(() => getServerInfo(any())).called(1);
  });

  test('each failed try waits twice as long, up to the cap', () async {
    when(() => getServerInfo(any())).thenAnswer((_) async => offline());
    final connect = build();
    await connect.start(cloudUrl);
    await connect.settled;

    final waits = <int>[];
    for (var i = 0; i < 10; i++) {
      final intent = intents.read()!;
      waits.add(intent.nextAttemptAtMs - now.millisecondsSinceEpoch);
      now = DateTime.fromMillisecondsSinceEpoch(
        intent.nextAttemptAtMs,
        isUtc: true,
      );
      await connect.tick();
    }

    expect(waits.take(4), [2000, 4000, 8000, 16000]);
    expect(waits.last, BackgroundConnect.maxBackoff.inMilliseconds);
    // It never gives up on a network that is only away.
    expect(connect.state.status, BackgroundConnectStatus.waitingForNetwork);
    expect(intents.read(), isNotNull);
  });

  test('retries on resume without waiting for the retry time', () async {
    var online = false;
    when(() => getServerInfo(any())).thenAnswer(
      (_) async => online ? cloudInfo.toSuccess() : offline(),
    );
    final connect = build();
    await connect.start(cloudUrl);
    await connect.settled;
    expect(connect.state.status, BackgroundConnectStatus.waitingForNetwork);

    online = true;
    await connect.retryNow();

    expect(connect.state.status, BackgroundConnectStatus.connected);
    expect(intents.read(), isNull);
    expect(landed, 1);
  });

  test('resume with nothing pending makes no request', () async {
    final connect = build();

    await connect.retryNow();

    verifyNever(() => getServerInfo(any()));
    expect(connect.state.status, BackgroundConnectStatus.idle);
  });

  test('retries on launch from a saved intent', () async {
    await intents.save(const ConnectIntent(serverUrl: cloudUrl, attempts: 4));
    // A new app run: a new object over the same prefs.
    final connect = build(on: prefs);

    await connect.resumeSaved();

    expect(statuses(), [
      BackgroundConnectStatus.connecting,
      BackgroundConnectStatus.connected,
    ]);
    verify(() => getServerInfo(Uri.parse(cloudUrl))).called(1);
    expect(intents.read(), isNull);
  });

  test('launch with no saved intent stays idle and starts no timer', () async {
    final connect = build();

    await connect.resumeSaved();

    expect(connect.state.status, BackgroundConnectStatus.idle);
    expect(connect.hasTimer, isFalse);
    verifyNever(() => getServerInfo(any()));
  });

  test(
    'a version that is too old fails, clears the intent and does not retry',
    () async {
      when(() => getServerInfo(any())).thenAnswer(
        (_) async => cloudInfo.copyWith(version: '1.4.0').toSuccess(),
      );
      final connect = build();

      await connect.start(cloudUrl);
      await connect.settled;

      expect(connect.state.status, BackgroundConnectStatus.failed);
      expect(
        connect.state.failure,
        BackgroundConnectFailure.versionUnsupported,
      );
      expect(connect.state.serverVersion, '1.4.0');
      expect(intents.read(), isNull);
      expect(connect.hasTimer, isFalse);

      clearInteractions(getServerInfo);
      now = now.add(const Duration(hours: 1));
      await connect.tick();
      await connect.retryNow();
      verifyNever(() => getServerInfo(any()));
      verifyNever(() => saveConnection(any()));
    },
  );

  test('a server that answers an error fails and clears the intent', () async {
    when(() => getServerInfo(any())).thenAnswer(
      (_) async => const Failure.api(statusCode: 404).toFailure(),
    );
    final connect = build();

    await connect.start(cloudUrl);
    await connect.settled;

    expect(connect.state.failure, BackgroundConnectFailure.refused);
    expect(intents.read(), isNull);
  });

  test('a server that is briefly down is tried again', () async {
    when(() => getServerInfo(any())).thenAnswer(
      (_) async => const Failure.api(statusCode: 503).toFailure(),
    );
    final connect = build();

    await connect.start(cloudUrl);
    await connect.settled;

    // The network is fine, so the line keeps saying "connecting".
    expect(connect.state.status, BackgroundConnectStatus.connecting);
    expect(intents.read()!.attempts, 1);
  });

  test(
    'a registration the relay refuses fails and clears the intent',
    () async {
      when(
        () => establishSession(
          any(),
          any(),
          pushToken: any(named: 'pushToken'),
        ),
      ).thenThrow(const ApiException(statusCode: 403, message: 'forbidden'));
      final connect = build();

      await connect.start(cloudUrl);
      await connect.settled;

      expect(connect.state.failure, BackgroundConnectFailure.refused);
      expect(intents.read(), isNull);
    },
  );

  test(
    'a server that wants an admin token fails back to the connect step',
    () async {
      when(() => getServerInfo(any())).thenAnswer(
        (_) async =>
            cloudInfo.copyWith(mode: ServerModes.selfhosted).toSuccess(),
      );
      final connect = build();

      await connect.start(cloudUrl);
      await connect.settled;

      expect(connect.state.failure, BackgroundConnectFailure.needsAdminToken);
      verifyNever(
        () => establishSession(
          any(),
          any(),
          pushToken: any(named: 'pushToken'),
        ),
      );
    },
  );

  test(
    'a second Continue tap while one is pending starts no second run',
    () async {
      final answer = Completer<AppResult<ServerInfo>>();
      when(() => getServerInfo(any())).thenAnswer((_) => answer.future);
      final connect = build();

      await connect.start(cloudUrl);
      await connect.start(cloudUrl);
      answer.complete(cloudInfo.toSuccess());
      await connect.settled;

      verify(() => getServerInfo(any())).called(1);
      verify(() => saveConnection(any())).called(1);
      expect(statuses(), [
        BackgroundConnectStatus.connecting,
        BackgroundConnectStatus.connected,
      ]);
    },
  );

  test(
    'a second tap while waiting for the network starts no second run',
    () async {
      when(() => getServerInfo(any())).thenAnswer((_) async => offline());
      final connect = build();
      await connect.start(cloudUrl);
      await connect.settled;
      clearInteractions(getServerInfo);

      await connect.start(cloudUrl);
      await connect.settled;

      verifyNever(() => getServerInfo(any()));
      expect(intents.read()!.attempts, 1);
    },
  );

  test('cancel clears the intent and a late answer saves nothing', () async {
    final answer = Completer<AppResult<ServerInfo>>();
    when(() => getServerInfo(any())).thenAnswer((_) => answer.future);
    final connect = build();
    await connect.start(cloudUrl);

    await connect.cancel();
    answer.complete(cloudInfo.toSuccess());
    await connect.settled;

    expect(connect.state.status, BackgroundConnectStatus.idle);
    expect(intents.read(), isNull);
    expect(connect.hasTimer, isFalse);
    verifyNever(() => saveConnection(any()));
    expect(landed, 0);
  });

  test('a new Continue after a failure starts again', () async {
    when(() => getServerInfo(any())).thenAnswer(
      (_) async => const Failure.api(statusCode: 404).toFailure(),
    );
    final connect = build();
    await connect.start(cloudUrl);
    await connect.settled;
    expect(connect.state.isFailed, isTrue);

    when(() => getServerInfo(any())).thenAnswer(
      (_) async => cloudInfo.toSuccess(),
    );
    await connect.start(cloudUrl);
    await connect.settled;

    expect(connect.state.isConnected, isTrue);
  });

  group('device cap', () {
    test('a 429 from the registration is the device cap: it fails with its '
        'own reason, clears the intent and is not retried', () async {
      when(
        () => establishSession(
          any(),
          any(),
          pushToken: any(named: 'pushToken'),
        ),
      ).thenThrow(
        const ApiException(statusCode: 429, message: 'cap', cap: 'devices'),
      );
      final connect = build();

      await connect.start(cloudUrl);
      await connect.settled;

      expect(connect.state.status, BackgroundConnectStatus.failed);
      expect(connect.state.failure, BackgroundConnectFailure.deviceCap);
      expect(intents.read(), isNull);
      expect(connect.hasTimer, isFalse);

      clearInteractions(establishSession);
      now = now.add(const Duration(hours: 1));
      await connect.tick();
      await connect.retryNow();
      verifyNever(
        () => establishSession(
          any(),
          any(),
          pushToken: any(named: 'pushToken'),
        ),
      );
    });

    test('a 429 from /v1/info is the rate limit and is tried again', () async {
      when(() => getServerInfo(any())).thenAnswer(
        (_) async => const Failure.api(statusCode: 429).toFailure(),
      );
      final connect = build();

      await connect.start(cloudUrl);
      await connect.settled;

      expect(connect.state.status, BackgroundConnectStatus.connecting);
      expect(intents.read()!.attempts, 1);
    });

    test(
      'a registration the relay is briefly too busy for is tried again',
      () async {
        when(
          () => establishSession(
            any(),
            any(),
            pushToken: any(named: 'pushToken'),
          ),
        ).thenThrow(const ApiException(statusCode: 503, message: 'down'));
        final connect = build();

        await connect.start(cloudUrl);
        await connect.settled;

        expect(connect.state.status, BackgroundConnectStatus.connecting);
        expect(intents.read()!.attempts, 1);
      },
    );
  });

  group('the connect step stops counting as done', () {
    test('when the connect gives up', () async {
      when(() => getServerInfo(any())).thenAnswer(
        (_) async => const Failure.api(statusCode: 404).toFailure(),
      );
      final connect = build();

      await connect.start(cloudUrl);
      await connect.settled;

      expect(abandoned, 1);
    });

    test('when a pending connect is cancelled', () async {
      when(() => getServerInfo(any())).thenAnswer((_) async => offline());
      final connect = build();
      await connect.start(cloudUrl);
      await connect.settled;

      await connect.cancel();

      expect(abandoned, 1);
    });

    test(
      'not when it lands, and not when there was nothing to cancel',
      () async {
        final connect = build();
        await connect.cancel();
        await connect.start(cloudUrl);
        await connect.settled;
        // Disconnecting later cancels with no intent left.
        await connect.cancel();

        expect(connect.state.status, BackgroundConnectStatus.idle);
        expect(abandoned, 0);
      },
    );
  });

  group('cancel races', () {
    test('cancelled while the connection is being saved: the saved '
        'connection is taken back and nothing is reported', () async {
      final saving = Completer<AppResult<Unit>>();
      when(() => saveConnection(any())).thenAnswer((_) => saving.future);
      final connect = build();
      await connect.start(cloudUrl);
      await untilCalled(() => saveConnection(any()));

      // The user disconnects: cancel comes first, then the clear.
      await connect.cancel();
      saving.complete(unit.toSuccess());
      await connect.settled;

      expect(removed, 1);
      expect(connect.state.status, BackgroundConnectStatus.idle);
      expect(landed, 0);
      expect(intents.read(), isNull);
    });

    test(
      'cancelled while the save fails: there is nothing to take back',
      () async {
        final saving = Completer<AppResult<Unit>>();
        when(() => saveConnection(any())).thenAnswer((_) => saving.future);
        final connect = build();
        await connect.start(cloudUrl);
        await untilCalled(() => saveConnection(any()));

        await connect.cancel();
        saving.complete(const Failure.unexpected(message: 'disk').toFailure());
        await connect.settled;

        expect(removed, 0);
        expect(connect.state.status, BackgroundConnectStatus.idle);
      },
    );

    test('cancelled while the retry time is being written: it stays idle, '
        'with no intent and no timer', () async {
      when(() => getServerInfo(any())).thenAnswer((_) async => offline());
      final slow = _SlowIntents(prefs);
      final connect = build(store: slow);
      await connect.start(cloudUrl);
      await connect.settled;
      expect(connect.state.status, BackgroundConnectStatus.waitingForNetwork);

      // The next try fails too, and its write of the retry time hangs.
      slow.gate = Completer<void>();
      final retry = connect.retryNow();
      await pumpEventQueue();
      await connect.cancel();
      slow.gate!.complete();
      await retry;
      await connect.settled;

      expect(connect.state.status, BackgroundConnectStatus.idle);
      expect(connect.state.isPending, isFalse);
      expect(intents.read(), isNull);
      expect(connect.hasTimer, isFalse);
    });

    test('a new Continue while a failure is being written is not overwritten '
        'by it', () async {
      final answer = Completer<AppResult<ServerInfo>>();
      var calls = 0;
      when(() => getServerInfo(any())).thenAnswer((_) {
        calls++;
        return calls == 1 ? answer.future : Future.value(cloudInfo.toSuccess());
      });
      final connect = build();
      await connect.start(cloudUrl);
      await connect.cancel();
      await connect.start(cloudUrl);
      answer.complete(const Failure.api(statusCode: 404).toFailure());
      await connect.settled;

      expect(connect.state.status, BackgroundConnectStatus.connected);
      expect(connect.state.failure, isNull);
    });
  });

  group('a failure the user has left behind', () {
    test('dismissFailure puts it back to idle', () async {
      when(() => getServerInfo(any())).thenAnswer(
        (_) async => const Failure.api(statusCode: 404).toFailure(),
      );
      final connect = build();
      await connect.start(cloudUrl);
      await connect.settled;
      expect(connect.state.isFailed, isTrue);

      connect.dismissFailure();

      expect(connect.state, const BackgroundConnectState());
    });

    test('dismissFailure leaves a pending connect alone', () async {
      when(() => getServerInfo(any())).thenAnswer((_) async => offline());
      final connect = build();
      await connect.start(cloudUrl);
      await connect.settled;

      connect.dismissFailure();

      expect(connect.state.status, BackgroundConnectStatus.waitingForNetwork);
      expect(intents.read(), isNotNull);
    });
  });
}
