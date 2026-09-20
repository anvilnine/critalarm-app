abstract class HomePromptRepository {
  DateTime? getAccountPromptDismissedAt();
  Future<void> dismissAccountPrompt();

  /// When the Pro sheet was last put in front of the user, however they left
  /// it. Tapping "See Pro plans", swiping the sheet away and tapping outside
  /// it all count, because all three mean the ask has been made.
  DateTime? getProPromptAskedAt();

  /// Records that the sheet was shown. Called as it opens, so the quiet
  /// period starts whatever the user does next.
  Future<void> markProPromptAsked();

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
