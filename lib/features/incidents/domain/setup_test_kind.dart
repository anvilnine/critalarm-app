import 'package:critalarm/features/local_reminders/domain/incident_kinds.dart';

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

/// The buttons under the acknowledged screen.
enum AckedExits {
  /// A real incident: At my desk, open the topic, back to topics.
  incident,

  /// A setup test on a flow that has the real ring step. One Continue button
  /// that finishes the step. The flow decides what comes next.
  continueSetup,

  /// A test run after setup was over. One button back out.
  retest,

  /// The first shipped order, with no topic made yet: create one, or finish.
  legacyCreateTopicOrFinish,

  /// The first shipped order, with a topic already made: finish.
  legacyFinish;

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
AckedExits ackedExitsFor({
  required SetupTestKind kind,
  required bool isOnboardingDone,
  required bool flowHasRealRing,
  required bool hasOwnedTopic,
}) {
  if (kind == SetupTestKind.none) return AckedExits.incident;
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
