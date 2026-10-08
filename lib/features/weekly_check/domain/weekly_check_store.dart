import 'package:critalarm/core/models/weekly_check.dart';
import 'package:flutter/foundation.dart';

/// The relay's last answer about the weekly check, and when this phone got
/// it, by this phone's own clock in epoch seconds.
@immutable
final class KeptWeeklyCheck {
  const KeptWeeklyCheck({
    required this.check,
    required this.seenAt,
    this.deviceId,
  });

  final WeeklyCheck check;
  final int seenAt;

  /// The device the answer was for. After a sign-out the phone has another
  /// device id and this answer says nothing about it.
  final String? deviceId;
}

/// What the native push handler wrote about the last check that reached
/// this phone. It runs with no Dart, so this record is how Dart hears of it.
///
/// It never holds the id a check push carries.
@immutable
final class WeeklyCheckArrival {
  const WeeklyCheckArrival({
    this.receivedAt,
    this.noticeAfter,
    this.noticeAfterSeenAt,
    this.nextDueAt,
  });

  /// When the last check push arrived, by this phone's clock.
  final int? receivedAt;

  /// `notice_after` from the last receipt the relay answered, and when.
  final int? noticeAfter;
  final int? noticeAfterSeenAt;

  /// `next_due_at` from that same answer.
  final int? nextDueAt;
}

/// Keeps the weekly check on the phone, so a cold start with no network
/// still knows whether it is on, and so the phone can tell by its own clock
/// that checks stopped arriving.
abstract interface class WeeklyCheckStore {
  /// Null when the relay has never answered on this phone.
  KeptWeeklyCheck? readCheck();

  Future<void> writeCheck(KeptWeeklyCheck kept);

  /// What the native handler recorded. Reads it fresh from disk.
  Future<WeeklyCheckArrival?> readArrival();

  /// When the Home notice was last closed, by this phone's clock.
  int? readDismissedAt();

  Future<void> writeDismissedAt(int at);

  /// When this phone last saw that the relay sends it no check because of
  /// the plan or the server: Hosted not held, or a server of the user's
  /// own. By this phone's clock. Null when it never saw that.
  ///
  /// Anything the phone learned at or before this second describes a
  /// schedule the relay has since stopped, so the notice rule sets it
  /// aside.
  int? readPlanAwayAt();

  Future<void> writePlanAwayAt(int at);

  /// Forgets everything, the native record included.
  Future<void> clear();
}
