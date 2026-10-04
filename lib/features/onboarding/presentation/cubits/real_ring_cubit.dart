import 'dart:async';

import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/features/incidents/domain/usecases/trigger_test_alarm_usecase.dart';
import 'package:critalarm/features/onboarding/domain/connect/background_connect.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_step_facts.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/alarm_arrivals.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/real_ring_rules.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/setup_test_ring.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/real_ring_state.dart';
import 'package:critalarm/features/onboarding/presentation/model/local_test_alarm.dart';
import 'package:critalarm/features/topics/domain/first_topic_handoff.dart';
import 'package:critalarm/features/topics/domain/usecases/update_topic_usecase.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

typedef OneShotTimerFactory =
    Timer Function(Duration duration, void Function() onFire);

/// The real ring step: the server sends the test alarm, the push carries it
/// here, and the phone rings.
///
/// Three rules it keeps:
///
/// - The server is only asked when it can say yes. No server and Critical
///   off are both known before the call, so neither makes one.
/// - Critical delivery is the user's to turn on. Only [setCritical] changes
///   it, and only the switch calls [setCritical].
/// - The test of this phone only never starts by itself. Only
///   [startPhoneOnlyTest] starts it.
class RealRingCubit extends Cubit<RealRingState> {
  RealRingCubit({
    required this.triggerTest,
    required this.updateTopic,
    required this.readTopics,
    required this.refreshTopics,
    required this.hasConnection,
    required this.connectState,
    required this.connectChanges,
    required this.handoff,
    required this.ring,
    required this.arrivals,
    this.alarmHost,
    this.onTopicUpdated,
    this.isReplay = false,
    this.on = const OnboardingPlatform(
      platform: TargetPlatform.android,
      isWeb: false,
    ),
    OneShotTimerFactory? timer,
    PeriodicTimerFactory? periodic,
  }) : _timer = timer ?? Timer.new,
       super(const RealRingState()) {
    _local = LocalTestAlarm(
      host: alarmHost,
      periodic: periodic,
      onChanged: (local) {
        if (!isClosed) emit(state.copyWith(local: local));
      },
    );
  }

  final TriggerTestAlarmUsecase triggerTest;
  final UpdateTopicUsecase updateTopic;

  /// The topics on the server, from the app's shared list.
  final Future<List<Topic>> Function() readTopics;

  /// The same list, fetched again. Asked only when the list does not hold
  /// the topic setup made: the list may have been loaded before the topic
  /// existed.
  final Future<List<Topic>> Function() refreshTopics;

  /// Whether a server connection is saved. One local read.
  final Future<bool> Function() hasConnection;
  final BackgroundConnectState Function() connectState;
  final Stream<BackgroundConnectState> connectChanges;
  final FirstTopicHandoff handoff;
  final SetupTestRing ring;
  final AlarmArrivals arrivals;

  /// Null in tests with no platform channel.
  final AlarmHost? alarmHost;

  /// Told about the topic the server answered after the switch, so the
  /// app's shared list follows.
  final void Function(Topic topic)? onTopicUpdated;
  final OneShotTimerFactory _timer;

  /// The phone the step runs on, handed in as values.
  final OnboardingPlatform on;

  /// Opened from Settings to look at the screen. Nothing is read, sent or
  /// saved.
  final bool isReplay;

  /// The address the phone-only alarm carries when no server is connected.
  /// The alarm never calls it; Android only needs a well formed one.
  static const fallbackServer = 'https://api.critalarm.app';

  late final LocalTestAlarm _local;

  Timer? _pushWait;
  StreamSubscription<String>? _arrivalsSub;
  StreamSubscription<BackgroundConnectState>? _connectSub;

  /// Alarms that reached the phone since the last tap. A push can beat the
  /// answer to the call that caused it.
  final Set<String> _arrived = <String>{};

  bool _isSending = false;

  /// The phases the checks decide. A wait or a result is left alone.
  static const Set<RealRingPhase> _gatePhases = {
    RealRingPhase.checking,
    RealRingPhase.noServer,
    RealRingPhase.noTopic,
    RealRingPhase.criticalOff,
    RealRingPhase.ready,
  };

