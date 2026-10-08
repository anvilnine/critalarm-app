import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/presentation/reliability_rows.dart';
import 'package:critalarm/features/weekly_check/domain/weekly_check_monitor.dart';
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
///
/// The row has no face while the check is fine, so there is none here. A
/// check that needs a look wears the face of that state, which the row takes
/// from `reliabilityStateFace`.
@immutable
final class WeeklyCheckBodyView {
  const WeeklyCheckBodyView({
    required this.lineKey,
    required this.isOn,
    this.lineWhen,
  });

  /// The one short line, and the time it names when it names one. While
  /// the check is off it is the line that says what the check does.
  final String lineKey;
  final String? lineWhen;

  /// Where the switch stands.
  final bool isOn;

  @override
  bool operator ==(Object other) =>
      other is WeeklyCheckBodyView &&
      other.lineKey == lineKey &&
      other.lineWhen == lineWhen &&
      other.isOn == isOn;

  @override
  int get hashCode => Object.hash(lineKey, lineWhen, isOn);
}

/// The one line under the row for how the last tap on the switch ended, or
/// null when it has nothing to say. A tap the relay refused says why in
/// words that are true: it never reads as "could not reach the relay".
String? weeklyCheckSwitchLineKey(WeeklyCheckSwitchOutcome? outcome) =>
    switch (outcome) {
      null || WeeklyCheckSwitchOutcome.done => null,
      WeeklyCheckSwitchOutcome.tierRefused =>
        LocaleKeys.weekly_check_switch_needs_hosted,
      WeeklyCheckSwitchOutcome.notOffered =>
        LocaleKeys.weekly_check_own_server_line,
      WeeklyCheckSwitchOutcome.refused =>
        LocaleKeys.weekly_check_switch_refused,
      WeeklyCheckSwitchOutcome.failed => LocaleKeys.weekly_check_switch_failed,
    };

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

/// Whether the way to the list of rounds shows: once the relay has sent this
/// phone a check. The list needs no plan, so this is true for a locked row
/// and for one that is not offered too.
bool weeklyCheckShowsRounds(WeeklyCheck? check) => check?.lastSentAt != null;

/// The unlocked row for how the check stands. [check] is the relay's last
/// answer, null until it has answered on this phone.
///
/// [standing] is never [WeeklyCheckStanding.locked] or
/// [WeeklyCheckStanding.notOffered] here: those rows have no switch and
/// are drawn by themselves. Handed one, this answers as for a check that
/// was never on.
WeeklyCheckBodyView weeklyCheckBodyView({
  required WeeklyCheckStanding standing,
  required WeeklyCheck? check,
  required DateTime now,
}) {
  final received = check?.lastReceivedAt;
  final (lineKey, lineWhen) = switch (standing) {
    // Off: the switch shows that. The line says what the check does.
    WeeklyCheckStanding.notOffered ||
    WeeklyCheckStanding.locked ||
    WeeklyCheckStanding.neverOn ||
    WeeklyCheckStanding.off => (LocaleKeys.weekly_check_what_line, null),
    WeeklyCheckStanding.waiting => (LocaleKeys.weekly_check_line_waiting, null),
    WeeklyCheckStanding.received when received != null => (
      LocaleKeys.weekly_check_line_received,
      weeklyCheckMoment(received, now: now),
    ),
    WeeklyCheckStanding.received => (
      LocaleKeys.weekly_check_line_received_plain,
      null,
    ),
    WeeklyCheckStanding.missedOnce => (
      LocaleKeys.weekly_check_line_missed_once,
      null,
    ),
    WeeklyCheckStanding.missedRepeatedly => (
      LocaleKeys.weekly_check_line_missed_repeatedly,
      null,
    ),
    WeeklyCheckStanding.tokenRefused => (
      LocaleKeys.weekly_check_line_token_refused,
      null,
    ),
    WeeklyCheckStanding.noToken => (
      LocaleKeys.weekly_check_line_no_token,
      null,
    ),
    // On, with no words for how the rounds went.
    WeeklyCheckStanding.on => (LocaleKeys.weekly_check_what_line, null),
  };
  return WeeklyCheckBodyView(
    lineKey: lineKey,
    lineWhen: lineWhen,
    isOn: standing.isOn,
  );
}

/// One round in the list: what marks it, its result in a few words, and its
/// time.
///
/// The mark follows the face rule of the screen: a missed or refused round
/// wears the face of a broken check, a received one a tick, and a skipped
/// or open one nothing.
@immutable
final class WeeklyCheckRoundView {
  const WeeklyCheckRoundView({
    required this.face,
    required this.showsTick,
    required this.wordKey,
    this.when,
    this.wordTime,
  });

  /// The face of a round that went wrong, or null.
  final FaceState? face;

  /// A round that was received.
  final bool showsTick;
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
      other.showsTick == showsTick &&
      other.wordKey == wordKey &&
      other.wordTime == wordTime &&
      other.when == when;

  @override
  int get hashCode => Object.hash(face, showsTick, wordKey, wordTime, when);
}

/// The words for how a round ended.
///
/// A round still open is "Due by" its closing time when the relay named
/// one. A skipped round says why only when the reason is that the check
/// was switched off: api.md §4.5 lists four more reasons (`tier`,
/// `no_token`, `held`, `unsent`) and "switched off" is true of none of
/// them, so those stay a plain "Skipped". So does `pack`, which a round
/// closed before 1.19.0 may carry, and any reason this build does not
/// know.
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

/// The face for a round, or null. A missed or refused round takes the face
/// of a broken check. Received, skipped, open and closed rounds have none.
FaceState? weeklyCheckResultFace(WeeklyCheckRound round) {
  if (round.isOpen) return null;
  return switch (round.result) {
    WeeklyCheckResult.missed ||
    WeeklyCheckResult.refused => reliabilityStateFace(ReliabilityState.broken),
    WeeklyCheckResult.received || WeeklyCheckResult.skipped || null => null,
  };
}

/// Whether a round shows a tick: it was received.
bool weeklyCheckResultShowsTick(WeeklyCheckRound round) =>
    !round.isOpen && round.result == WeeklyCheckResult.received;

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
    showsTick: weeklyCheckResultShowsTick(round),
    wordKey: weeklyCheckResultKey(round),
    wordTime: dueBy,
    when: dueBy == null ? weeklyCheckMoment(round.openedAt, now: now) : null,
  );
}
