import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:flutter/foundation.dart';

/// Why this phone thinks it missed an alarm. Most specific first.
///
/// Each one is a claim about the phone, so each needs a record behind it.
/// [unanswered] needs none: the server says the incident ran out with no
/// acknowledgement, and that is all it says.
enum MissedReason {
  /// The phone kept a full record over the time the incident rang, and no
  /// push for it is in there.
  noPushReached('no_push'),

  /// A push for the incident is on record, and so is the phone not starting
  /// the alarm for it.
  pushButNoRing('push_no_ring'),

  /// The alarm was set off on this phone, and nobody acknowledged it before
  /// it expired.
  rangUnanswered('rang'),

  /// The phone cannot tell which of the others it was.
  unanswered('unanswered');

  const MissedReason(this.code);

  /// Saved nowhere, but read by the screens to pick words. A shipped code
  /// never changes.
  final String code;
}

/// Why an incident does not count as missed.
enum NotMissedReason {
  /// Open or acknowledged and still going. Only a finished incident counts.
  stillOpen,

  /// Somebody acknowledged it, and not on this phone as far as it knows.
  acknowledgedElsewhere,

  /// It was acknowledged on this phone, whether or not the server heard.
  acknowledgedHere,

  /// The topic is not critical, or it is not known to be.
  topicNotCritical,

  /// No priority 5 message is in what the app holds for it.
  belowPriorityFive,

  /// The incident has no opening time, so nothing can be compared.
  timeUnknown,

  /// It opened before this install first ran.
  beforeFirstLaunch,

  /// It opened before setup was done on this phone.
  setupUnfinished,

  /// It opened before this phone was connected to the server it is on.
  notConnected,

  /// Setup rang it on purpose.
  setupTest,
}

/// What the phone has on record about one incident.
///
/// Every field is false until something on the phone says otherwise, so a
/// phone that knows nothing answers [MissedReason.unanswered].
@immutable
final class PhoneKnowledge {
  const PhoneKnowledge({
    this.acknowledgedHere = false,
    this.rang = false,
    this.pushReached = false,
    this.ringKnownNotStarted = false,
    this.silenceMeansNoPush = false,
  });

  /// Nothing on record.
  static const none = PhoneKnowledge();

  /// An acknowledgement made on this phone is on record.
  final bool acknowledgedHere;

  /// The alarm for this incident was set off on this phone.
  final bool rang;

  /// A push that names this incident reached the phone.
  final bool pushReached;

  /// The phone recorded that it did not start the alarm for that push. Only
  /// means something next to [pushReached].
  final bool ringKnownNotStarted;

  /// The phone recorded every push over the whole time the incident rang,
  /// and nothing in that stretch could be this incident's. Without this, no
  /// record of a push is only no record.
  final bool silenceMeansNoPush;

  @override
  bool operator ==(Object other) =>
      other is PhoneKnowledge &&
      other.acknowledgedHere == acknowledgedHere &&
      other.rang == rang &&
      other.pushReached == pushReached &&
      other.ringKnownNotStarted == ringKnownNotStarted &&
      other.silenceMeansNoPush == silenceMeansNoPush;

  @override
  int get hashCode => Object.hash(
    acknowledgedHere,
    rang,
    pushReached,
    ringKnownNotStarted,
    silenceMeansNoPush,
  );
}

/// The three moments an incident has to come after to count. A null one is
/// not known, and then nothing counts.
@immutable
final class MissedAlarmCutoffs {
  const MissedAlarmCutoffs({
    required this.firstLaunchAt,
    required this.setupDoneAt,
    required this.connectedSince,
  });

  /// When this install first ran.
  final DateTime? firstLaunchAt;

  /// When this phone first saw setup done.
  final DateTime? setupDoneAt;

  /// When this phone first saw itself connected to the server it is on now.
  final DateTime? connectedSince;
}

