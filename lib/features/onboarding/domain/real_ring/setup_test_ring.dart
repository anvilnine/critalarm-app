/// The test alarm setup asked the server to send, kept for the steps after
/// the ring.
///
/// Only the incident id is held, and it is written to the phone: the alarm
/// can start the app from cold, and the screen that follows the ring still
/// has to know this incident was the setup test. The step after the ring
/// reads the same id as the point to look for newer alarms from.
abstract interface class SetupTestRing {
  /// The id the server answered for the setup test, or null before a test
  /// was sent and after [clear].
  String? get incidentId;

  /// Saves the id of the incident the server just opened.
  Future<void> hold(String incidentId);

  /// Forgets it. Called when setup completes.
  Future<void> clear();
}
