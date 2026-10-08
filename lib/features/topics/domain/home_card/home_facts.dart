import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/features/topics/domain/home_card/home_card_input.dart';
import 'package:flutter/foundation.dart';

/// What Home knows about alarms and messages, as plain values. The card and
/// the inbox read these instead of working them out again from the lists.
///
/// Every field is a fact about the lists Home holds, with no clock in it: the
/// card rule compares them to its own `now`.
@immutable
class HomeFacts {
  const HomeFacts({
    this.ringing,
    this.acknowledged,
    this.handled,
    this.newestMessageAt,
    this.lastAlarmAt,
    this.warningCount = 0,
  });

  /// No lists, no facts.
  static const none = HomeFacts();

  /// The alarm that is sounding. The newest when several are.
  final RingingFact? ringing;

  /// The acknowledged alarm whose desk timer is still counting, with the
  /// moment it rings again. The newest acknowledgement when several are.
  final AcknowledgedFact? acknowledged;

  /// The alarm closed in the last `handledCardWindow`, with how long the
  /// first answer took. The newest close when several are.
  final HandledFact? handled;

  /// When the newest message on any topic came in. Null with no message.
  final DateTime? newestMessageAt;

  /// The start of the newest alarm that counts as real use. Null when none
  /// does.
  final DateTime? lastAlarmAt;

  /// How many topics have a live warning.
  final int warningCount;

  /// These facts without anything that is live now.
  ///
  /// For a list that is an old copy: a sounding or counting alarm from before
  /// the server stopped answering is not something to say now, and no warning
  /// is either. The times of the past stay.
  HomeFacts withoutLive() => HomeFacts(
    newestMessageAt: newestMessageAt,
    lastAlarmAt: lastAlarmAt,
  );

  @override
  bool operator ==(Object other) =>
      other is HomeFacts &&
      other.ringing == ringing &&
      other.acknowledged == acknowledged &&
      other.handled == handled &&
      other.newestMessageAt == newestMessageAt &&
      other.lastAlarmAt == lastAlarmAt &&
      other.warningCount == warningCount;

  @override
  int get hashCode => Object.hash(
    ringing,
    acknowledged,
    handled,
    newestMessageAt,
    lastAlarmAt,
    warningCount,
  );

  @override
  String toString() =>
      'HomeFacts(ringing: ${ringing?.incidentId}, '
      'acknowledged: ${acknowledged?.incidentId}, '
      'handled: ${handled?.topic}, newest: $newestMessageAt, '
      'last alarm: $lastAlarmAt, warnings: $warningCount)';
}

/// The facts of the lists Home holds.
///
/// - [topics]: the user's topics, for each topic's desk timer.
/// - [incidents]: every incident the app holds.
/// - [warningTopics]: the topics with a live warning.
/// - [messageTimes]: the epoch seconds of every message held, per topic.
/// - [setupIncidentIds]: the alarms setup rang on purpose. They never count
///   as the last alarm.
///
/// Ringing is an open incident with a priority 5 message. When several
/// qualify the one that opened last wins, and an incident with no opening
/// time loses to one that has it.
HomeFacts homeFactsFrom({
  required List<Topic> topics,
  required Iterable<Incident> incidents,
  required Set<String> warningTopics,
  required Map<String, List<int>> messageTimes,
  required DateTime now,
  Set<String> setupIncidentIds = const {},
}) {
  final deskTimerOf = {for (final t in topics) t.name: t.deskTimerS};

  RingingFact? ringing;
  AcknowledgedFact? acknowledged;
  DateTime? acknowledgedSince;
  HandledFact? handled;
  for (final incident in incidents) {
    if (incident.isOpen && incident.messages.any((m) => m.priority == 5)) {
      final fact = RingingFact.fromIncident(incident)!;
      if (ringing == null || _isLater(fact.openedAt, ringing.openedAt)) {
        ringing = fact;
      }
    }

    final ack = AcknowledgedFact.fromIncident(
      incident,
      deskTimerS: deskTimerOf[incident.topic] ?? defaultDeskTimerS,
    );
    if (ack != null && now.isBefore(ack.deadline)) {
      final since = incident.ackedAt;
      if (acknowledged == null || _isLater(since, acknowledgedSince)) {
        acknowledged = ack;
        acknowledgedSince = since;
      }
    }

    final done = HandledFact.fromIncident(incident, now: now);
    if (done != null &&
        (handled == null || done.closedAt.isAfter(handled.closedAt))) {
      handled = done;
    }
  }

  var newestSeconds = 0;
  var hasMessage = false;
  for (final times in messageTimes.values) {
    for (final seconds in times) {
      if (!hasMessage || seconds > newestSeconds) newestSeconds = seconds;
      hasMessage = true;
    }
  }

  return HomeFacts(
    ringing: ringing,
    acknowledged: acknowledged,
    handled: handled,
    newestMessageAt: hasMessage
        ? DateTime.fromMillisecondsSinceEpoch(newestSeconds * 1000)
        : null,
    lastAlarmAt: lastRealAlarmAt(incidents, setupIncidentIds: setupIncidentIds),
    warningCount: warningTopics.length,
  );
}

/// Whether [a] is strictly later than [b]. A missing time is the earliest.
bool _isLater(DateTime? a, DateTime? b) {
  if (a == null) return false;
  if (b == null) return true;
  return a.isAfter(b);
}
