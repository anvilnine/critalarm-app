/// How far back History and the topic screen are allowed to show.
///
/// One place, because the rule is easy to get wrong in two. api.md §4.2: on
/// the free tier the server keeps 7 days and the app shows the same 7 days.
/// On a paid tier the app shows everything it holds, which can reach further
/// back than the server does, because the phone keeps its own copy.
///
/// This is a query filter, never a delete. Buying Pro unhides the old rows
/// with no download. A plan lapsing hides them again and removes nothing.
abstract final class HistoryWindow {
  /// How many days back the plan shows, for the summary line and the filter
  /// chips. Long history keeps 90.
  static const int paidDays = 90;

  /// [hasLongHistory] is `FeatureAccess.can(AppFeature.longHistory)`: true
  /// on Hosted and on a server of the user's own, which has no tier.
  /// [historyDays] is the cap the registration sent.
  static int shownDays({
    required bool hasLongHistory,
    required int historyDays,
  }) => hasLongHistory ? paidDays : historyDays;

  /// The oldest `opened_at` allowed on screen.
  ///
  /// A null lower bound means "show everything on the phone". That is
  /// anyone with long history.
  ///
  /// [hasLongHistory] is `FeatureAccess.can(AppFeature.longHistory)`, so a
  /// purchase the store confirmed and the developer switch count the same
  /// as the server saying so.
  static DateTime? lowerBound({
    required bool hasLongHistory,
    required int historyDays,
    required DateTime now,
  }) {
    if (hasLongHistory) return null;
    return now.subtract(Duration(days: historyDays));
  }
}
