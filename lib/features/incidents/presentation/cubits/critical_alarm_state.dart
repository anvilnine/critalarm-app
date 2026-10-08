import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';
import 'package:flutter/foundation.dart';

enum CriticalAlarmStatus {
  initial,
  loading,
  ringing,
  acknowledged,
  closed,
  failure,
}

/// State for the Critical Alarm screen.
@immutable
class CriticalAlarmState {
  const CriticalAlarmState({
    this.status = CriticalAlarmStatus.initial,
    this.incident,
    this.openIncidents = const <Incident>[],
    this.topic = '',
    this.word = '',
    this.subtext = '',
    this.ringTimeSpoken = '',
    this.title = '',
    this.body = '',
    this.meta = '',
    this.severityMode = SeverityMode.none,
    this.faceState = FaceState.calm,
    this.isLive = false,
    this.isAcknowledged = false,
    this.isAcknowledging = false,
    this.feedbackMessage,
    this.errorMessage,
    this.isOnboardingDone = false,
    this.hasOwnedTopic = false,
    this.setupTestIncidentIds = const <String>{},
    this.setupFlowHasRealRing = false,
    this.firstToolIncidentId,
    this.isPreview = false,
    this.unloadedIncidentId,
    this.isCloseQueued = false,
  });

  final CriticalAlarmStatus status;
  final Incident? incident;

  /// The open incidents still ringing, newest first by [Incident.openedAt].
  final List<Incident> openIncidents;
  final String topic;
  final String word;
  final String subtext;

  /// How long the alarm has been ringing, as a screen reader says it. Whole
  /// minutes, so it changes once a minute while [subtext] counts seconds.
  /// Empty when nothing is ringing.
  final String ringTimeSpoken;
  final String title;
  final String body;
  final String meta;
  final SeverityMode severityMode;
  final FaceState faceState;
  final bool isLive;
  final bool isAcknowledged;
  final bool isAcknowledging;
  final String? feedbackMessage;
  final String? errorMessage;

  /// True when onboarding was already finished before this alarm rang.
  /// Only the demo alarm reads it: a test fired from Settings ends on one
  /// Finish button, while onboarding's own test still ends on the two
  /// buttons that start the first topic.
  final bool isOnboardingDone;

  /// Only the demo alarm reads it: with a topic already made, the
  /// celebration has no first topic to offer.
  final bool hasOwnedTopic;

  /// The incidents the server opened when setup asked it to ring this
  /// phone. Empty when no such test was sent, and once setup is complete.
  final Set<String> setupTestIncidentIds;

  /// Whether the setup flow the user is in has the real ring step. The
  /// first shipped order does not, and keeps its own exits.
  final bool setupFlowHasRealRing;

  /// The incident the user's first hook-up message set off, while its own
  /// acknowledged screen is still owed. Null for everyone who left setup
  /// early or finished it before, and once that screen's button was used.
  final String? firstToolIncidentId;

  /// A developer's look at a screen: nothing on it reaches the server.
  final bool isPreview;

  /// The incident the screen was opened for and could not load, while it
  /// can still be closed from here: the server did not answer, and this
  /// phone is not ringing for it. Null in every other state.
  ///
  /// It is what keeps "At my desk" on screen with no signal. The Done
  /// button on a card can open the app instead of closing, and a person
  /// who lands here must still be able to close.
  final String? unloadedIncidentId;

  /// The close could not reach the server and is waiting in the ack queue.
  final bool isCloseQueued;

  /// Whether the alarm on screen is the first tool alarm of a setup run.
  /// Matched by incident id and nothing else.
  bool get isFirstToolAlarm {
    final id = incident?.id;
    return id != null && id.isNotEmpty && id == firstToolIncidentId;
  }

  /// Which setup test the alarm on screen was, if any.
  SetupTestKind get setupTest => setupTestKind(
    incidentId: incident?.id,
    setupTestIncidentIds: setupTestIncidentIds,
  );

  /// The buttons the acknowledged screen ends on.
  AckedExits get ackedExits => ackedExitsFor(
    kind: setupTest,
    isOnboardingDone: isOnboardingDone,
    flowHasRealRing: setupFlowHasRealRing,
    hasOwnedTopic: hasOwnedTopic,
    isFirstToolAlarm: isFirstToolAlarm,
  );