/// The answer for one incident: missed with one reason, or not missed.
@immutable
final class MissedVerdict {
  const MissedVerdict.missed(MissedReason this.reason) : notMissed = null;
  const MissedVerdict.notMissed(NotMissedReason this.notMissed) : reason = null;

  final MissedReason? reason;
  final NotMissedReason? notMissed;

  bool get isMissed => reason != null;

  @override
  bool operator ==(Object other) =>
      other is MissedVerdict &&
      other.reason == reason &&
      other.notMissed == notMissed;

  @override
  int get hashCode => Object.hash(reason, notMissed);

  @override
  String toString() =>
      isMissed ? 'missed(${reason!.name})' : 'notMissed(${notMissed!.name})';
}

/// Did this phone miss [incident], and if so, why.
///
/// Missed means the server let it run out (`expired`) with no
/// acknowledgement from anyone, on a critical topic, at priority 5, after
/// this phone was set up and connected. The reason is the most specific one
/// the phone has a record for. When it cannot tell two apart it answers
/// [MissedReason.unanswered] and names no cause.
///
/// [topicIsCritical] is null when the topic is gone or the list could not be
/// read, and that counts as not critical. [isSetupTest] is true for an alarm
/// setup rang on purpose.
MissedVerdict missedVerdictFor({
  required Incident incident,
  required bool? topicIsCritical,
  required PhoneKnowledge knowledge,
  required MissedAlarmCutoffs cutoffs,
  bool isSetupTest = false,
}) {
  if (incident.isOpen || incident.isAcked) {
    return const MissedVerdict.notMissed(NotMissedReason.stillOpen);
  }
  if (knowledge.acknowledgedHere) {
    return const MissedVerdict.notMissed(NotMissedReason.acknowledgedHere);
  }
  // A closed incident was acknowledged first (the server only closes an
  // acknowledged one), and an expired one that carries an acknowledgement
  // had somebody up for it.
  if (!incident.isExpired || incident.ackedAt != null) {
    return const MissedVerdict.notMissed(NotMissedReason.acknowledgedElsewhere);
  }
  if (topicIsCritical != true) {
    return const MissedVerdict.notMissed(NotMissedReason.topicNotCritical);
  }
  if (!incident.messages.any((message) => message.priority >= 5)) {
    return const MissedVerdict.notMissed(NotMissedReason.belowPriorityFive);
  }
  final openedAt = incident.openedAt;
  if (openedAt == null) {
    return const MissedVerdict.notMissed(NotMissedReason.timeUnknown);
  }
  final firstLaunchAt = cutoffs.firstLaunchAt;
  if (firstLaunchAt == null || openedAt.isBefore(firstLaunchAt)) {
    return const MissedVerdict.notMissed(NotMissedReason.beforeFirstLaunch);
  }
  final setupDoneAt = cutoffs.setupDoneAt;
  if (setupDoneAt == null || openedAt.isBefore(setupDoneAt)) {
    return const MissedVerdict.notMissed(NotMissedReason.setupUnfinished);
  }
  final connectedSince = cutoffs.connectedSince;
  if (connectedSince == null || openedAt.isBefore(connectedSince)) {
    return const MissedVerdict.notMissed(NotMissedReason.notConnected);
  }
  if (isSetupTest) {
    return const MissedVerdict.notMissed(NotMissedReason.setupTest);
  }

  if (knowledge.rang) {
    return const MissedVerdict.missed(MissedReason.rangUnanswered);
  }
  if (knowledge.pushReached) {
    // A push with no word on whether the alarm started could be either of
    // two reasons, so neither is named.
    return MissedVerdict.missed(
      knowledge.ringKnownNotStarted
          ? MissedReason.pushButNoRing
          : MissedReason.unanswered,
    );
  }
  if (knowledge.silenceMeansNoPush) {
    return const MissedVerdict.missed(MissedReason.noPushReached);
  }
  return const MissedVerdict.missed(MissedReason.unanswered);
}
