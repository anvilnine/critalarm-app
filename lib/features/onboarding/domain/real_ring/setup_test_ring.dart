import 'package:flutter/foundation.dart';

/// The alarm the user's first hook-up message set off, as the phone
/// remembers it while that alarm is still in its first ring.
///
/// The server keeps one id for an incident's whole life: a later message
/// joins it, and its desk timer reopens it under the same id. So the id
/// alone does not say "the first ring". The rest of this record does.
@immutable
class FirstToolAlarm {
  const FirstToolAlarm({
    required this.incidentId,
    required this.heldAt,
    this.openedAt,
    this.lastMessageAt,
    this.wasAcked = false,
  });

  final String incidentId;

  /// When the hook-up step heard the alarm, by this phone's clock.
  final DateTime heldAt;

  /// The incident's `opened_at` the first time the alarm screen showed it.
  /// A reopen moves it. Null until the screen has shown it.
  final DateTime? openedAt;

  /// Its `last_message_at` at that same moment. A message that joins the
  /// incident moves it.
  final DateTime? lastMessageAt;

  /// The user has acknowledged it once on the alarm screen.
  final bool wasAcked;

  /// Whether the alarm screen has shown it yet.
  bool get wasSeen => openedAt != null || lastMessageAt != null;

  @override
  bool operator ==(Object other) =>
      other is FirstToolAlarm &&
      other.incidentId == incidentId &&
      other.heldAt == heldAt &&
      other.openedAt == openedAt &&
      other.lastMessageAt == lastMessageAt &&
      other.wasAcked == wasAcked;

  @override
  int get hashCode =>
      Object.hash(incidentId, heldAt, openedAt, lastMessageAt, wasAcked);
}

/// The test alarms setup asked the server to send, kept for the steps after
/// the ring.
///
/// Only incident ids are held, and they are written to the phone: an alarm
/// can start the app from cold, and the screen that follows the ring still
/// has to know the incident was a setup test.
abstract interface class SetupTestRing {
  /// The id the server answered for the newest setup test, or null before a
  /// test was sent and after [clear]. The step after the ring reads it as
  /// the point to look for newer alarms from.
  String? get incidentId;

  /// Every test incident of this setup run that still counts as one. Try
  /// again sends a second test, and the first one can still ring late, so
  /// each id is kept. An id leaves the set when its close failed
  /// ([markUnclosed]) and when setup completes.
  Set<String> get incidentIds;

  /// Test incidents the server would not close. They are still open or
  /// acknowledged there, so they can ring again. They are no longer setup
  /// tests: a ring from one proves nothing. They outlive [clear], so the
  /// next app open can close them.
  Set<String> get unclosedIds;

  /// Every incident setup itself caused: each test it asked the server to
  /// send, and the alarm the first hook-up message set off. Kept after
  /// [clear], because their acknowledgements come after setup is over and
  /// must never count as real use (`countsAsRealUse`).
  Set<String> get setupIncidentIds;

  /// The alarm the user's first hook-up message set off, while it still
  /// has its own acknowledged screen to show: the one that ends setup. Null
  /// before that alarm and once it is forgotten ([forgetFirstTool]): its
  /// button was used, the incident rang a second time or took in another
  /// message, setup ended some other way, or the app was opened again
  /// after the first acknowledgement. Kept after [clear], because setup is
  /// already complete when that alarm is answered.
  FirstToolAlarm? get firstTool;

  /// The id of [firstTool], or null.
  String? get firstToolIncidentId;

  /// Saves the id of the incident the server just opened.
  Future<void> hold(String incidentId);

  /// The alarm the user's first hook-up message set off. Setup asked for
  /// that message, so it joins [setupIncidentIds] and becomes
  /// [firstToolIncidentId]. It is not a test.
  Future<void> holdFirstMessage(String incidentId);

  /// The alarm screen showed [firstTool] in its first ring: what the
  /// incident looked like then is kept, so a later ring is told apart.
  /// Does nothing with no first tool alarm on record.
  Future<void> noteFirstToolSeen({
    required DateTime? openedAt,
    required DateTime? lastMessageAt,
  });

  /// The user acknowledged [firstTool] on the alarm screen.
  Future<void> noteFirstToolAcked();

  /// The first tool alarm's own acknowledged screen is done with, or is no
  /// longer owed. From now on that incident is like any other.
  Future<void> forgetFirstTool();

  /// The app was opened. A first tool alarm already acknowledged in an
  /// earlier run had its moment: it is forgotten. One not yet acknowledged
  /// is kept, because the alarm itself may be what opened the app.
  Future<void> settleFirstToolAtLaunch();

  /// The close of [incidentId] failed. It stops counting as a setup test
  /// and is kept to be closed later.
  Future<void> markUnclosed(String incidentId);

  /// [incidentId] is closed on the server, or gone from it.
  Future<void> markClosed(String incidentId);

  /// Forgets the tests of this run. Called when setup completes. Ids still
  /// to be closed are kept.
  Future<void> clear();
}
