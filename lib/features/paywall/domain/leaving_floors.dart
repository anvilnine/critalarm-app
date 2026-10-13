/// The floors of the leaving paywall's numbers, in one place so they can be
/// tuned. A first guess. A row under its floor is left off the slip.
abstract final class LeavingFloors {
  /// Alarms that rang in the window.
  static const int alarmsRang = 10;

  /// Alarms answered, and the share of what rang they must be.
  static const int answered = 10;
  static const int answeredPercent = 80;

  /// Distinct nights with an alarm between midnight and [nightEndsAtHour].
  static const int nights = 3;

  /// Critical topics on now.
  static const int criticalTopics = 3;

  /// All Hosted keeps. The slip counts these days back.
  static const int windowDays = 90;

  /// A night runs from 00:00 up to but not including this hour, local time.
  static const int nightEndsAtHour = 6;

  /// The least rows a slip needs to be a receipt. Fewer opens Wipe.
  static const int rowsForReceipt = 2;
}
