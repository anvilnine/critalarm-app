import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
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
    this.topic = 'prod-db',
    this.word = 'CRITICAL',
    this.subtext = 'Ringing 2 min 14 s. Repeats every 30 s.',
    this.title = 'Primary database down',
    this.body =
        'pg_isready failed 3 times in 90 s. '
        'Replica promoted to primary on db-2.',
    this.meta = 'uptime-kuma / 03:12:04 / postgres, db-1',
    this.severityMode = SeverityMode.crit,
    this.faceState = FaceState.alarmed,
    this.isLive = true,
    this.isAcknowledged = false,
    this.isAcknowledging = false,
    this.isSnoozed = false,
    this.feedbackMessage,
    this.errorMessage,
  });

  final CriticalAlarmStatus status;
  final Incident? incident;
  final String topic;
  final String word;
  final String subtext;
  final String title;
  final String body;
  final String meta;
  final SeverityMode severityMode;
  final FaceState faceState;
  final bool isLive;
  final bool isAcknowledged;
  final bool isAcknowledging;
  final bool isSnoozed;
  final String? feedbackMessage;
  final String? errorMessage;

  CriticalAlarmState copyWith({
    CriticalAlarmStatus? status,
    Incident? incident,
    String? topic,
    String? word,
    String? subtext,
    String? title,
    String? body,
    String? meta,
    SeverityMode? severityMode,
    FaceState? faceState,
    bool? isLive,
    bool? isAcknowledged,
    bool? isAcknowledging,
    bool? isSnoozed,
    String? feedbackMessage,
    String? errorMessage,
    bool clearError = false,
    bool clearFeedback = false,
  }) {
    return CriticalAlarmState(
      status: status ?? this.status,
      incident: incident ?? this.incident,
      topic: topic ?? this.topic,
      word: word ?? this.word,
      subtext: subtext ?? this.subtext,
      title: title ?? this.title,
      body: body ?? this.body,
      meta: meta ?? this.meta,
      severityMode: severityMode ?? this.severityMode,
      faceState: faceState ?? this.faceState,
      isLive: isLive ?? this.isLive,
      isAcknowledged: isAcknowledged ?? this.isAcknowledged,
      isAcknowledging: isAcknowledging ?? this.isAcknowledging,
      isSnoozed: isSnoozed ?? this.isSnoozed,
      feedbackMessage: clearFeedback
          ? null
          : (feedbackMessage ?? this.feedbackMessage),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CriticalAlarmState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          incident == other.incident &&
          topic == other.topic &&
          word == other.word &&
          subtext == other.subtext &&
          title == other.title &&
          body == other.body &&
          meta == other.meta &&
          severityMode == other.severityMode &&
          faceState == other.faceState &&
          isLive == other.isLive &&
          isAcknowledged == other.isAcknowledged &&
          isAcknowledging == other.isAcknowledging &&
          isSnoozed == other.isSnoozed &&
          feedbackMessage == other.feedbackMessage &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(
    status,
    incident,
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
    isSnoozed,
    feedbackMessage,
    errorMessage,
  );
}
