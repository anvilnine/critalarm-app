import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/features/in_app_notices/domain/missed_alarm_notice_rule.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/topics/domain/home_card/handled_window.dart';
import 'package:critalarm/features/topics/domain/setup_checklist.dart';
import 'package:flutter/foundation.dart';

/// How long the list can go without a message before the card says so.
const Duration quietAfter = Duration(days: 7);

/// The desk timer length used when the topic is not known.
const int defaultDeskTimerS = 600;

/// An alarm that is sounding.
@immutable
class RingingFact {
  const RingingFact({
    required this.incidentId,
    required this.topic,
    required this.openedAt,
  });

  /// The facts of [incident], or null when it is not open.
  static RingingFact? fromIncident(Incident incident) {
    if (!incident.isOpen) return null;
    return RingingFact(
      incidentId: incident.id,
      topic: incident.topic,
      openedAt: incident.openedAt,
    );
  }

  final String incidentId;
  final String topic;

  /// Null when the server did not send it.
  final DateTime? openedAt;

  @override
  bool operator ==(Object other) =>
      other is RingingFact &&
      other.incidentId == incidentId &&
      other.topic == topic &&
      other.openedAt == openedAt;

  @override
  int get hashCode => Object.hash(incidentId, topic, openedAt);
}

/// An acknowledged alarm and the moment it rings again.
@immutable
class AcknowledgedFact {
  const AcknowledgedFact({
    required this.incidentId,
    required this.topic,
    required this.deadline,
  });

  /// The facts of [incident], or null when it is not acknowledged or has no
  /// deadline to work out.
  ///
  /// The deadline is the server's `desk_timer_fires_at`. A server that does
  /// not send it gets `ackedAt` plus [deskTimerS].
  static AcknowledgedFact? fromIncident(
    Incident incident, {
    int deskTimerS = defaultDeskTimerS,
  }) {
    if (!incident.isAcked) return null;
    final ackedAt = incident.ackedAt;
    final deadline =
        incident.deskTimerFiresAt ??
        ackedAt?.add(Duration(seconds: deskTimerS));
    if (deadline == null) return null;
    return AcknowledgedFact(
      incidentId: incident.id,
      topic: incident.topic,
      deadline: deadline,
    );
  }

  final String incidentId;
  final String topic;

  /// When the desk timer rings the alarm again.
  final DateTime deadline;

  @override
  bool operator ==(Object other) =>
      other is AcknowledgedFact &&
      other.incidentId == incidentId &&
      other.topic == topic &&
      other.deadline == deadline;

  @override
  int get hashCode => Object.hash(incidentId, topic, deadline);
}

/// An alarm that was closed a moment ago.
@immutable
class HandledFact {
  const HandledFact({
    required this.topic,
    required this.closedAt,
    this.answeredAfter,
  });

  /// The facts of [incident], or null when it was not closed, has no close
  /// time, or closed [handledCardWindow] or more before [now]. An alarm that
  /// ran out is not handled and is never returned.
  ///
  /// [answeredAfter] is `ackedAt - openedAt`. It stays null when either time
  /// is missing, when the incident was closed with no acknowledgement, or
  /// when the times run backwards.
  static HandledFact? fromIncident(Incident incident, {required DateTime now}) {
    if (!incident.isClosed) return null;
    final closedAt = incident.closedAt;
    if (closedAt == null) return null;
    if (now.difference(closedAt) >= handledCardWindow) return null;
    final openedAt = incident.openedAt;
    final ackedAt = incident.ackedAt;
    Duration? answeredAfter;
    if (openedAt != null && ackedAt != null) {
      final gap = ackedAt.difference(openedAt);
      if (!gap.isNegative) answeredAfter = gap;
    }
    return HandledFact(
      topic: incident.topic,
      closedAt: closedAt,
      answeredAfter: answeredAfter,
    );
  }

  final String topic;
  final DateTime closedAt;

  /// How long the first answer took, or null when it is not known.
  final Duration? answeredAfter;

  @override
  bool operator ==(Object other) =>
      other is HandledFact &&
      other.topic == topic &&
      other.closedAt == closedAt &&
      other.answeredAfter == answeredAfter;

  @override
  int get hashCode => Object.hash(topic, closedAt, answeredAfter);
}

/// A missed alarm entry and how long the alarm rang.
@immutable
class MissedFact {
  const MissedFact({required this.notice, this.ringDuration});

  final MissedAlarmNotice notice;

  /// `closedAt - openedAt` of the newest missed incident, or null when the
  /// times are not known.
  final Duration? ringDuration;

  @override
  bool operator ==(Object other) =>
      other is MissedFact &&
      other.notice == notice &&
      other.ringDuration == ringDuration;

