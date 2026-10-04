import 'dart:async';

import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/incidents/domain/usecases/trigger_test_alarm_usecase.dart';
import 'package:critalarm/features/onboarding/domain/connect/background_connect.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/alarm_arrivals.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/real_ring_rules.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/real_ring_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/real_ring_state.dart';
import 'package:critalarm/features/onboarding/presentation/model/local_test_alarm.dart';
import 'package:critalarm/features/topics/domain/first_topic_handoff.dart';
import 'package:critalarm/features/topics/domain/usecases/update_topic_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../core/alarm/fake_alarm_host.dart';
import 'support/fake_setup_test_ring.dart';

class _MockTriggerTest extends Mock implements TriggerTestAlarmUsecase {}

class _MockUpdateTopic extends Mock implements UpdateTopicUsecase {}

class _FakeArrivals implements AlarmArrivals {
  final controller = StreamController<String>.broadcast();
  final up = <String>{};

  @override
  Stream<String> get incidentIds => controller.stream;

  @override
  Future<bool> isUp(String incidentId) async => up.contains(incidentId);
}

class _FakeHandoff implements FirstTopicHandoff {
  _FakeHandoff({this.savedTopicName});

  @override
  FirstTopicHandoffEntry? entry;

  @override
  String? savedTopicName;

  @override
  String? mintedTokenId;

  @override
  Future<void> saveMintedTokenId(String tokenId) async =>
      mintedTokenId = tokenId;

  @override
  Future<void> hold(FirstTopicHandoffEntry entry) async => this.entry = entry;

  @override
  Future<void> clear() async {
    entry = null;
    savedTopicName = null;
  }
}

/// A timer the test fires by hand.
class _FakeTimer implements Timer {
  _FakeTimer(this.duration, this._onFire);

