/// Reads whether iOS puts this app's notifications in the Scheduled Summary.
// One method today, and it stays an interface so there is something to fake.
// ignore: one_member_abstracts
abstract interface class ScheduledSummaryReader {
  /// True when the app is in the Scheduled Summary. False when it is not, and
  /// when the phone cannot say. Never throws.
  Future<bool> isInScheduledSummary();
}