  @override
  int get hashCode => Object.hash(notice, ringDuration);
}

/// What the reliability read says.
@immutable
class ReadinessInput {
  const ReadinessInput({
    this.loaded = false,
    this.incomplete = false,
    this.checks = const [],
  });

  /// Nothing read yet. The card draws no count.
  static const notLoaded = ReadinessInput();

  /// The first read has ended.
  final bool loaded;

  /// A source failed to answer, so [checks] has a hole.
  final bool incomplete;

  /// The checks that exist on this phone, in source order.
  final List<ReliabilityCheck> checks;

  @override
  bool operator ==(Object other) =>
      other is ReadinessInput &&
      other.loaded == loaded &&
      other.incomplete == incomplete &&
      listEquals(other.checks, checks);

  @override
  int get hashCode => Object.hash(loaded, incomplete, Object.hashAll(checks));
}

/// The newest start among the incidents, or null when none has one.
///
/// Every alarm the phone holds counts, a test that setup sent included: it
/// rang the phone, History lists it and the Topic screen names it, so the
/// Topics card must not say "no alarm yet" over it. The rules that wait for
/// real use (`countsAsRealUse`) are a different question and do not read this.
DateTime? newestAlarmAt(Iterable<Incident> incidents) {
  DateTime? newest;
  for (final incident in incidents) {
    final openedAt = incident.openedAt;
    if (openedAt == null) continue;
    if (newest == null || openedAt.isAfter(newest)) newest = openedAt;
  }
  return newest;
}

/// Everything the card rule reads. A plain value: the rule has no other
/// input, and no clock of its own.
@immutable
class HomeCardInput {
  const HomeCardInput({
    required this.now,
    this.isLoading = false,
    this.hasServer = true,
    this.isStale = false,
    this.loadFailed = false,
    this.lastKnownGoodAt,
    this.topicCount = 0,
    this.ringing,
    this.acknowledged,
    this.handled,
    this.missed,
    this.warningCount = 0,
    this.readiness = ReadinessInput.notLoaded,
    this.setup,
    this.firstTopic,
    this.watchedTopic,
    this.newestMessageAt,
    this.lastAlarmAt,
    this.hasCriticalTopic = false,
  });

  final DateTime now;

  // Status.

  /// The list has not answered yet.
  final bool isLoading;

  /// A server is saved.
  final bool hasServer;

  /// The list on screen is an old copy.
  final bool isStale;

  /// The list failed to load. With no old copy, [lastKnownGoodAt] is null.
  final bool loadFailed;

  /// When the server last answered.
  final DateTime? lastKnownGoodAt;

  /// How many topics the user owns.
  final int topicCount;

  // Live.

  final RingingFact? ringing;
  final AcknowledgedFact? acknowledged;
  final HandledFact? handled;
  final MissedFact? missed;

  /// How many topics have a live warning.
  final int warningCount;

  // Health.

  final ReadinessInput readiness;

  // Setup.

  /// The setup checklist, or null when there is none.
  final SetupChecklist? setup;

  /// The user's first topic, for the route of the critical-topic row.
  final String? firstTopic;

  /// The topic Home watches for the first message.
  final String? watchedTopic;

  // Quiet and idle.

  /// When the newest message on any topic came in.
  final DateTime? newestMessageAt;

  /// The start of the newest alarm the phone holds ([newestAlarmAt]).
  final DateTime? lastAlarmAt;

  /// Some topic has Critical delivery on.
  final bool hasCriticalTopic;

  @override
  bool operator ==(Object other) =>
      other is HomeCardInput &&
      other.now == now &&
      other.isLoading == isLoading &&
      other.hasServer == hasServer &&
      other.isStale == isStale &&
      other.loadFailed == loadFailed &&
      other.lastKnownGoodAt == lastKnownGoodAt &&
      other.topicCount == topicCount &&
      other.ringing == ringing &&
      other.acknowledged == acknowledged &&
      other.handled == handled &&
      other.missed == missed &&
      other.warningCount == warningCount &&
      other.readiness == readiness &&
      other.setup == setup &&
      other.firstTopic == firstTopic &&
      other.watchedTopic == watchedTopic &&
      other.newestMessageAt == newestMessageAt &&
      other.lastAlarmAt == lastAlarmAt &&
      other.hasCriticalTopic == hasCriticalTopic;

  @override
  int get hashCode => Object.hashAll([
    now,
    isLoading,
    hasServer,
    isStale,
    loadFailed,
    lastKnownGoodAt,
    topicCount,
    ringing,
    acknowledged,
    handled,
    missed,
    warningCount,
    readiness,
    setup,
    firstTopic,
    watchedTopic,
    newestMessageAt,
    lastAlarmAt,
    hasCriticalTopic,
  ]);
}
