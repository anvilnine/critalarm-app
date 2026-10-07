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
}

/// Answers "should Home say that weekly checks stopped arriving".
///
/// It shows when every one of these holds:
///
/// - setup is done (`SetupGate`), like every other notice;
/// - the device is enrolled and the account still holds the pack;
/// - two rounds in a row were missed: either the relay says so (`misses` of
///   2 or more), or this phone's own clock passed `notice_after`. The phone
///   has to tell by itself, because the push that would bring the news is
///   the thing that failed;
/// - no check has reached this phone since it learned that;
/// - the notice was not closed for this run of misses.
///
/// One missed round shows nothing here. Closing the notice keeps it gone
/// until a check arrives and a later run of misses begins.
///
/// It is a card on Home. It is not a notification and it makes no alert.
abstract final class WeeklyCheckNoticeRule {
  static bool shouldShow({
    required bool isSetupDone,
    required WeeklyCheckNoticeFacts? facts,
    required int now,
  }) {
    if (!isSetupDone || facts == null) return false;
    final check = facts.check;
    if (!check.enabled || check.state == WeeklyCheckState.off) return false;

    final arrival = facts.lastArrivalAt;
    bool arrivedSince(int? at) => arrival != null && at != null && arrival > at;

    final missedTwice = check.misses >= 2 && !arrivedSince(facts.checkSeenAt);
    final noticeAfter = facts.noticeAfter;
    final clockPassed =
        noticeAfter != null &&
        now >= noticeAfter &&
        !arrivedSince(facts.noticeAfterSeenAt);
    if (!missedTwice && !clockPassed) return false;

    final dismissedAt = facts.dismissedAt;
    if (dismissedAt == null) return true;
    // A check that arrived after the notice was closed ended that run, so
    // what is due now is a later one.
    final relayReceived = check.lastReceivedAt;
    return arrivedSince(dismissedAt) ||
        (relayReceived != null && relayReceived > dismissedAt);
  }
}
