import 'package:critalarm/core/models/weekly_check.dart';
import 'package:critalarm/design/faces/face_state.dart';
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

/// What sits under the title of the unlocked weekly check row.
@immutable
final class WeeklyCheckBodyView {
  const WeeklyCheckBodyView({
    required this.face,
    required this.lineKey,
    required this.isOn,
    this.lineWhen,
    this.nextDueKey,
    this.nextDueWhen,
    this.showsSelfHostedLine = false,
  });

  /// One face per state, none of them used by another row on the screen.
  final FaceState face;

  /// The one short line, and the time it names when it names one.
  final String lineKey;
  final String? lineWhen;

  /// Where the switch stands.
  final bool isOn;

  /// The line about the next check, or null when none is due.
  final String? nextDueKey;
  final String? nextDueWhen;

  /// On a phone connected to a self-hosted server: the check covers the
  /// relay to this phone and says nothing about that server.
  final bool showsSelfHostedLine;

  @override
  bool operator ==(Object other) =>
      other is WeeklyCheckBodyView &&
      other.face == face &&
      other.lineKey == lineKey &&
      other.lineWhen == lineWhen &&
      other.isOn == isOn &&
      other.nextDueKey == nextDueKey &&
      other.nextDueWhen == nextDueWhen &&
      other.showsSelfHostedLine == showsSelfHostedLine;

  @override
  int get hashCode => Object.hash(
    face,
    lineKey,
    lineWhen,
    isOn,
    nextDueKey,
    nextDueWhen,
    showsSelfHostedLine,
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

/// The unlocked row for what the relay last said. [check] is null until the
/// relay has answered on this phone.
WeeklyCheckBodyView weeklyCheckBodyView({
  required WeeklyCheck? check,
  required bool isSelfHosted,
  required DateTime now,
}) {
  if (check == null) {
    return const WeeklyCheckBodyView(
      face: FaceState.sleepy,
      lineKey: LocaleKeys.pro_pack_weekly_ready_line,
      isOn: false,
    );
  }
  final state = check.state;
  if (state == WeeklyCheckState.off) {
    if (check.reason == WeeklyCheckOffReason.pack) {
      return const WeeklyCheckBodyView(
        face: FaceState.dozing,
        lineKey: LocaleKeys.weekly_check_line_pack_lost,
        isOn: false,
      );
    }
    return WeeklyCheckBodyView(
      face: FaceState.sleepy,
      // A device that never had a round has nothing to call switched off.
      lineKey: check.lastSentAt == null
          ? LocaleKeys.pro_pack_weekly_ready_line
          : LocaleKeys.weekly_check_line_off,
      isOn: false,
    );
  }

  final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
  final due = check.nextDueAt;
  final isOverdue = due != null && due <= nowSeconds;
  final received = check.lastReceivedAt;
  final (face, lineKey, lineWhen) = switch (state) {
    WeeklyCheckState.waiting => (
      FaceState.interested,
      LocaleKeys.weekly_check_line_waiting,
      null,
    ),
    WeeklyCheckState.received when received != null => (
      FaceState.confident,
      LocaleKeys.weekly_check_line_received,
      weeklyCheckMoment(received, now: now),
    ),
    WeeklyCheckState.received => (
      FaceState.confident,
      LocaleKeys.weekly_check_line_received_plain,
      null,
    ),
    WeeklyCheckState.missedOnce => (
      FaceState.surprised,
      LocaleKeys.weekly_check_line_missed_once,
      null,
    ),
    WeeklyCheckState.missedRepeatedly => (
      FaceState.shakeHead,
      LocaleKeys.weekly_check_line_missed_repeatedly,
      null,
    ),
    WeeklyCheckState.tokenRefused => (
      FaceState.shocked,
      LocaleKeys.weekly_check_line_token_refused,
      null,
    ),
    WeeklyCheckState.noToken => (
      FaceState.lookLeft,
      LocaleKeys.weekly_check_line_no_token,
      null,
    ),
    // A state a newer relay sends and this build has no words for.
    WeeklyCheckState.off || null => (
      FaceState.blink,
      LocaleKeys.weekly_check_line_on,
      null,
    ),
  };
  return WeeklyCheckBodyView(
    face: face,
    lineKey: lineKey,
    lineWhen: lineWhen,
    isOn: check.enabled,
    nextDueKey: due == null
        ? null
        : isOverdue
        ? LocaleKeys.weekly_check_next_due_now
        : LocaleKeys.weekly_check_next_due,
    nextDueWhen: due == null || isOverdue ? null : weeklyCheckDay(due),
    showsSelfHostedLine: isSelfHosted,
  );
}

/// One round in the list: its result in a word, and its time.
@immutable
final class WeeklyCheckRoundView {
  const WeeklyCheckRoundView({required this.wordKey, required this.when});

  final String wordKey;
  final String when;

  @override
  bool operator ==(Object other) =>
      other is WeeklyCheckRoundView &&
      other.wordKey == wordKey &&
      other.when == when;

  @override
  int get hashCode => Object.hash(wordKey, when);
}

/// The word for how a round ended.
String weeklyCheckResultKey(WeeklyCheckRound round) {
  if (round.isOpen) return LocaleKeys.weekly_check_result_open;
  return switch (round.result) {
    WeeklyCheckResult.received => LocaleKeys.weekly_check_result_received,
    WeeklyCheckResult.missed => LocaleKeys.weekly_check_result_missed,
    WeeklyCheckResult.refused => LocaleKeys.weekly_check_result_refused,
    WeeklyCheckResult.skipped => LocaleKeys.weekly_check_result_skipped,
    // Closed with a result this build has no word for.
    null => LocaleKeys.weekly_check_result_closed,
  };
}

/// A round is listed at the moment it opened: every round has one, and it
/// is the moment the relay first reached for the phone.
WeeklyCheckRoundView weeklyCheckRoundView(
  WeeklyCheckRound round, {
  required DateTime now,
}) => WeeklyCheckRoundView(
  wordKey: weeklyCheckResultKey(round),
  when: weeklyCheckMoment(round.openedAt, now: now),
);
