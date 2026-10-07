abstract class InAppNoticeRepository {
  DateTime? getAccountNoticeDismissedAt();
  Future<void> dismissAccountNotice();

  /// When the Pro sheet was last put in front of the user, however they left
  /// it. Tapping "See Pro plans", swiping the sheet away and tapping outside
  /// it all count, because all three mean the ask has been made.
  DateTime? getProAskedAt();

  /// Records that the sheet was shown. Called as it opens, so the quiet
  /// period starts whatever the user does next.
  Future<void> markProAsked();

  /// When "Not now" was last tapped on the Pro sheet.
  DateTime? getProAskDismissedAt();

  /// How many times "Not now" has been tapped on the Pro sheet. The second
  /// one turns the sheet off for good.
  int getProAskDismissCount();

  /// Records a "Not now": stores the time and adds one to the count.
  Future<void> dismissProAsk();

  /// When the user first owned a topic on this install. Stamped once, the
  /// first time the topic list is seen with at least one topic. The "Back up
  /// your topics" notice and reminder wait a day from here.
  DateTime? getFirstTopicOwnedAt();

  /// Stamps the first time a topic exists. Does nothing after that.
  Future<void> markFirstTopicOwned();

  /// When the battery optimisation notice was closed on Home. It shows
  /// once, so any value here keeps it off Home for good.
  DateTime? getBatteryNoticeDismissedAt();
  Future<void> dismissBatteryNotice();

  DateTime? getLastNoticeResolvedOrDismissedAt();
  Future<void> markNoticeResolvedOrDismissed();

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

  /// Records an ask: stores the time and adds one to the count. [at] is
  /// when the ask happened; a review reminder (idea 21) passes its fire
  /// time. Defaults to now.
  Future<void> markReviewAsked({DateTime? at});

  /// When the feedback reminder (idea 22) was delivered. It asks once per
  /// install.
  DateTime? getFeedbackAskedAt();

  /// Records the feedback ask at [at], or now.
  Future<void> markFeedbackAsked({DateTime? at});

  /// When "Remind me later" was last tapped on the Pro sheet. Unlike "Not
  /// now" it never counts toward `ProAskRules.maxDismissals`.
  DateTime? getProAskLaterAt();

  /// Records a "Remind me later". The sheet was already marked asked when it
  /// opened, and that is what starts the 30 day wait.
  Future<void> remindProAskLater();

  /// Clears the "Remind me later" once its notification was delivered.
  Future<void> clearProAskLater();

  /// When an alarm was last acknowledged from inside the app.
  DateTime? getLastAcknowledgedAt();
  Future<void> markAcknowledged();

  /// When the first real acknowledge happened on this install. Written once
  /// and never overwritten. A setup ring and a test alarm do not set it.
  DateTime? getFirstRealAcknowledgedAt();

  /// Stamps the first real acknowledge. Does nothing after that.
  Future<void> markFirstRealAcknowledged();

  /// When the day-0 card was first shown on Home. It counts as an ask for the
  /// 24 hour gap, so the other asks wait after it and it waits after them.
  DateTime? getDay0CardShownAt();

  /// Stamps the first time the card is shown and starts its open count at
  /// one. Does nothing after the first call.
  Future<void> markDay0CardShown();

  /// How many separate Home opens the card has been on screen for.
  int getDay0CardOpenCount();

  /// Adds one to the open count.
  Future<void> markDay0CardOpened();

  /// When the card ended for good: dismissed, "See plans" tapped, or three
  /// opens without a tap. Never cleared.
  DateTime? getDay0CardEndedAt();

  /// Ends the card for good. Does nothing after the first call.
  Future<void> endDay0Card();

  /// When the after-ack reminder or Pro sheet last showed. Stamped as the
  /// sheet opens, so a second ack the same calendar day shows nothing.
  DateTime? getAfterAckSheetShownAt();
  Future<void> markAfterAckSheetShown();

  /// The billing period (`ProEndingRule.keyFor`) the "Pro ends" sheet was
  /// shown for. It shows once per period.
  String? getProEndingSheetShownFor();
  Future<void> markProEndingSheetShown(String key);

  /// When the "Pro ends" pill was last closed outside the last 2 days.
  DateTime? getProEndingNoticeDismissedAt();
  Future<void> dismissProEndingNotice();

  /// The billing period whose last-days pill was closed. It stays gone then.
  String? getProEndingLastDaysDismissedFor();
  Future<void> markProEndingLastDaysDismissed(String key);

  /// The last end date the store reported for Pro. Once it passes, the app
  /// asks the server for the tier again.
  DateTime? getProKnownExpiry();
  Future<void> setProKnownExpiry(DateTime at);

  /// The account last seen on Pro. Pro ending on this same account shows the
  /// "Pro ended" sheet; a different account (sign out, switch) does not.
  String? getProPaidAccountId();
  Future<void> setProPaidAccountId(String? accountId);

  /// The account the "Pro ended" sheet is waiting to show for. Set the
  /// moment the app sees Pro end on that account, cleared once the sheet has
  /// shown. Any other account sees nothing.
  String? getProEndedSheetDueFor();
  Future<void> setProEndedSheetDueFor(String? accountId);

  /// The OS major version the "your phone was updated" notice was closed for
  /// (dismissed, or its test button tapped). While the phone still runs that
  /// version the notice stays gone. A later update is a new version and can
  /// show it once more.
  int? getSystemUpdateNoticeDismissedFor();
  Future<void> dismissSystemUpdateNotice(int osMajor);
}
