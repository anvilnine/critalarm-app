abstract class HomePromptRepository {
  DateTime? getAccountPromptDismissedAt();
  Future<void> dismissAccountPrompt();

  /// When "Not now" was last tapped on the Pro sheet.
  DateTime? getProPromptDismissedAt();

  /// How many times "Not now" has been tapped on the Pro sheet. The second
  /// one turns the sheet off for good.
  int getProPromptDismissCount();

  /// Records a "Not now": stores the time and adds one to the count.
  Future<void> dismissProPrompt();

  DateTime? getLastBannerResolvedOrDismissedAt();
  Future<void> markBannerResolvedOrDismissed();
}
