import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_standing.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

// What the weekly check row, its list of rounds and its Home notice show,
// decided without drawing. Pure, so it is unit tested and the widgets only
// draw what they are handed. Words are `LocaleKeys` keys, translated by the
// widget.
//
// Nothing here says a received check proves that alarms work. It proves a
// push reached this phone and the phone reached the relay, and no more.

/// What the unlocked weekly check row shows.
@immutable
final class WeeklyCheckBodyView {
  const WeeklyCheckBodyView({
    required this.face,
    required this.lineKey,
    required this.isOn,
    this.lineWhen,
    this.nextDueWhen,
    this.showsSelfHostedLine = false,
    this.showsRoundsLink = false,
  });

  /// One face per state, none of them used by another row on the screen.
  final FaceState face;

  /// The one short line, and the time it names when it names one. While
  /// the check is off it is the line that says what the check does.
  final String lineKey;
  final String? lineWhen;

  /// Where the switch stands.
  final bool isOn;

  /// The day the next check is due, or null when none is due or the moment
  /// has passed. A passed moment says nothing the user can use.
  final String? nextDueWhen;

  /// On a phone connected to a self-hosted server, in every state: the
  /// check covers the relay to this phone and says nothing about that
  /// server.
  final bool showsSelfHostedLine;

  /// The way to the list of rounds, once the relay has sent one.
  final bool showsRoundsLink;

  @override
  bool operator ==(Object other) =>
      other is WeeklyCheckBodyView &&
      other.face == face &&
      other.lineKey == lineKey &&
      other.lineWhen == lineWhen &&
      other.isOn == isOn &&
      other.nextDueWhen == nextDueWhen &&
      other.showsSelfHostedLine == showsSelfHostedLine &&
      other.showsRoundsLink == showsRoundsLink;

  @override
  int get hashCode => Object.hash(
    face,
    lineKey,
    lineWhen,
    isOn,
    nextDueWhen,
    showsSelfHostedLine,
    showsRoundsLink,
  );
}

