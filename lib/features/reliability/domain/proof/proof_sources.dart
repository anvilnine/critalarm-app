import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/features/local_reminders/domain/incident_kinds.dart';
import 'package:critalarm/features/reliability/domain/proof/proof_entry.dart';

/// Whether [incident] is a test alarm the server sent: a message with the
/// test route's title. Onboarding's demo alarm is not one, and neither is a
/// real incident.
bool proofIsServerTest(Incident incident) =>
    incident.id != IncidentKinds.demoIncidentId &&
    incident.topic != IncidentKinds.demoTopic &&
    incident.messages.any((m) => m.title == IncidentKinds.testAlarmTitle);

/// What a weekly check answer from the relay adds to the log.
///
/// - A `lastReceivedAt` marks `rang` for the week of that second.
/// - `misses` of one or more with a `lastSentAt` marks `failed` for the week
///   of that second. A `rang` in the same week still wins when the two are
///   merged.
List<ProofEntry> proofEntriesFromWeeklyCheck(WeeklyCheck check) {
  DateTime at(int seconds) =>
      DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  final received = check.lastReceivedAt;
  final sent = check.lastSentAt;
  return [
    if (received != null) ProofEntry.rang(at(received)),
    if (check.misses >= 1 && sent != null) ProofEntry.failed(at(sent)),
  ];
}
