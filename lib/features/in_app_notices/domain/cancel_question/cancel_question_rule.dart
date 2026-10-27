/// When the cancel question is asked. Pure, so it tests without a clock, a
/// store or a network.
abstract final class CancelQuestionRule {
  /// A failed send is tried again on this many later launches, then dropped.
  static const int maxRetries = 3;

  /// One billing period: the UTC date of the store's expiry instant, written
  /// `2026-10-20`. It comes straight from the parsed instant and never through
  /// `DeviceTimeZone`, so every phone, in any zone, makes the same key. A later
  /// cancel (a new end date) asks again.
  static String keyFor(DateTime endsAtInstant) =>
      endsAtInstant.toUtc().toIso8601String().substring(0, 10);

  /// Asked once per end date. A billing problem is not a cancel, so a plan the
  /// store could not charge is not asked why it was cancelled.
  static bool isDue({
    required DateTime endsAtInstant,
    required String? askedFor,
    bool hasBillingIssue = false,
  }) => !hasBillingIssue && askedFor != keyFor(endsAtInstant);
}
