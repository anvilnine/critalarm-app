import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/features/local_reminders/domain/incident_kinds.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/setup_test_ring.dart';

/// The id and topic of the alarm the phone sets for itself. Neither exists
/// on a server.
const String phoneOnlyTestIncidentId = IncidentKinds.demoIncidentId;
const String phoneOnlyTestTopic = IncidentKinds.demoTopic;

/// What an acknowledged alarm proved, when it was a test run during setup.
enum SetupTestKind {
  /// The server opened the incident and the push carried it here: the
  /// server, the push path and this phone all work.
  serverSent,

  /// The phone set the alarm for itself. Only this phone was tested.
  phoneOnly,

  /// Not a setup test.
  none,
}

/// Says which test, if any, the alarm for [incidentId] was.
///
/// Matched by incident id and nothing else. A topic's name never decides
/// it: a real topic may be called anything, and its alarms are real.
///
/// [setupTestIncidentIds] are the ids the server answered when setup asked
/// it to ring this phone. They are saved, so an alarm that started the app
/// from cold is still recognised when nothing else is in memory. An id
/// whose close failed is not in the set, so a later ring from it is not
/// taken for a test.
SetupTestKind setupTestKind({
  required String? incidentId,
  required Set<String> setupTestIncidentIds,
}) {
  if (incidentId == null || incidentId.isEmpty) return SetupTestKind.none;
  if (incidentId == phoneOnlyTestIncidentId) return SetupTestKind.phoneOnly;
  if (setupTestIncidentIds.contains(incidentId)) {
    return SetupTestKind.serverSent;
  }
  return SetupTestKind.none;
}

/// One link of the chain an alarm travels: the sender, the push, the phone.
enum ProofPoint {
  /// The user's own tool sent the message.
  toolSent,

  /// The server and the push carried it to this phone.
  delivered,

  /// The server sent the alarm.
  serverSent,

  /// The push carried it to this phone.
  pushArrived,

  /// This phone rang.
  phoneRang,
}

/// One line of the list the acknowledged screen shows after a setup test:
/// a link of the chain, and whether this alarm proved it.
typedef ProofLine = ({ProofPoint point, bool isProved});

/// What an acknowledged setup test proved, in the order the screen lists
/// it. What was proved comes first.
///
/// The test of this phone only proves the phone and nothing else, so the
/// server and the push are listed as not proved. Nobody should take it for
/// the full test.
List<ProofLine> setupProofFor(SetupTestKind kind) => switch (kind) {
  SetupTestKind.serverSent => const [
    (point: ProofPoint.serverSent, isProved: true),
    (point: ProofPoint.pushArrived, isProved: true),
    (point: ProofPoint.phoneRang, isProved: true),
  ],
  SetupTestKind.phoneOnly => const [
    (point: ProofPoint.phoneRang, isProved: true),
    (point: ProofPoint.serverSent, isProved: false),
    (point: ProofPoint.pushArrived, isProved: false),
  ],
  SetupTestKind.none => const [],
};

/// What an incident is to the first tool alarm on record.
enum FirstToolVerdict {
  /// Another incident, or nothing is on record.
  notIt,

  /// The alarm the first hook-up message set off, still in its first ring
  /// or acknowledged once and not rung since. Its acknowledged screen is
  /// the setup one.
  firstRing,

  /// The same id, but no longer that first ring: it reopened, took in
  /// another message, or is finished. From here on it is an alarm like any
  /// other, and the record is to be forgotten.
  over,
}

/// How far past the moment the hook-up step heard the alarm an `opened_at`
/// may be and still be the first ring. A reopen moves `opened_at` to the
/// time of the reopen, which is a desk timer later.
const Duration firstToolOpenedAtSlack = Duration(seconds: 30);

