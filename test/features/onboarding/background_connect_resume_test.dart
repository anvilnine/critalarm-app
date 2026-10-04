import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/data/repositories/shared_prefs_connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/connect/background_connect.dart';
import 'package:critalarm/features/onboarding/domain/connect/connect_intent_store.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/usecases/clear_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/complete_onboarding_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/establish_api_session_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/flow/connect_gate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/onboarding_flow_fakes.dart';

class _GetServerInfo extends Mock implements GetServerInfoUsecase {}

class _EstablishSession extends Mock implements EstablishApiSessionUsecase {}

class _SaveConnection extends Mock implements SaveConnectionUsecase {}

const cloudUrl = 'https://api.critalarm.app';

const cloudInfo = ServerInfo(
  version: '0.9.0',
  baseUrl: cloudUrl,
  relayUrl: 'https://relay.critalarm.app',
  mode: ServerModes.hosted,
);

/// What the app does around a kill: the same prefs and the same saved flow,
/// a new engine and a new connect object.
void main() {
  late SharedPreferences prefs;
  late FakeOnboardingFlowRepository flow;
  late FakeOnboardingStepFacts facts;
  late _GetServerInfo getServerInfo;
  late _EstablishSession establishSession;
  late _SaveConnection saveConnection;

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
    // The user tapped Continue with Crit Alarm Cloud: the connect step was
    // finished on the spot. Permissions are already granted.
    flow = FakeOnboardingFlowRepository(
      pinned: BundledOnboardingFlows.defaultFlow,
      completed: {
        OnboardingStepId.welcome,
        OnboardingStepId.howItRings,
        OnboardingStepId.connect,
      },
    );
    facts = FakeOnboardingStepFacts(permissions: true);
    getServerInfo = _GetServerInfo();
    establishSession = _EstablishSession();
    saveConnection = _SaveConnection();
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
    when(() => saveConnection(any())).thenAnswer((_) async {
      facts.connected = true;
      return unit.toSuccess();
    });
  });

  /// One app run.
  ({EngineHarness app, BackgroundConnect connect}) launch() {
    final app = EngineHarness(facts: facts, repository: flow);
    final connect = BackgroundConnect(
      intents: ConnectIntentStore(prefs),
      getServerInfo: getServerInfo,
      establishSession: establishSession,
      saveConnection: saveConnection,
      onAbandoned: () => app.engine.reopenStep(OnboardingStepId.connect),
      clock: () => DateTime.utc(2026, 10, 4, 9),
    );
    addTearDown(connect.dispose);
    return (app: app, connect: connect);
  }

  test('a kill after a failure resumes at the connect step', () async {
    when(() => getServerInfo(any())).thenAnswer(
      (_) async => cloudInfo.copyWith(version: '1.4.0').toSuccess(),
    );
    final first = launch();
    await first.connect.start(cloudUrl);
    await first.connect.settled;
    expect(first.connect.state.isFailed, isTrue);
    expect(flow.completed, isNot(contains(OnboardingStepId.connect)));

    // Killed and opened again.
    final second = launch();
    await second.connect.resumeSaved();
    final destination = await second.app.engine.resume();

    expect(second.connect.state.status, BackgroundConnectStatus.idle);
    expect(destination.stepId, OnboardingStepId.connect);
  });

  test('a kill after a failure, a connect by hand that fails, and another '
      'kill still resumes at the connect step', () async {
    when(() => getServerInfo(any())).thenAnswer(
      (_) async => const Failure.api(statusCode: 404).toFailure(),
    );
    final first = launch();
    await first.connect.start(cloudUrl);
    await first.connect.settled;
    // Back to connect, then Connect on a typed address: the cubit cancels
    // the background connect and its own try fails. Nothing finishes the
    // step.
    await first.connect.cancel();

    final second = launch();
    await second.connect.resumeSaved();
    final destination = await second.app.engine.resume();

    expect(destination.stepId, OnboardingStepId.connect);
  });

  test('a kill while pending resumes behind the waiting gate, and the retry '
      'carries on and lands', () async {
    var online = false;
    when(() => getServerInfo(any())).thenAnswer(
      (_) async => online
          ? cloudInfo.toSuccess()
          : const Failure.unexpected(message: 'offline').toFailure(),
    );
    final first = launch();
    await first.connect.start(cloudUrl);
    await first.connect.settled;
    expect(first.connect.state.isPending, isTrue);
    // Still pending, so the connect step still counts as done.
    expect(flow.completed, contains(OnboardingStepId.connect));

    // Killed and opened again, still offline.
    final second = launch();
    await second.connect.resumeSaved();
    final destination = await second.app.engine.resume();

    expect(destination.stepId, OnboardingStepId.firstTopic);
    expect(second.connect.state.isPending, isTrue);
    expect(second.connect.hasTimer, isTrue);
    expect(
      connectGateFor(
        state: second.connect.state,
        path: destination.route!,
        isReplay: false,
        hasConnection: false,
      ),
      ConnectGate.waiting,
    );

    // The network comes back. The retry lands and the step shows.
    online = true;
    await second.connect.retryNow();

    expect(second.connect.state.isConnected, isTrue);
    expect(
      connectGateFor(
        state: second.connect.state,
        path: destination.route!,
        isReplay: false,
        hasConnection: true,
      ),
      ConnectGate.none,
    );
  });

  test('reopening a step that is not completed changes nothing', () async {
    final app = launch().app;
    final writes = flow.writes;

    await app.engine.reopenStep(OnboardingStepId.firstTopic);

    expect(flow.writes, writes);
  });

  test('completing setup forgets a connect failure', () async {
    when(() => getServerInfo(any())).thenAnswer(
      (_) async => const Failure.api(statusCode: 404).toFailure(),
    );
    final run = launch();
    await run.connect.start(cloudUrl);
    await run.connect.settled;
    final complete = CompleteOnboardingUsecase(
      run.app.progress,
      flow,
      run.connect.dismissFailure,
    );

    await complete(const NoParams());

    expect(run.connect.state, const BackgroundConnectState());
  });

  test('disconnecting cancels the pending connect before it clears, so a '
      'connect on its way cannot leave a server behind', () async {
    final order = <String>[];
    when(() => getServerInfo(any())).thenAnswer(
      (_) async => const Failure.unexpected(message: 'offline').toFailure(),
    );
    final run = launch();
    await run.connect.start(cloudUrl);
    await run.connect.settled;
    run.connect.stream.listen((s) => order.add('connect:${s.status.name}'));
    final clear = ClearConnectionUsecase(
      _Recording(prefs, order),
      beforeClear: run.connect.cancel,
    );

    await clear(const NoParams());
    await pumpEventQueue();

    expect(order, ['connect:idle', 'clear']);
    expect(ConnectIntentStore(prefs).read(), isNull);
  });
}

class _Recording extends SharedPrefsConnectionRepository {
  _Recording(super._prefs, this._order);

  final List<String> _order;

  @override
  Future<AppResult<Unit>> clearConnection() {
    _order.add('clear');
    return super.clearConnection();
  }
}
