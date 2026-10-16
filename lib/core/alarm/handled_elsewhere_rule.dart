import 'package:critalarm/core/models/incident.dart';

/// When this phone may stop ringing because the server says the incident is
/// no longer open.
///
/// Every device on a topic rings for the same incident. Once it is
/// acknowledged, closed or expired anywhere, the other phones have to go quiet
/// and drop the ring they set for themselves. Getting that wrong one way keeps
/// a phone ringing for an incident somebody already handled. Getting it wrong
/// the other way silences a phone for an incident nobody handled, which is
/// worse. So only a state the server named stops a ring. A failed check, a
/// timeout or a state this app does not know leaves the ring alone.
///
/// The native halves read the same three words: `StateKindRule.kt` on Android
/// and `RemoteStateCheck` in `ios/Shared/Ack/NativeAckSender.swift`.
abstract final class HandledElsewhereRule {
  /// The state that ends the ring, or null when [state] does not say for
  /// certain that the incident is over here.
  ///
  /// `Incident.isOpen` is not the test: it is false for any word the server
  /// adds later, and a word this app does not know is not an answer.
  static IncidentState? endingState(String? state) => switch (state) {
    IncidentStates.acked => IncidentState.acked,
    IncidentStates.closed => IncidentState.closed,
    IncidentStates.expired => IncidentState.expired,
    _ => null,
  };

  /// True when [held], a copy of the incident from the shared list, says
  /// the incident ringing on screen ([ringing]) is over.
  ///
  /// The list can be older than the ring. With no signal it is filled from
  /// the phone's own store, and a store copy can hold an earlier stage of the
  /// same incident: acknowledged, then reopened by the desk timer and ringing
  /// again now. A reopen moves `opened_at` (api.md §5.1), so a copy only
  /// counts when it carries the same `opened_at` as the ring and is not older
  /// by `updated_at`. A copy with no `opened_at` does not count.
  static bool endsRing({required Incident held, required Incident ringing}) {
    if (held.id != ringing.id) return false;
    if (endingState(held.state) == null) return false;
    final heldOpenedAt = held.openedAt;
    final ringingOpenedAt = ringing.openedAt;
    if (heldOpenedAt == null || ringingOpenedAt == null) return false;
    if (!heldOpenedAt.isAtSameMomentAs(ringingOpenedAt)) return false;
    final heldUpdatedAt = held.updatedAt;
    final ringingUpdatedAt = ringing.updatedAt;
    if (heldUpdatedAt != null &&
        ringingUpdatedAt != null &&
        heldUpdatedAt.isBefore(ringingUpdatedAt)) {
      return false;
    }
    return true;
  }

  /// The word the native side and the Live Activity use for [state].
  static String wireName(IncidentState state) => switch (state) {
    IncidentState.open => IncidentStates.open,
    IncidentState.acked => IncidentStates.acked,
    IncidentState.closed => IncidentStates.closed,
    IncidentState.expired => IncidentStates.expired,
  };
}