/// Decides whether [incident] is still the first ring of the alarm the
/// user's first hook-up message set off.
///
/// The server keeps one id for an incident's whole life, so the id is only
/// the start. It is [FirstToolVerdict.over] as soon as anything says this
/// is a later ring: the incident is closed or expired, it is open again
/// after its first acknowledgement, its `opened_at` or `last_message_at`
/// is not what the alarm screen first saw, or its `opened_at` is later
/// than the hook-up step heard it.
///
/// When in doubt it answers over: the cost is the normal acknowledged
/// screen, which has every control. The other mistake would put a
/// celebration over a real alarm.
FirstToolVerdict firstToolVerdictFor({
  required FirstToolAlarm? held,
  required Incident incident,
}) {
  if (held == null || held.incidentId != incident.id) {
    return FirstToolVerdict.notIt;
  }
  if (!incident.isOpen && !incident.isAcked) return FirstToolVerdict.over;
  if (held.wasAcked && incident.isOpen) return FirstToolVerdict.over;

  final openedAt = incident.openedAt;
  final seenOpenedAt = held.openedAt;
  if (openedAt != null) {
    if (seenOpenedAt != null && !openedAt.isAtSameMomentAs(seenOpenedAt)) {
      return FirstToolVerdict.over;
    }
    if (openedAt.isAfter(held.heldAt.add(firstToolOpenedAtSlack))) {
      return FirstToolVerdict.over;
    }
  }
  final lastMessageAt = incident.lastMessageAt;
  final seenLastMessageAt = held.lastMessageAt;
  if (lastMessageAt != null &&
      seenLastMessageAt != null &&
      !lastMessageAt.isAtSameMomentAs(seenLastMessageAt)) {
    return FirstToolVerdict.over;
  }
  // More than one message was never the first ring of one curl line.
  if (incident.messages.length > 1) return FirstToolVerdict.over;
  return FirstToolVerdict.firstRing;
}

/// What the alarm of the user's first hook-up message proved: their own
/// tool reached the server, the server and the push delivered it, and this
/// phone rang. Nothing is left untested.
const List<ProofLine> firstToolAlarmProof = [
  (point: ProofPoint.toolSent, isProved: true),
  (point: ProofPoint.delivered, isProved: true),
  (point: ProofPoint.phoneRang, isProved: true),
];

/// The buttons under the acknowledged screen.
enum AckedExits {
  /// A real incident: At my desk, open the topic, back to topics.
  incident,

  /// A setup test on a flow that has the real ring step. One Continue button
  /// that finishes the step. The flow decides what comes next.
  continueSetup,

  /// The alarm the user's own tool set off from the last setup step. Not a
  /// test: a real incident, and the proof setup was after. One button that
  /// ends that one incident and goes Home.
  firstToolAlarm,

  /// A test run after setup was over. One button back out.
  retest,

  /// The first shipped order, with no topic made yet: create one, or finish.
  legacyCreateTopicOrFinish,

  /// The first shipped order, with a topic already made: finish.
  legacyFinish;

  /// Whether the alarm is one of setup's own tests, sent by the server for
  /// setup or set by the phone for itself. The ringing screen leaves out
  /// the way to the topic for those. The first tool alarm is not one: it
  /// rings with every control a real alarm has.
  bool get isSetupTest =>
      this != AckedExits.incident && this != AckedExits.firstToolAlarm;

  /// Whether a button on this screen ends setup itself. Everywhere else the
  /// flow engine does it, when no step is left.
  bool get completesSetup =>
      this == AckedExits.legacyCreateTopicOrFinish ||
      this == AckedExits.legacyFinish;
}

/// Picks the exits for an acknowledged alarm.
///
/// [flowHasRealRing] is whether the flow the user is in lists the real ring
/// step. The first shipped order does not, and keeps the exits it always had.
///
/// [isFirstToolAlarm] is whether this incident is the one the user's first
/// hook-up message set off in a setup run, matched by its incident id. It
/// is never true for a user who left setup early or had finished it before:
/// the hook-up step is what records that id. Any other alarm, during setup
/// or after it, from any topic, is an [AckedExits.incident].
AckedExits ackedExitsFor({
  required SetupTestKind kind,
  required bool isOnboardingDone,
  required bool flowHasRealRing,
  required bool hasOwnedTopic,
  bool isFirstToolAlarm = false,
}) {
  if (kind == SetupTestKind.none) {
    return isFirstToolAlarm ? AckedExits.firstToolAlarm : AckedExits.incident;
  }
  if (isOnboardingDone) {
    // A server-sent incident met after setup is a real one to answer.
    return kind == SetupTestKind.phoneOnly
        ? AckedExits.retest
        : AckedExits.incident;
  }
  if (flowHasRealRing) return AckedExits.continueSetup;
  return hasOwnedTopic
      ? AckedExits.legacyFinish
      : AckedExits.legacyCreateTopicOrFinish;
}
