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

  /// Saves the id of the incident the server just opened.
  Future<void> hold(String incidentId);

  /// The alarm the user's first hook-up message set off. Setup asked for
  /// that message, so it joins [setupIncidentIds]. It is not a test.
  Future<void> holdFirstMessage(String incidentId);

  /// The close of [incidentId] failed. It stops counting as a setup test
  /// and is kept to be closed later.
  Future<void> markUnclosed(String incidentId);

  /// [incidentId] is closed on the server, or gone from it.
  Future<void> markClosed(String incidentId);

  /// Forgets the tests of this run. Called when setup completes. Ids still
  /// to be closed are kept.
  Future<void> clear();
}