  CriticalAlarmState copyWith({
    CriticalAlarmStatus? status,
    Incident? incident,
    List<Incident>? openIncidents,
    String? topic,
    String? word,
    String? subtext,
    String? ringTimeSpoken,
    String? title,
    String? body,
    String? meta,
    SeverityMode? severityMode,
    FaceState? faceState,
    bool? isLive,
    bool? isAcknowledged,
    bool? isAcknowledging,
    String? feedbackMessage,
    String? errorMessage,
    bool? isOnboardingDone,
    bool? hasOwnedTopic,
    Set<String>? setupTestIncidentIds,
    bool? setupFlowHasRealRing,
    String? firstToolIncidentId,
    bool? isPreview,
    bool? isCloseQueued,
    bool clearFirstTool = false,
    bool clearError = false,
    bool clearFeedback = false,
  }) {
    return CriticalAlarmState(
      status: status ?? this.status,
      incident: incident ?? this.incident,
      openIncidents: openIncidents ?? this.openIncidents,
      topic: topic ?? this.topic,
      word: word ?? this.word,
      subtext: subtext ?? this.subtext,
      ringTimeSpoken: ringTimeSpoken ?? this.ringTimeSpoken,
      title: title ?? this.title,
      body: body ?? this.body,
      meta: meta ?? this.meta,
      severityMode: severityMode ?? this.severityMode,
      faceState: faceState ?? this.faceState,
      isLive: isLive ?? this.isLive,
      isAcknowledged: isAcknowledged ?? this.isAcknowledged,
      isAcknowledging: isAcknowledging ?? this.isAcknowledging,
      feedbackMessage: clearFeedback
          ? null
          : (feedbackMessage ?? this.feedbackMessage),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isOnboardingDone: isOnboardingDone ?? this.isOnboardingDone,
      hasOwnedTopic: hasOwnedTopic ?? this.hasOwnedTopic,
      setupTestIncidentIds: setupTestIncidentIds ?? this.setupTestIncidentIds,
      setupFlowHasRealRing: setupFlowHasRealRing ?? this.setupFlowHasRealRing,
      firstToolIncidentId: clearFirstTool
          ? null
          : (firstToolIncidentId ?? this.firstToolIncidentId),
      isPreview: isPreview ?? this.isPreview,
      unloadedIncidentId: unloadedIncidentId,
      isCloseQueued: isCloseQueued ?? this.isCloseQueued,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CriticalAlarmState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          incident == other.incident &&
          listEquals(openIncidents, other.openIncidents) &&
          topic == other.topic &&
          word == other.word &&
          subtext == other.subtext &&
          ringTimeSpoken == other.ringTimeSpoken &&
          title == other.title &&
          body == other.body &&
          meta == other.meta &&
          severityMode == other.severityMode &&
          faceState == other.faceState &&
          isLive == other.isLive &&
          isAcknowledged == other.isAcknowledged &&
          isAcknowledging == other.isAcknowledging &&
          feedbackMessage == other.feedbackMessage &&
          errorMessage == other.errorMessage &&
          isOnboardingDone == other.isOnboardingDone &&
          hasOwnedTopic == other.hasOwnedTopic &&
          setEquals(setupTestIncidentIds, other.setupTestIncidentIds) &&
          setupFlowHasRealRing == other.setupFlowHasRealRing &&
          firstToolIncidentId == other.firstToolIncidentId &&
          isPreview == other.isPreview &&
          unloadedIncidentId == other.unloadedIncidentId &&
          isCloseQueued == other.isCloseQueued;

  @override
  int get hashCode => Object.hash(
    status,
    incident,
    Object.hashAll(openIncidents),
    topic,
    word,
    subtext,
    title,
    body,
    meta,
    severityMode,
    faceState,
    isLive,
    isAcknowledged,
    isAcknowledging,
    feedbackMessage,
    errorMessage,
    isOnboardingDone,
    hasOwnedTopic,
    Object.hashAllUnordered(setupTestIncidentIds),
    Object.hash(
      setupFlowHasRealRing,
      firstToolIncidentId,
      isPreview,
      ringTimeSpoken,
      unloadedIncidentId,
      isCloseQueued,
    ),
  );
}