DateTime _at(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

/// A moment in the phone's own time: the hour alone for today, the day with
/// it for any other day.
String weeklyCheckMoment(int seconds, {required DateTime now}) {
  final local = _at(seconds).toLocal();
  final today = now.toLocal();
  final sameDay =
      local.year == today.year &&
      local.month == today.month &&
      local.day == today.day;
  return DateFormat(sameDay ? 'HH:mm' : 'EEE d MMM, HH:mm').format(local);
}

/// A day in the phone's own time, for when the next check is due.
String weeklyCheckDay(int seconds) =>
    DateFormat('EEE d MMM').format(_at(seconds).toLocal());

/// The unlocked row for how the check stands. [check] is the relay's last
/// answer, null until it has answered on this phone.
///
/// [standing] is never [WeeklyCheckStanding.locked] here: a locked row is
/// the Pro pack's to draw. Handed one, this answers as for a check that was
/// never on.
WeeklyCheckBodyView weeklyCheckBodyView({
  required WeeklyCheckStanding standing,
  required WeeklyCheck? check,
  required bool isSelfHosted,
  required DateTime now,
}) {
  final received = check?.lastReceivedAt;
  final (face, lineKey, lineWhen) = switch (standing) {
    // Off: the switch shows that. The line says what the check does.
    WeeklyCheckStanding.locked ||
    WeeklyCheckStanding.neverOn ||
    WeeklyCheckStanding.off => (
      FaceState.sleepy,
      LocaleKeys.pro_pack_weekly_locked_line,
      null,
    ),
    WeeklyCheckStanding.waiting => (
      FaceState.interested,
      LocaleKeys.weekly_check_line_waiting,
      null,
    ),
    WeeklyCheckStanding.received when received != null => (
      FaceState.confident,
      LocaleKeys.weekly_check_line_received,
      weeklyCheckMoment(received, now: now),
    ),
    WeeklyCheckStanding.received => (
      FaceState.confident,
      LocaleKeys.weekly_check_line_received_plain,
      null,
    ),
    WeeklyCheckStanding.missedOnce => (
      FaceState.surprised,
      LocaleKeys.weekly_check_line_missed_once,
      null,
    ),
    WeeklyCheckStanding.missedRepeatedly => (
      FaceState.shakeHead,
      LocaleKeys.weekly_check_line_missed_repeatedly,
      null,
    ),
    WeeklyCheckStanding.tokenRefused => (
      FaceState.shocked,
      LocaleKeys.weekly_check_line_token_refused,
      null,
    ),
    WeeklyCheckStanding.noToken => (
      FaceState.lookLeft,
      LocaleKeys.weekly_check_line_no_token,
      null,
    ),
    // A state a newer relay sends and this build has no words for.
    WeeklyCheckStanding.on => (
      FaceState.blink,
      LocaleKeys.pro_pack_weekly_locked_line,
      null,
    ),
  };
  final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
  final due = check?.nextDueAt;
  return WeeklyCheckBodyView(
    face: face,
    lineKey: lineKey,
    lineWhen: lineWhen,
    isOn: standing.isOn,
    nextDueWhen: standing.isOn && due != null && due > nowSeconds
        ? weeklyCheckDay(due)
        : null,
    showsSelfHostedLine: isSelfHosted,
    showsRoundsLink: check?.lastSentAt != null,
  );
}

/// One round in the list: a face, its result in a few words, and its time.
@immutable
final class WeeklyCheckRoundView {
  const WeeklyCheckRoundView({
    required this.face,
    required this.wordKey,
    this.when,
    this.wordTime,
  });

  /// The face the weekly row shows for the same outcome.
  final FaceState face;
  final String wordKey;

  /// The time [wordKey] names, for a round still open: when it closes.
  final String? wordTime;

  /// When the round opened. Null for an open round that says when it is
  /// due by: one time on the row is enough.
  final String? when;

  @override
  bool operator ==(Object other) =>
      other is WeeklyCheckRoundView &&
      other.face == face &&
      other.wordKey == wordKey &&
      other.wordTime == wordTime &&
      other.when == when;

  @override
  int get hashCode => Object.hash(face, wordKey, wordTime, when);
}

/// The words for how a round ended.
///
/// A round still open is "Due by" its closing time when the relay named
/// one. A skipped round says why only when the reason is that the check
/// was switched off: api.md §4.5 lists four more reasons (`pack`,
/// `no_token`, `held`, `unsent`) and "switched off" is true of none of
/// them, so those stay a plain "Skipped".
String weeklyCheckResultKey(WeeklyCheckRound round) {
  if (round.isOpen) {
    return round.closesAt == null
        ? LocaleKeys.weekly_check_result_open
        : LocaleKeys.weekly_check_result_open_due;
  }
  return switch (round.result) {
    WeeklyCheckResult.received => LocaleKeys.weekly_check_result_received,
    WeeklyCheckResult.missed => LocaleKeys.weekly_check_result_missed,
    WeeklyCheckResult.refused => LocaleKeys.weekly_check_result_refused,
    WeeklyCheckResult.skipped =>
      round.reason == 'disabled'
          ? LocaleKeys.weekly_check_result_skipped_off
          : LocaleKeys.weekly_check_result_skipped,
    // Closed with a result this build has no word for.
    null => LocaleKeys.weekly_check_result_closed,
  };
}

/// The face for a round: the one the weekly row shows for that outcome.
FaceState weeklyCheckResultFace(WeeklyCheckRound round) {
  if (round.isOpen) return FaceState.interested;
  return switch (round.result) {
    WeeklyCheckResult.received => FaceState.confident,
    WeeklyCheckResult.missed => FaceState.surprised,
    WeeklyCheckResult.refused => FaceState.shocked,
    WeeklyCheckResult.skipped => FaceState.sleepy,
    null => FaceState.blink,
  };
}

/// A round is listed at the moment it opened: every round has one, and it
/// is the moment the relay first reached for the phone.
WeeklyCheckRoundView weeklyCheckRoundView(
  WeeklyCheckRound round, {
  required DateTime now,
}) {
  final closesAt = round.closesAt;
  final dueBy = round.isOpen && closesAt != null
      ? weeklyCheckMoment(closesAt, now: now)
      : null;
  return WeeklyCheckRoundView(
    face: weeklyCheckResultFace(round),
    wordKey: weeklyCheckResultKey(round),
    wordTime: dueBy,
    when: dueBy == null ? weeklyCheckMoment(round.openedAt, now: now) : null,
  );
}
