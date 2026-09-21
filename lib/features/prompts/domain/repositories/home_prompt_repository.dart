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

  /// When the home screen first opened on this install. Day counts for the
  /// consent sheet and the review popup start here.
  DateTime? getFirstSeenAt();

  /// Stamps the first time home opens. Does nothing after that.
  Future<void> markFirstSeen();

  /// When the analytics and crash report sheet was shown. It shows once.
  DateTime? getConsentAskedAt();
  Future<void> markConsentAsked();

  /// When the store review popup was last asked for. The store decides
  /// whether it really showed, so asking is what counts.
  DateTime? getReviewAskedAt();
  int getReviewAskCount();

  /// Records an ask: stores the time and adds one to the count.
  Future<void> markReviewAsked();

  /// When an alarm was last acknowledged from inside the app.
  DateTime? getLastAcknowledgedAt();
  Future<void> markAcknowledged();
}
