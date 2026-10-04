import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';

/// Whether an alarm is the user's own use of the app, as opposed to one
/// setup itself caused.
///
/// Setup rings the phone on purpose: the test the server sends, the test of
/// this phone only, and the alarm the first hook-up message sets off. None
/// of those says anything about how the app is being used, so none counts
/// toward a rule that waits for real use: the Local reminders sheet, the
/// Hosted sheet after an acknowledged alarm, the rating and feedback asks,
/// the fire drill and the morning-after reminder.
///
/// Matched by incident id and nothing else. [setupIncidentIds] is
/// `SetupTestRing.setupIncidentIds`, which outlives setup because the
/// acknowledgement often comes after it.
///
/// A test sent later from Settings is not decided here. It is a test, and
/// the rules already treat it as one.
bool countsAsRealUse({
  required String? incidentId,
  required Set<String> setupIncidentIds,
}) {
  if (incidentId == null || incidentId.isEmpty) return false;
  if (incidentId == phoneOnlyTestIncidentId) return false;
  return !setupIncidentIds.contains(incidentId);
}

/// The newest acknowledgement among [acks] that counts as real use, or
/// null when none does. Each entry is an incident id and its `acked_at`.
DateTime? newestRealAckedAt({
  required Iterable<({String id, DateTime? ackedAt})> acks,
  required Set<String> setupIncidentIds,
}) {
  DateTime? newest;
  for (final ack in acks) {
    final at = ack.ackedAt;
    if (at == null) continue;
    if (!countsAsRealUse(
      incidentId: ack.id,
      setupIncidentIds: setupIncidentIds,
    )) {
      continue;
    }
    if (newest == null || at.isAfter(newest)) newest = at;
  }
  return newest;
}