  /// Reads what the step needs and shows where it stands. Makes no call to
  /// the server's test route.
  Future<void> load() async {
    final authorization = await _readAuthorization();
    if (isClosed) return;
    final alarm = authorization ?? state.alarm;
    emit(
      state.copyWith(
        alarm: alarm,
        platform: realRingPlatformFor(
          platform: on.platform,
          isWeb: on.isWeb,
          claim: RingClaim.forPhone(
            alarm,
            platform: on.platform,
            isWeb: on.isWeb,
          ),
        ),
      ),
    );

    if (isReplay) {
      emit(state.copyWith(phase: RealRingPhase.ready));
      return;
    }

    _arrivalsSub = arrivals.incidentIds.listen(_onArrival);
    _connectSub = connectChanges.listen((_) => unawaited(_recheck()));

    // The alarm can start the app from cold. When the test sent before the
    // app went away is ringing on this phone, its screen is the one to show.
    final sent = ring.incidentId;
    if (sent != null && await arrivals.isUp(sent)) {
      if (isClosed) return;
      emit(state.copyWith(phase: RealRingPhase.rang, incidentId: sent));
      return;
    }
    await _recheck();
  }

  Future<AlarmAuthorization?> _readAuthorization() async {
    try {
      return await alarmHost?.authorizationStatus();
    } on Object catch (_) {
      return null;
    }
  }

  /// Runs the checks and returns what they said. Changes the phase only
  /// while the step is on one of the phases the checks decide.
  Future<RealRingGate> _recheck({bool force = false}) async {
    final connect = connectState();
    final isConnected = await hasConnection();
    final heldName = handoff.entry?.topicName;
    final savedName = handoff.savedTopicName;
    var topics = isConnected ? await readTopics() : const <Topic>[];
    if (isConnected && !_holdsSetupTopic(topics, heldName ?? savedName)) {
      topics = await refreshTopics();
    }
    final found = setupTestTopic(
      heldName: heldName,
      savedName: savedName,
      topics: topics,
    );
    // A 409 taught this cubit the switch is off before the shared list
    // heard. The list still says on, so what was learned wins.
    final topic = found != null && _criticalKnownOff
        ? found.copyWith(critical: false)
        : found;
    final gate = realRingGateFor(
      hasConnection: isConnected,
      connect: connect,
      topic: topic,
    );
    if (isClosed) return gate;
    if (!force && !_gatePhases.contains(state.phase)) return gate;
    emit(
      state.copyWith(
        phase: switch (gate) {
          RealRingGate.noServer => RealRingPhase.noServer,
          RealRingGate.noTopic => RealRingPhase.noTopic,
          RealRingGate.criticalOff => RealRingPhase.criticalOff,
          RealRingGate.ready => RealRingPhase.ready,
        },
        topic: topic,
        clearTopic: topic == null,
        connect: connect,
        clearFailure: true,
      ),
    );
    return gate;
  }

  /// Whether [topics] has the topic setup made. With no name on record any
  /// topic will do.
  static bool _holdsSetupTopic(List<Topic> topics, String? name) => name == null
      ? topics.isNotEmpty
      : topics.any((topic) => topic.name == name);

  /// The server answered 409 for this topic and the user has not turned the
  /// switch on since.
  bool _criticalKnownOff = false;

  /// Ring me for real, and Try again. Asks the server to send the test
  /// alarm, when the checks say it can.
  Future<void> ringForReal() async {
    if (isReplay || _isSending) return;
    _isSending = true;
    try {
      _pushWait?.cancel();
      final gate = await _recheck(force: true);
      if (isClosed || gate != RealRingGate.ready) return;
      final topic = state.topic;
      if (topic == null) return;

      _arrived.clear();
      emit(state.copyWith(phase: RealRingPhase.sending, clearFailure: true));
      final result = await triggerTest(topic.name);
      if (isClosed) return;

      await result.fold(_onSent, (failure) async {
        if (isCriticalOffAnswer(failure)) {
          _criticalKnownOff = true;
          emit(
            state.copyWith(
              phase: RealRingPhase.criticalOff,
              topic: topic.copyWith(critical: false),
              clearFailure: true,
            ),
          );
          return;
        }
        emit(
          state.copyWith(
            phase: RealRingPhase.failed,
            failure: realRingFailureFor(failure),
          ),
        );
      });
    } finally {
      _isSending = false;
    }
  }

