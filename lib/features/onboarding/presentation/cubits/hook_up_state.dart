import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/features/topics/domain/tool_template.dart';
import 'package:flutter/foundation.dart';

/// Where the hook-up step stands on having a curl line to show.
enum HookUpPhase {
  /// Reading which topic setup made. A wait.
  finding,

  /// The line is on screen, with a token in it.
  ready,

  /// The token setup made is gone, so a new one is being made. A wait.
  minting,

  /// The server would not make a new token.
  mintFailed,

  /// A server is connected and holds no topic to send to.
  noTopic,

  /// No server is connected.
  noServer,
}

/// What the hook-up screen draws.
///
/// It holds the publish token, so [toString] is written by hand and leaves
/// it out. Nothing that prints a state can leak it.
@immutable
class HookUpState {
  const HookUpState({
    this.phase = HookUpPhase.finding,
    this.topicName,
    this.serverUrl,
    this.token,
    this.template,
    this.isCritical,
    this.claim = RingClaim.alarm,
    this.isFirstMessageReceived = false,
    this.isAnalyticsOn = false,
    this.isExample = false,
    this.mintFailure,
    this.ringingIncidentId,
  });

  final HookUpPhase phase;
  final String? topicName;
  final String? serverUrl;

  /// The publish token. Memory only.
  final String? token;

  /// The tool the user picked on the first topic, or null.
  final ToolTemplate? template;

  /// Whether the topic's Critical switch is on. Null until it is known.
  final bool? isCritical;

  /// What this phone can promise for a ring.
  final RingClaim claim;

  final bool isFirstMessageReceived;
  final bool isAnalyticsOn;

  /// A replay from Settings: the address and the token are made up.
  final bool isExample;

  /// Why the token could not be made. Set in [HookUpPhase.mintFailed].
  final Failure? mintFailure;

  /// The incident of an alarm the user's own message set off while this
  /// step was open. The phone is ringing, so the screen hands over to the
  /// alarm, where the stop control is.
  final String? ringingIncidentId;

  /// A wait the screen shows the waiting face for.
  bool get isWaiting =>
      phase == HookUpPhase.finding || phase == HookUpPhase.minting;

  /// Whether there is a line to show.
  bool get hasLine =>
      phase == HookUpPhase.ready &&
      topicName != null &&
      serverUrl != null &&
      token != null;

  HookUpState copyWith({
    HookUpPhase? phase,
    String? topicName,
    String? serverUrl,
    String? token,
    ToolTemplate? template,
    bool? isCritical,
    RingClaim? claim,
    bool? isFirstMessageReceived,
    bool? isAnalyticsOn,
    bool? isExample,
    Failure? mintFailure,
    String? ringingIncidentId,
    bool clearMintFailure = false,
    bool clearTemplate = false,
  }) => HookUpState(
    phase: phase ?? this.phase,
    topicName: topicName ?? this.topicName,
    serverUrl: serverUrl ?? this.serverUrl,
    token: token ?? this.token,
    template: clearTemplate ? null : (template ?? this.template),
    isCritical: isCritical ?? this.isCritical,
    claim: claim ?? this.claim,
    isFirstMessageReceived:
        isFirstMessageReceived ?? this.isFirstMessageReceived,
    isAnalyticsOn: isAnalyticsOn ?? this.isAnalyticsOn,
    isExample: isExample ?? this.isExample,
    mintFailure: clearMintFailure ? null : (mintFailure ?? this.mintFailure),
    ringingIncidentId: ringingIncidentId ?? this.ringingIncidentId,
  );

  @override
  bool operator ==(Object other) =>
      other is HookUpState &&
      phase == other.phase &&
      topicName == other.topicName &&
      serverUrl == other.serverUrl &&
      token == other.token &&
      template == other.template &&
      isCritical == other.isCritical &&
      claim == other.claim &&
      isFirstMessageReceived == other.isFirstMessageReceived &&
      isAnalyticsOn == other.isAnalyticsOn &&
      isExample == other.isExample &&
      mintFailure == other.mintFailure &&
      ringingIncidentId == other.ringingIncidentId;

  @override
  int get hashCode => Object.hash(
    phase,
    topicName,
    serverUrl,
    token,
    template,
    isCritical,
    claim,
    isFirstMessageReceived,
    isAnalyticsOn,
    isExample,
    mintFailure,
    ringingIncidentId,
  );

  /// Leaves the token and the address out.
  @override
  String toString() =>
      'HookUpState(phase: ${phase.name}, '
      'hasToken: ${token != null}, '
      'isFirstMessageReceived: $isFirstMessageReceived, '
      'isAnalyticsOn: $isAnalyticsOn, isExample: $isExample)';
}
