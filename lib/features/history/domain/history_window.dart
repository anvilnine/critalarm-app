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
  /// The tier the relay calls the unpaid plan.
  static const freeTier = 'free';

  /// The oldest `opened_at` allowed on screen.
  ///
  /// A null lower bound means "show everything on the phone". That is every
  /// tier except [freeTier], and self-hosted mode, which is never sent a
  /// tier at all and has no caps to apply.
  static DateTime? lowerBound({
    required String tier,
    required int historyDays,
    required DateTime now,
    bool isSelfHosted = false,
  }) {
    if (isSelfHosted || tier != freeTier) return null;
    return now.subtract(Duration(days: historyDays));
  }
}