  Future<void> _onSent(String incidentId) async {
    // Saved before anything else: the alarm may start the app from cold, and
    // the screen after it has to know this incident was the setup test.
    await ring.hold(incidentId);
    if (isClosed) return;
    if (_arrived.contains(incidentId)) {
      emit(state.copyWith(phase: RealRingPhase.rang, incidentId: incidentId));
      return;
    }
    emit(state.copyWith(phase: RealRingPhase.waiting, incidentId: incidentId));
    _pushWait = _timer(realRingPushWait, _onPushWaitOver);
  }

  void _onPushWaitOver() {
    if (isClosed || state.phase != RealRingPhase.waiting) return;
    emit(state.copyWith(phase: RealRingPhase.timedOut));
  }

  void _onArrival(String incidentId) {
    if (isClosed) return;
    _arrived.add(incidentId);
    final awaited =
        state.phase == RealRingPhase.waiting ||
        state.phase == RealRingPhase.timedOut;
    if (!awaited || incidentId != state.incidentId) return;
    _rang();
  }

  void _rang() {
    _pushWait?.cancel();
    emit(state.copyWith(phase: RealRingPhase.rang));
  }

  /// The app came back to the front. An alarm that started while it was
  /// away may have been missed, so the phone is asked. The server is not.
  Future<void> appResumed() async {
    if (isReplay) return;
    final id = state.incidentId;
    final awaited =
        state.phase == RealRingPhase.waiting ||
        state.phase == RealRingPhase.timedOut;
    if (id != null && awaited) {
      final isUp = await arrivals.isUp(id);
      if (isClosed) return;
      // The phase may have moved while the phone was asked.
      if (isUp && state.incidentId == id && state.phase != RealRingPhase.rang) {
        _rang();
      }
      return;
    }
    await _recheck();
  }

  /// The user tapped the Critical delivery switch. The only path that
  /// changes it.
  Future<void> setCritical({required bool isOn}) async {
    final topic = state.topic;
    if (isReplay || topic == null || state.isSwitchingCritical) return;
    emit(
      state.copyWith(isSwitchingCritical: true, clearCriticalFailure: true),
    );
    final result = await updateTopic(
      UpdateTopicParams(name: topic.name, critical: isOn),
    );
    if (isClosed) return;
    result.fold(
      (updated) {
        _criticalKnownOff = false;
        onTopicUpdated?.call(updated);
        emit(
          state.copyWith(
            isSwitchingCritical: false,
            topic: updated,
            phase: _gatePhases.contains(state.phase)
                ? (updated.critical
                      ? RealRingPhase.ready
                      : RealRingPhase.criticalOff)
                : state.phase,
          ),
        );
      },
      (failure) => emit(
        state.copyWith(isSwitchingCritical: false, criticalFailure: failure),
      ),
    );
  }

  /// Test this phone only. The fallback, started by the user's tap and by
  /// nothing else. It rings from the phone itself and tests neither the
  /// server nor the push.
  Future<void> startPhoneOnlyTest() {
    _pushWait?.cancel();
    final server = state.connect.serverUrl;
    return _local.start(
      server: server == null || server.trim().isEmpty ? fallbackServer : server,
    );
  }

  void cancelPhoneOnlyTest() => _local.cancel();

  /// The alarm screen was opened for the phone-only test.
  void phoneOnlyTestLaunched() => _local.launched();

  /// Puts a replay on [phase], so a developer can look at a state without
  /// making it happen. Does nothing outside a replay, and nothing is sent,
  /// set or saved.
  void showForReplay(RealRingPhase phase, {bool isCountingDown = false}) {
    if (!isReplay) return;
    const sample = Topic(name: 'setup-test');
    emit(
      state.copyWith(
        phase: phase,
        topic: phase == RealRingPhase.criticalOff
            ? sample
            : sample.copyWith(critical: true),
        failure: phase == RealRingPhase.failed ? RealRingFailure.offline : null,
        clearFailure: phase != RealRingPhase.failed,
        local: isCountingDown
            ? const LocalTestAlarmState(
                status: TestAlarmStatus.ringing,
                isCountingDown: true,
                countdownSeconds: 4,
              )
            : const LocalTestAlarmState(),
      ),
    );
  }

  @override
  Future<void> close() {
    _pushWait?.cancel();
    unawaited(_arrivalsSub?.cancel());
    unawaited(_connectSub?.cancel());
    _local.dispose();
    return super.close();
  }
}
