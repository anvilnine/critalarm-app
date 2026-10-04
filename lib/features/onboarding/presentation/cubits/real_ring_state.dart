import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/features/onboarding/domain/connect/background_connect.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/real_ring_rules.dart';
import 'package:critalarm/features/onboarding/presentation/model/local_test_alarm.dart';
import 'package:flutter/foundation.dart';

/// What the real ring step is showing.
enum RealRingPhase {
  /// The first local reads have not answered yet.
  checking,

  /// No server is connected. The server is never asked.
  noServer,

  /// The server holds no topic to ring.
  noTopic,

  /// The topic has Critical delivery off. The server is never asked.
  criticalOff,

  /// The three instruction lines and the button.
  ready,

  /// The call to the server is in flight.
  sending,

  /// The server took the test. Waiting for the phone to ring.
  waiting,

  /// The server took the test and the phone did not ring in time.
  timedOut,

  /// The server did not take the test.
  failed,

  /// The alarm reached this phone. The alarm screen takes over.
  rang,
}

@immutable
class RealRingState {
  const RealRingState({
    this.phase = RealRingPhase.checking,
    this.topic,
    this.connect = const BackgroundConnectState(),
    this.alarm = AlarmAuthorization.notDetermined,
    this.failure,
    this.incidentId,
    this.isSwitchingCritical = false,
    this.criticalFailure,
    this.local = const LocalTestAlarmState(),
    this.platform = RealRingPlatform.android,
  });

  final RealRingPhase phase;

  /// The topic the test rings. Null when the server holds none.
  final Topic? topic;

  /// Where the connect behind the user stands, for the no-server line.
  final BackgroundConnectState connect;

  /// Whether this phone can set an alarm. The copy reads it through
  /// `RingClaim`, so an iPhone older than iOS 26 is not told it rings
  /// through silent mode.
  final AlarmAuthorization alarm;

  /// Why the call failed. Set in [RealRingPhase.failed] only.
  final RealRingFailure? failure;

  /// The incident the server opened for the test. Set from the moment the
  /// server answered.
  final String? incidentId;

  /// The user's tap on the Critical switch is on its way to the server.
  final bool isSwitchingCritical;

  /// The server refused the switch. The cap message is read from it.
  final Failure? criticalFailure;

  /// The test of this phone only, which the user starts by hand.
  final LocalTestAlarmState local;

  /// Which phone this is, for the instruction lines and the check list.
  final RealRingPlatform platform;

  /// What this phone can promise for a ring.
  RingClaim get claim => platform == RealRingPlatform.iosTimeSensitive
      ? RingClaim.timeSensitive
      : RingClaim.alarm;

  /// A wait the screen shows the waiting face for.
  bool get isWaiting =>
      phase == RealRingPhase.checking ||
      phase == RealRingPhase.sending ||
      phase == RealRingPhase.waiting;

  RealRingState copyWith({
    RealRingPhase? phase,
    Topic? topic,
    BackgroundConnectState? connect,
    AlarmAuthorization? alarm,
    RealRingFailure? failure,
    String? incidentId,
    bool? isSwitchingCritical,
    Failure? criticalFailure,
    LocalTestAlarmState? local,
    RealRingPlatform? platform,
    bool clearTopic = false,
    bool clearFailure = false,
    bool clearCriticalFailure = false,
  }) => RealRingState(
    phase: phase ?? this.phase,
    topic: clearTopic ? null : (topic ?? this.topic),
    connect: connect ?? this.connect,
    alarm: alarm ?? this.alarm,
    failure: clearFailure ? null : (failure ?? this.failure),
    incidentId: incidentId ?? this.incidentId,
    isSwitchingCritical: isSwitchingCritical ?? this.isSwitchingCritical,
    criticalFailure: clearCriticalFailure
        ? null
        : (criticalFailure ?? this.criticalFailure),
    local: local ?? this.local,
    platform: platform ?? this.platform,
  );

  @override
  bool operator ==(Object other) =>
      other is RealRingState &&
      phase == other.phase &&
      topic == other.topic &&
      connect == other.connect &&
      alarm == other.alarm &&
      failure == other.failure &&
      incidentId == other.incidentId &&
      isSwitchingCritical == other.isSwitchingCritical &&
      criticalFailure == other.criticalFailure &&
      local == other.local &&
      platform == other.platform;

  @override
  int get hashCode => Object.hash(
    phase,
    topic,
    connect,
    alarm,
    failure,
    incidentId,
    isSwitchingCritical,
    criticalFailure,
    local,
    platform,
  );
}