  final Duration duration;
  final void Function() _onFire;
  bool _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    _onFire();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

void main() {
  const critical = Topic(name: 'setup-test', critical: true);
  const quiet = Topic(name: 'setup-test');
  const connected = BackgroundConnectState(
    status: BackgroundConnectStatus.connected,
    serverUrl: 'https://api.critalarm.app',
  );

  late _MockTriggerTest triggerTest;
  late _MockUpdateTopic updateTopic;
  late _FakeArrivals arrivals;
  late FakeSetupTestRing ring;
  late _FakeHandoff handoff;
  late FakeAlarmHost alarm;
  late List<_FakeTimer> timers;
  late List<Topic> topics;
  late bool hasConnection;
  late BackgroundConnectState connect;
  late StreamController<BackgroundConnectState> connectChanges;
  late List<Topic> applied;

  /// What the server holds, when it differs from the shared list.
  late List<Topic>? onServer;
  late int refreshes;

  setUpAll(() {
    registerFallbackValue(const UpdateTopicParams(name: ''));
  });

  setUp(() {
    triggerTest = _MockTriggerTest();
    updateTopic = _MockUpdateTopic();
    arrivals = _FakeArrivals();
    ring = FakeSetupTestRing();
    handoff = _FakeHandoff(savedTopicName: 'setup-test');
    alarm = FakeAlarmHost();
    timers = [];
    topics = [critical];
    hasConnection = true;
    connect = connected;
    connectChanges = StreamController<BackgroundConnectState>.broadcast();
    applied = [];
    onServer = null;
    refreshes = 0;
  });

  tearDown(() async {
    alarm.dispose();
    await arrivals.controller.close();
    await connectChanges.close();
  });

  RealRingCubit build({bool isReplay = false}) => RealRingCubit(
    triggerTest: triggerTest,
    updateTopic: updateTopic,
    readTopics: () async => topics,
    refreshTopics: () async {
      refreshes++;
      return topics = onServer ?? topics;
    },
    hasConnection: () async => hasConnection,
    connectState: () => connect,
    connectChanges: connectChanges.stream,
    handoff: handoff,
    ring: ring,
    arrivals: arrivals,
    alarmHost: alarm.host,
    onTopicUpdated: applied.add,
    isReplay: isReplay,
    timer: (duration, onFire) {
      final timer = _FakeTimer(duration, onFire);
      timers.add(timer);
      return timer;
    },
  );

  void serverAnswers(String incidentId) {
    when(
      () => triggerTest(any()),
    ).thenAnswer((_) async => incidentId.toSuccess());
  }

  void serverFails(Failure failure) {
    when(() => triggerTest(any())).thenAnswer((_) async => failure.toFailure());
  }

  /// Lets the stream listeners run.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('what the step shows when it opens', () {
    test('a connected server and a critical topic are ready', () async {
      final cubit = build();
      await cubit.load();
      expect(cubit.state.phase, RealRingPhase.ready);
      expect(cubit.state.topic, critical);
      verifyNever(() => triggerTest(any()));
      await cubit.close();
    });

    test('the topic comes from the handoff, not the top of the list', () async {
      topics = [const Topic(name: 'other', critical: true), quiet];
      final cubit = build();
      await cubit.load();
      expect(cubit.state.topic?.name, 'setup-test');
      expect(cubit.state.phase, RealRingPhase.criticalOff);
      await cubit.close();
    });

    test('Critical off shows Critical off', () async {
      topics = [quiet];
      final cubit = build();
      await cubit.load();
      expect(cubit.state.phase, RealRingPhase.criticalOff);
      await cubit.close();
    });

    test('no saved connection shows no server', () async {
      hasConnection = false;
      connect = const BackgroundConnectState();
      final cubit = build();
      await cubit.load();
      expect(cubit.state.phase, RealRingPhase.noServer);
      await cubit.close();
    });

    test(
      'a topic made a moment ago is found by reading the list again',
      () async {
        // The shared list was loaded before setup made the topic, so it is
        // still empty. The server has the topic.
        topics = [];
        onServer = [quiet];
        final cubit = build();
        await cubit.load();

        expect(refreshes, 1);
        expect(cubit.state.topic, quiet);
        expect(cubit.state.phase, RealRingPhase.criticalOff);
        await cubit.close();
      },
    );

    test('a list that already holds the topic is not fetched again', () async {
      final cubit = build();
      await cubit.load();
      await cubit.appResumed();
      expect(refreshes, 0);
      await cubit.close();
    });

    test('a server with no topic says so', () async {
      topics = [];
      final cubit = build();
      await cubit.load();
      expect(cubit.state.phase, RealRingPhase.noTopic);
      await cubit.close();
    });

    test(
      'a connect that lands while the step is open makes it ready',
      () async {
        hasConnection = false;
        connect = const BackgroundConnectState(
          status: BackgroundConnectStatus.connecting,
        );
        final cubit = build();
        await cubit.load();
        expect(cubit.state.phase, RealRingPhase.noServer);

        hasConnection = true;
        connect = connected;
        connectChanges.add(connected);
        await settle();
        await settle();

        expect(cubit.state.phase, RealRingPhase.ready);
        verifyNever(() => triggerTest(any()));
        await cubit.close();
      },
    );
  });

  group('Ring me for real', () {
    test('Critical off makes zero calls to the test usecase', () async {
      topics = [quiet];
      final cubit = build();
      await cubit.load();
      await cubit.ringForReal();
      await cubit.ringForReal();

      expect(cubit.state.phase, RealRingPhase.criticalOff);
      verifyNever(() => triggerTest(any()));
      expect(ring.incidentId, isNull);
      expect(timers, isEmpty);
      await cubit.close();
    });

    test('no server makes zero calls', () async {
      hasConnection = false;
      connect = const BackgroundConnectState();
      final cubit = build();
      await cubit.load();
      await cubit.ringForReal();

      expect(cubit.state.phase, RealRingPhase.noServer);
      verifyNever(() => triggerTest(any()));
      await cubit.close();
    });

    test('the checks run again on every tap', () async {
      final cubit = build();
      await cubit.load();
      expect(cubit.state.phase, RealRingPhase.ready);

      // The connect gave up after the step opened.
      connect = const BackgroundConnectState(
        status: BackgroundConnectStatus.failed,
        failure: BackgroundConnectFailure.refused,
      );
      await cubit.ringForReal();

      expect(cubit.state.phase, RealRingPhase.noServer);
      verifyNever(() => triggerTest(any()));
      await cubit.close();
    });

    test('a 200 moves to waiting and keeps the incident id', () async {
      serverAnswers('inc_7');
      final cubit = build();
      await cubit.load();
      final phases = <RealRingPhase>[];
      final sub = cubit.stream.listen((s) => phases.add(s.phase));

      await cubit.ringForReal();
      await settle();

      expect(phases, [RealRingPhase.sending, RealRingPhase.waiting]);
      expect(cubit.state.incidentId, 'inc_7');
      expect(ring.incidentId, 'inc_7');
      verify(() => triggerTest('setup-test')).called(1);
      expect(timers.single.duration, realRingPushWait);
      expect(timers.single.isActive, isTrue);
      await sub.cancel();
      await cubit.close();
    });

    test('the fake timer at 20 seconds moves to timed out', () async {
      serverAnswers('inc_7');
      final cubit = build();
      await cubit.load();
      await cubit.ringForReal();

      timers.single.fire();

      expect(cubit.state.phase, RealRingPhase.timedOut);
      expect(cubit.state.incidentId, 'inc_7');
      await cubit.close();
    });

    test('an alarm start before 20 seconds cancels the timer', () async {
      serverAnswers('inc_7');
      final cubit = build();
      await cubit.load();
      await cubit.ringForReal();

      arrivals.controller.add('inc_7');
      await settle();

      expect(cubit.state.phase, RealRingPhase.rang);
      expect(timers.single.isActive, isFalse);
      // A timer that was already cancelled changes nothing if it fires.
      timers.single.fire();
      expect(cubit.state.phase, RealRingPhase.rang);
      await cubit.close();
    });

    test('an alarm for another incident is not this test', () async {
      serverAnswers('inc_7');
      final cubit = build();
      await cubit.load();
      await cubit.ringForReal();

      arrivals.controller.add('inc_other');
      await settle();

      expect(cubit.state.phase, RealRingPhase.waiting);
      expect(timers.single.isActive, isTrue);
      await cubit.close();
    });

    test('a push that beats the answer still counts', () async {
      final answer = Completer<AppResult<String>>();
      when(() => triggerTest(any())).thenAnswer((_) => answer.future);
      final cubit = build();
      await cubit.load();
      final tap = cubit.ringForReal();
      await settle();
      expect(cubit.state.phase, RealRingPhase.sending);

      arrivals.controller.add('inc_7');
      await settle();
      answer.complete('inc_7'.toSuccess());
      await tap;

      expect(cubit.state.phase, RealRingPhase.rang);
      expect(timers, isEmpty);
      await cubit.close();
    });

    test('a ring that comes after the time out still counts', () async {
      serverAnswers('inc_7');
      final cubit = build();
      await cubit.load();
      await cubit.ringForReal();
      timers.single.fire();
      expect(cubit.state.phase, RealRingPhase.timedOut);

      arrivals.controller.add('inc_7');
      await settle();

      expect(cubit.state.phase, RealRingPhase.rang);
      await cubit.close();
    });

    test('coming back to the app finds an alarm that is already up', () async {
      serverAnswers('inc_7');
      final cubit = build();
      await cubit.load();
      await cubit.ringForReal();
      timers.single.fire();

      arrivals.up.add('inc_7');
      await cubit.appResumed();

      expect(cubit.state.phase, RealRingPhase.rang);
      await cubit.close();
    });

    test(
      'a cold start with the alarm already up goes straight to it',
      () async {
        ring.incidentId = 'inc_7';
        arrivals.up.add('inc_7');
        final cubit = build();
        await cubit.load();

        expect(cubit.state.phase, RealRingPhase.rang);
        expect(cubit.state.incidentId, 'inc_7');
        verifyNever(() => triggerTest(any()));
        await cubit.close();
      },
    );

    test('a stored id with no alarm up opens the step as usual', () async {
      await ring.hold('inc_7');
      final cubit = build();
      await cubit.load();
      expect(cubit.state.phase, RealRingPhase.ready);
      await cubit.close();
    });

    test('a second tap while one is in flight sends nothing more', () async {
      final answer = Completer<AppResult<String>>();
      when(() => triggerTest(any())).thenAnswer((_) => answer.future);
      final cubit = build();
      await cubit.load();
      final first = cubit.ringForReal();
      await settle();
      await cubit.ringForReal();
      answer.complete('inc_7'.toSuccess());
      await first;

      verify(() => triggerTest(any())).called(1);
      await cubit.close();
    });

    test('Try again after a time out asks the server again', () async {
      serverAnswers('inc_7');
      final cubit = build();
      await cubit.load();
      await cubit.ringForReal();
      timers.single.fire();

      serverAnswers('inc_8');
      await cubit.ringForReal();

      expect(cubit.state.phase, RealRingPhase.waiting);
      expect(cubit.state.incidentId, 'inc_8');
      expect(ring.incidentId, 'inc_8');
      expect(timers.last.isActive, isTrue);
      await cubit.close();
    });

    test('after Try again, a late ring from the first test still counts '
        'as the setup test', () async {
      serverAnswers('inc_7');
      final cubit = build();
      await cubit.load();
      await cubit.ringForReal();
      timers.single.fire();
      serverAnswers('inc_8');
      await cubit.ringForReal();
      // Both ids are kept, so the first is still known as a setup test.
      expect(ring.incidentIds, {'inc_7', 'inc_8'});

      arrivals.controller.add('inc_7');
      await settle();

      expect(cubit.state.phase, RealRingPhase.rang);
      // The alarm screen opens the incident that is ringing.
      expect(cubit.state.incidentId, 'inc_7');
      expect(timers.last.isActive, isFalse);
      await cubit.close();
    });

    test('a cold start finds an earlier test of the run ringing', () async {
      await ring.hold('inc_7');
      await ring.hold('inc_8');
      arrivals.up.add('inc_7');
      final cubit = build();
      await cubit.load();

      expect(cubit.state.phase, RealRingPhase.rang);
      expect(cubit.state.incidentId, 'inc_7');
      await cubit.close();
    });

    test('closing the step stops the timer', () async {
      serverAnswers('inc_7');
      final cubit = build();
      await cubit.load();
      await cubit.ringForReal();
      await cubit.close();
      expect(timers.single.isActive, isFalse);
    });
  });

  group('when the call fails', () {
    test('each failure maps to a reason', () async {
      final cases = <Failure, RealRingFailure>{
        const Failure.api(statusCode: 401): RealRingFailure.signedOut,
        const Failure.api(statusCode: 404): RealRingFailure.topicGone,
        const Failure.api(statusCode: 429): RealRingFailure.rateLimited,
        const Failure.api(statusCode: 500): RealRingFailure.serverDown,
        const Failure.unexpected(
          message: 'SocketException: Failed host lookup',
        ): RealRingFailure.offline,
        const Failure.unexpected(
          message: 'TimeoutException after 0:00:15',
        ): RealRingFailure.slow,
        const Failure.unexpected(message: 'boom'): RealRingFailure.unknown,
      };
      for (final entry in cases.entries) {
        serverFails(entry.key);
        final cubit = build();
        await cubit.load();
        await cubit.ringForReal();

        expect(cubit.state.phase, RealRingPhase.failed, reason: '$entry');
        expect(cubit.state.failure, entry.value, reason: '$entry');
        expect(timers, isEmpty);
        expect(ring.incidentId, isNull);
        await cubit.close();
      }
    });

    test('a 409 that arrives anyway is shown as Critical off', () async {
      serverFails(
        const Failure.api(statusCode: 409, message: 'topic is not critical'),
      );
      final cubit = build();
      await cubit.load();
      await cubit.ringForReal();

      expect(cubit.state.phase, RealRingPhase.criticalOff);
      expect(cubit.state.failure, isNull);
      expect(cubit.state.topic?.critical, isFalse);
      // Known now, so the next tap does not ask again.
      await cubit.ringForReal();
      verify(() => triggerTest(any())).called(1);
      await cubit.close();
    });

    test('Try again after a failure can succeed', () async {
      serverFails(const Failure.api(statusCode: 500));
      final cubit = build();
      await cubit.load();
      await cubit.ringForReal();
      expect(cubit.state.phase, RealRingPhase.failed);

      serverAnswers('inc_7');
      await cubit.ringForReal();

      expect(cubit.state.phase, RealRingPhase.waiting);
      expect(cubit.state.failure, isNull);
      await cubit.close();
    });
  });

  group("Critical delivery is the user's to turn on", () {
    void serverTakesUpdate() {
      when(() => updateTopic(any())).thenAnswer((invocation) async {
        final params = invocation.positionalArguments[0] as UpdateTopicParams;
        return Topic(
          name: params.name,
          critical: params.critical ?? false,
        ).toSuccess();
      });
    }

    test('nothing but the switch method calls UpdateTopicUsecase', () async {
      topics = [quiet];
      serverAnswers('inc_7');
      serverTakesUpdate();
      final cubit = build();

      // Every other thing the step can do.
      await cubit.load();
      await cubit.ringForReal();
      await cubit.appResumed();
      connectChanges.add(connected);
      arrivals.controller.add('inc_7');
      await settle();
      await cubit.startPhoneOnlyTest();
      cubit.cancelPhoneOnlyTest();
      await cubit.ringForReal();

      verifyNever(() => updateTopic(any()));
      expect(cubit.state.topic?.critical, isFalse);
      await cubit.close();
      verifyNever(() => updateTopic(any()));
    });

    test('a ready step never touches the switch either', () async {
      serverAnswers('inc_7');
      serverTakesUpdate();
      final cubit = build();
      await cubit.load();
      await cubit.ringForReal();
      timers.single.fire();
      await cubit.ringForReal();
      await cubit.close();
      verifyNever(() => updateTopic(any()));
    });

    test('the switch turns it on and the step becomes ready', () async {
      topics = [quiet];
      serverTakesUpdate();
      final cubit = build();
      await cubit.load();

      await cubit.setCritical(isOn: true);

      final params =
          verify(() => updateTopic(captureAny())).captured.single
              as UpdateTopicParams;
      expect(params.name, 'setup-test');
      expect(params.critical, isTrue);
      expect(params.repeatIntervalS, isNull);
      expect(cubit.state.phase, RealRingPhase.ready);
      expect(cubit.state.topic?.critical, isTrue);
      expect(applied.single.critical, isTrue);
      // Turning it on rings nothing by itself.
      verifyNever(() => triggerTest(any()));
      await cubit.close();
    });

    test('a cap answer leaves the switch off and keeps the failure', () async {
      topics = [quiet];
      const cap = Failure.api(
        statusCode: 429,
        message: 'cap',
        cap: 'critical_topics',
      );
      when(() => updateTopic(any())).thenAnswer((_) async => cap.toFailure());
      final cubit = build();
      await cubit.load();

      await cubit.setCritical(isOn: true);

      expect(cubit.state.phase, RealRingPhase.criticalOff);
      expect(cubit.state.topic?.critical, isFalse);
      expect(cubit.state.criticalFailure, cap);
      expect(cubit.state.isSwitchingCritical, isFalse);
      await cubit.close();
    });
  });

  group('the test of this phone only', () {
    test('starts only from its own method', () async {
      serverAnswers('inc_7');
      final cubit = build();
      await cubit.load();
      await cubit.ringForReal();
      timers.single.fire();
      await cubit.appResumed();
      await cubit.ringForReal();
      arrivals.controller.add('inc_other');
      await settle();

      expect(alarm.callsTo('scheduleAlarm'), isEmpty);
      expect(cubit.state.local.status, TestAlarmStatus.idle);
      await cubit.close();
    });

    test('no server, a failed call and a time out never start it', () async {
      hasConnection = false;
      final cubit = build();
      await cubit.load();
      await cubit.ringForReal();
      expect(alarm.callsTo('scheduleAlarm'), isEmpty);
      await cubit.close();

      hasConnection = true;
      serverFails(const Failure.api(statusCode: 500));
      final failing = build();
      await failing.load();
      await failing.ringForReal();
      expect(alarm.callsTo('scheduleAlarm'), isEmpty);
      await failing.close();
    });

    test(
      'its own method sets the alarm on the phone, not the server',
      () async {
        final cubit = build();
        await cubit.load();

        await cubit.startPhoneOnlyTest();

        final args = alarm.argsOnce('scheduleAlarm');
        expect(args['incident_id'], 'inc_demo');
        expect(args['topic'], 'demo-topic');
        expect(args['server'], 'https://api.critalarm.app');
        expect(args['hand_over_to_status_card'], isFalse);
        expect(cubit.state.local.isCountingDown, isTrue);
        verifyNever(() => triggerTest(any()));
        expect(ring.incidentId, isNull);
        cubit.cancelPhoneOnlyTest();
        expect(cubit.state.local.isCountingDown, isFalse);
        expect(alarm.callsTo('cancelAlarm'), hasLength(1));
        await cubit.close();
      },
    );

    test('a late server push during its countdown takes the phone alarm '
        'back, so only one alarm rings', () async {
      serverAnswers('inc_7');
      final cubit = build();
      await cubit.load();
      await cubit.ringForReal();
      timers.single.fire();
      expect(cubit.state.phase, RealRingPhase.timedOut);

      await cubit.startPhoneOnlyTest();
      expect(cubit.state.local.isCountingDown, isTrue);
      expect(alarm.callsTo('cancelAlarm'), isEmpty);

      arrivals.controller.add('inc_7');
      await settle();

      expect(cubit.state.phase, RealRingPhase.rang);
      // The alarm the OS was holding for the phone-only test is cancelled,
      // not just the clock on screen.
      final cancel = alarm.argsOnce('cancelAlarm');
      expect(cancel['incident_id'], 'inc_demo');
      expect(cancel['hand_over_to_status_card'], isFalse);
      expect(cubit.state.local.isCountingDown, isFalse);
      expect(cubit.state.local.canLaunch, isFalse);
      await cubit.close();
    });

    test('a server push with no countdown running cancels nothing', () async {
      serverAnswers('inc_7');
      final cubit = build();
      await cubit.load();
      await cubit.ringForReal();
      arrivals.controller.add('inc_7');
      await settle();

      expect(cubit.state.phase, RealRingPhase.rang);
      expect(alarm.callsTo('cancelAlarm'), isEmpty);
      await cubit.close();
    });

    test('with no server it still has an address to carry', () async {
      hasConnection = false;
      connect = const BackgroundConnectState();
      final cubit = build();
      await cubit.load();

      await cubit.startPhoneOnlyTest();

      expect(
        alarm.argsOnce('scheduleAlarm')['server'],
        RealRingCubit.fallbackServer,
      );
      cubit.cancelPhoneOnlyTest();
      await cubit.close();
    });

    test('a phone that refuses the alarm reports a failure', () async {
      alarm.answers['scheduleAlarm'] = false;
      final cubit = build();
      await cubit.load();

      await cubit.startPhoneOnlyTest();

      expect(cubit.state.local.status, TestAlarmStatus.failure);
      expect(cubit.state.local.isCountingDown, isFalse);
      await cubit.close();
    });
  });

  group('a replay', () {
    test('sends nothing to the server and reads nothing', () async {
      serverAnswers('inc_7');
      var reads = 0;
      final cubit = RealRingCubit(
        triggerTest: triggerTest,
        updateTopic: updateTopic,
        readTopics: () async {
          reads++;
          return topics;
        },
        refreshTopics: () async {
          reads++;
          return topics;
        },
        hasConnection: () async => hasConnection,
        connectState: () => connect,
        connectChanges: connectChanges.stream,
        handoff: handoff,
        ring: ring,
        arrivals: arrivals,
        alarmHost: alarm.host,
        isReplay: true,
      );
      await cubit.load();
      expect(cubit.state.phase, RealRingPhase.ready);

      await cubit.ringForReal();
      await cubit.setCritical(isOn: true);
      await cubit.appResumed();

      verifyNever(() => triggerTest(any()));
      verifyNever(() => updateTopic(any()));
      expect(reads, 0);
      expect(ring.incidentId, isNull);
      expect(cubit.state.phase, RealRingPhase.ready);
      await cubit.close();
    });
  });
}
