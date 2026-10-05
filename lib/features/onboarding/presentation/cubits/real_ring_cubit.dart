import 'dart:async';

import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/features/incidents/domain/usecases/trigger_test_alarm_usecase.dart';
import 'package:critalarm/features/onboarding/domain/connect/background_connect.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_step_facts.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/alarm_arrivals.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/real_ring_rules.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/send_countdown.dart';
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
/// Four rules it keeps:
///
/// - The tap does not send at once. It starts a short wait
///   ([realRingSendDelay]) so the user can lock the phone, and the server is
///   asked when the wait ends, or the moment the app leaves the front.
///   Cancel sends nothing.
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
    this.readCriticalLimit,
    this.readServerUrl,
    this.sendDelay = realRingSendDelay,
    this.isReplay = false,
    this.on = const OnboardingPlatform(
      platform: TargetPlatform.android,
      isWeb: false,
    ),
    OneShotTimerFactory? timer,
    PeriodicTimerFactory? periodic,
  }) : _timer = timer ?? Timer.new,
       super(const RealRingState()) {
    _sendCountdown = SendCountdown(
      delay: sendDelay,
      ticker: periodic,
      onChanged: (seconds) {
        if (isClosed) return;
        emit(
          state.copyWith(
            sendSecondsLeft: seconds,
            clearSendCountdown: seconds == null,
          ),
        );
      },
      onSend: () => unawaited(_send()),
    );
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

  /// The free plan's cap on critical topics, or null where there is none
  /// (a paid plan, a server of the user's own). Local reads only. Null in
  /// tests that do not need the plan line.
  final Future<int?> Function()? readCriticalLimit;
  final OneShotTimerFactory _timer;

  /// The address of the connected server, or null when none is saved. Only
  /// shown, in the command the countdown types. Null in tests that do not
  /// look at it.
  final Future<String?> Function()? readServerUrl;

  /// How long the tap waits before the server is asked. Zero sends at once.
  final Duration sendDelay;

  /// The phone the step runs on, handed in as values.
  final OnboardingPlatform on;

  /// Opened from Settings to look at the screen. Nothing is read, sent or
  /// saved.
  final bool isReplay;

  /// The address the phone-only alarm carries when no server is connected.
  /// The alarm never calls it; Android only needs a well formed one.
  static const fallbackServer = 'https://api.critalarm.app';

  late final LocalTestAlarm _local;
  late final SendCountdown _sendCountdown;

  /// What a replay shows in place of a real address.
  static const exampleServerUrl = 'https://api.critalarm.app';

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
    final up = await _firstUp();
    if (isClosed) return;
    if (up != null) {
      emit(state.copyWith(phase: RealRingPhase.rang, incidentId: up));
      return;
    }
    await _recheck();
  }

  /// The first test of this setup run whose alarm is up on this phone, the
  /// newest one first. Null when none is. A local read.
  Future<String?> _firstUp() async {
    final newest = ring.incidentId;
    final ids = [
      ?newest,
      ...ring.incidentIds.where((id) => id != newest),
    ];
    for (final id in ids) {
      if (await arrivals.isUp(id)) return id;
    }
    return null;
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
    final plan = criticalPlanFor(
      topics: topics,
      topic: topic,
      limit: await readCriticalLimit?.call(),
    );
    String? serverUrl;
    try {
      serverUrl = isConnected ? await readServerUrl?.call() : null;
    } on Object catch (_) {
      // Only shown. The step works without it.
      serverUrl = null;
    }
    if (isClosed) return gate;
    if (!force && !_gatePhases.contains(state.phase)) return gate;
    // Whatever the wait was counting towards can no longer be sent.
    if (gate != RealRingGate.ready) _sendCountdown.cancel();
    emit(
      state.copyWith(
        plan: plan,
        clearPlan: plan == null,
        phase: switch (gate) {
          RealRingGate.noServer => RealRingPhase.noServer,
          RealRingGate.noTopic => RealRingPhase.noTopic,
          RealRingGate.criticalOff => RealRingPhase.criticalOff,
          RealRingGate.ready => RealRingPhase.ready,
        },
        topic: topic,
        clearTopic: topic == null,
        connect: connect,
        serverUrl: serverUrl ?? connect.serverUrl,
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

  /// Ring me for real, and Try again. Runs the checks and, when they say
  /// the server can be asked, starts the wait that ends in the call.
  ///
  /// Nothing is sent here. A second tap while the checks, the wait or the
  /// call are running does nothing.
  Future<void> ringForReal() async {
    if (isReplay || _isSending || _isStarting || _sendCountdown.isRunning) {
      return;
    }
    _isStarting = true;
    try {
      _pushWait?.cancel();
      final gate = await _recheck(force: true);
      if (isClosed || gate != RealRingGate.ready) return;
      if (state.topic == null) return;
      // With the wait switched off the tap sends, as it always did.
      if (sendDelay <= Duration.zero) {
        await _send();
        return;
      }
      _sendCountdown.start();
    } finally {
      _isStarting = false;
    }
  }

  bool _isStarting = false;

  /// Cancel, during the wait. Back to the ready state with nothing sent.
  void cancelSend() => _sendCountdown.cancel();

  /// The app left the front. A timer is not promised to run in the
  /// background on either platform, and the user leaving is the sign they
  /// are ready, so a running wait ends now and the server is asked at once.
  void appLeftFront() {
    if (isReplay) return;
    _sendCountdown.leftFront();
  }

  /// Asks the server to send the test alarm. Only the wait calls it.
  Future<void> _send() async {
    if (isReplay || isClosed || _isSending) return;
    _isSending = true;
    try {
      final topic = state.topic;
      // The checks moved on while the wait ran.
      if (topic == null || state.phase != RealRingPhase.ready) return;

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
      _rang(incidentId);
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
    // Try again sends a second test, and the first can still ring late.
    // Either one is this setup's test alarm reaching the phone.
    if (!awaited || !_isSetupTest(incidentId)) return;
    _rang(incidentId);
  }

  bool _isSetupTest(String incidentId) =>
      incidentId == state.incidentId || ring.incidentIds.contains(incidentId);

  void _rang(String incidentId) {
    _pushWait?.cancel();
    // The user may have started the test of this phone only while waiting.
    // The server's alarm is here now, so the phone's own alarm is taken
    // back before it fires on top of it.
    if (_local.state.isCountingDown) _local.cancel();
    emit(state.copyWith(phase: RealRingPhase.rang, incidentId: incidentId));
  }

  /// The app came back to the front. An alarm that started while it was
  /// away may have been missed, so the phone is asked. The server is not.
  Future<void> appResumed() async {
    if (isReplay) return;
    final awaited =
        state.phase == RealRingPhase.waiting ||
        state.phase == RealRingPhase.timedOut;
    if (state.incidentId != null && awaited) {
      final up = await _firstUp();
      if (isClosed) return;
      // The phase may have moved while the phone was asked.
      if (up != null && state.phase != RealRingPhase.rang) _rang(up);
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
  void showForReplay(
    RealRingPhase phase, {
    bool isCountingDown = false,
    bool isSendCountingDown = false,
  }) {
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
        // Made-up numbers, like the topic: the card with its plan line.
        plan: phase == RealRingPhase.criticalOff ? (used: 1, limit: 2) : null,
        clearPlan: phase != RealRingPhase.criticalOff,
        serverUrl: exampleServerUrl,
        sendSecondsLeft: isSendCountingDown ? sendDelay.inSeconds : null,
        clearSendCountdown: !isSendCountingDown,
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
    _sendCountdown.dispose();
    unawaited(_arrivalsSub?.cancel());
    unawaited(_connectSub?.cancel());
    _local.dispose();
    return super.close();
  }
}
