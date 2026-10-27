import 'package:critalarm/core/models/weekly_check.dart';
import 'package:flutter/foundation.dart';

/// Everything the Home notice about the weekly check is decided from. Every
/// time is epoch seconds. [check] times are the relay's clock, the rest are
/// this phone's.
@immutable
final class WeeklyCheckNoticeFacts {
  const WeeklyCheckNoticeFacts({
    required this.check,
    required this.checkSeenAt,
    this.noticeAfter,
    this.noticeAfterSeenAt,
    this.lastArrivalAt,
    this.dismissedAt,
    this.isPlanAway = false,
    this.planAwaySeenAt,
  });

  /// The relay's last answer.
  final WeeklyCheck check;

  /// When this phone got that answer.
  final int checkSeenAt;

  /// The newest `notice_after` this phone holds, from a read or from a
  /// receipt answer, and when it got it.
  final int? noticeAfter;
  final int? noticeAfterSeenAt;

  /// When a check push last reached this phone.
  final int? lastArrivalAt;

  /// When the notice was last closed.
  final int? dismissedAt;

  /// The relay is sending this phone no check right now because of the
  /// plan or the server: Hosted is not held, or the phone is on a server
  /// of the user's own (`WeeklyCheckAccess.isPlanAway`).
  final bool isPlanAway;

  /// When this phone last saw [isPlanAway] true, or null when it never
  /// did.
  final int? planAwaySeenAt;
}

/// Answers "should Home say that weekly checks stopped arriving".
///
/// It shows when every one of these holds:
///
/// - setup is done (`SetupGate`), like every other notice;
/// - the device is enrolled, and the relay is sending it checks: Hosted is
///   held and the phone is not on a server of the user's own;
/// - two rounds in a row were missed, by one of the two ways below;
/// - the notice was not closed for this run of misses.
///
/// What the relay last said decides it while no check has reached the phone
/// since: `misses` of 2 or more, or this phone's own clock passing
/// `notice_after`. The phone has to tell by itself, because the push that
/// would bring the news is the thing that failed.
///
/// A check that reached the phone after the relay's last answer ends the
/// miss window it fell in, and only that one. When its receipt was answered
/// the relay handed back a new `notice_after`, and that is the newer answer.
/// When it was not, the phone has no newer answer, so it counts from the
/// arrival: two windows of [missWindow] with nothing arriving are two
/// rounds missed. An arrival never switches the notice off for good.
///
/// A plan that lapsed is not a miss. While Hosted is away the relay sends
/// nothing and writes each round as skipped (api.md §4.5, "When the tier
/// changes"), so the answer is no. When Hosted comes back, what the phone
/// held from before it saw the lapse is set aside too: a `notice_after`, a
/// count of misses and an arrival from then describe a schedule the relay
/// stopped, and a clock that ran past them during the lapse proves
/// nothing. The phone waits for the relay's next answer or the next check.
///
/// One missed round shows nothing here. Closing the notice keeps it gone
/// until a check arrives and a later run of misses begins.
///
/// It is a card on Home. It is not a notification and it makes no alert.
abstract final class WeeklyCheckNoticeRule {
  /// api.md §4.5, "A round": rounds are 7 days apart, and the gap between a
  /// device's first two rounds is 3 to 10 days. Ten days is the longest the
  /// contract lets one round follow another. In seconds.
  static const int longestGapBetweenRounds = 10 * 24 * 60 * 60;

  /// api.md §4.5, "A round": a round stays open for 24 hours from the
  /// moment it opens, and only then counts as missed. The relay's own
  /// `notice_after` sits this far past the round it is waiting on. In
  /// seconds.
  static const int roundOpenFor = 24 * 60 * 60;

  /// The longest one round can take to come due and then be missed.
  static const int missWindow = longestGapBetweenRounds + roundOpenFor;

  /// How many windows in a row with nothing arriving raise the notice. The
  /// same two rounds the relay counts (api.md §4.5, "One missed round is a
  /// prompt to look").
  static const int windowsToNotice = 2;

  /// An arrival stamped later than this far past the phone's own clock was
  /// not read right, or the clock moved. It counts as no arrival known. In
  /// seconds.
  static const int clockSlack = 5 * 60;

  /// The second this phone counts two rounds missed from, when all it has
  /// is a check that arrived at [arrivalAt].
  static int deadlineAfterArrival(int arrivalAt) =>
      arrivalAt + windowsToNotice * missWindow;

  /// Whether two rounds in a row were missed, as far as this phone can
  /// tell: the first three points of [shouldShow], without setup and
  /// without whether the notice was closed. The Reliability screen reads
  /// this, so it still says so after the Home notice was closed.
  static bool twoRoundsMissed({
    required WeeklyCheckNoticeFacts? facts,
    required int now,
  }) {
    if (facts == null || facts.isPlanAway) return false;
    final check = facts.check;
    if (!check.enabled || check.state == WeeklyCheckState.off) return false;

    // Whatever the phone learned up to the last moment it saw the plan
    // away is from before a lapse.
    final planAwayAt = facts.planAwaySeenAt;
    bool isSinceLapse(int? at) =>
        planAwayAt == null || (at != null && at > planAwayAt);

    // An arrival the phone cannot place counts as none: it must neither
    // raise the notice nor hide a run of misses the relay reported.
    final placed = _arrival(facts, now);
    final arrival = isSinceLapse(placed) ? placed : null;
    bool arrivedSince(int? at) => arrival != null && at != null && arrival > at;

    if (arrival != null && arrivedSince(facts.noticeAfterSeenAt)) {
      // Nothing from the relay is newer than this arrival, so its
      // `notice_after` and its count of misses describe a window that has
      // ended. The phone counts on from the arrival by itself.
      return now >= deadlineAfterArrival(arrival);
    }
    final missedTwice =
        isSinceLapse(facts.checkSeenAt) &&
        check.misses >= 2 &&
        !arrivedSince(facts.checkSeenAt);
    final noticeAfter =
        isSinceLapse(facts.noticeAfterSeenAt ?? facts.checkSeenAt)
        ? facts.noticeAfter
        : null;
    return missedTwice || (noticeAfter != null && now >= noticeAfter);
  }

  static int? _arrival(WeeklyCheckNoticeFacts facts, int now) {
    final stamped = facts.lastArrivalAt;
    return stamped != null && stamped > 0 && stamped <= now + clockSlack
        ? stamped
        : null;
  }

  static bool shouldShow({
    required bool isSetupDone,
    required WeeklyCheckNoticeFacts? facts,
    required int now,
  }) {
    if (!isSetupDone || facts == null) return false;
    if (!twoRoundsMissed(facts: facts, now: now)) return false;

    final dismissedAt = facts.dismissedAt;
    if (dismissedAt == null) return true;
    // A check that arrived after the notice was closed ended that run, so
    // what is due now is a later one.
    final arrival = _arrival(facts, now);
    final relayReceived = facts.check.lastReceivedAt;
    return (arrival != null && arrival > dismissedAt) ||
        (relayReceived != null && relayReceived > dismissedAt);
  }
}
