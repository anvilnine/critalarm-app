import 'dart:math' as math;

import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/features/reliability/domain/attention_order.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:flutter/foundation.dart';

// The rule behind "Will it wake me?": one word, where along the way an alarm
// would stop, and the numbers the header and the path are drawn from. All of
// it is pure. The widgets only draw what these functions answer.

/// The one word the screen answers with.
enum WakeAnswer { yes, maybe, no }

bool _isProblem(ReliabilityState state) =>
    state == ReliabilityState.needsLook || state == ReliabilityState.broken;

/// Broken gives [WakeAnswer.no], a check that needs a look gives
/// [WakeAnswer.maybe], anything else gives [WakeAnswer.yes]. Checks that are
/// not on this phone are ignored and an empty list is a yes.
///
/// It is `overallReliabilityState` with new names, so the word and the
/// existing headline cannot disagree.
WakeAnswer wakeAnswerFor(Iterable<ReliabilityCheck> checks) {
  var answer = WakeAnswer.yes;
  for (final check in checks) {
    switch (check.state) {
      case ReliabilityState.broken:
        return WakeAnswer.no;
      case ReliabilityState.needsLook:
        answer = WakeAnswer.maybe;
      case ReliabilityState.fine:
      case ReliabilityState.notOnThisPhone:
        break;
    }
  }
  return answer;
}

/// [wakeAnswerFor] for a read of the checks. A read with a hole in it
/// ([incomplete]: a source did not answer) is never a yes.
WakeAnswer wakeAnswerForSnapshot(
  Iterable<ReliabilityCheck> checks, {
  required bool incomplete,
}) {
  final answer = wakeAnswerFor(checks);
  if (incomplete && answer == WakeAnswer.yes) return WakeAnswer.maybe;
  return answer;
}

/// How many checks are not fine, for "N things stop it" and the button.
int wakeProblemCount(Iterable<ReliabilityCheck> checks) =>
    checks.where((check) => _isProblem(check.state)).length;

/// How many checks are broken.
int wakeBrokenCount(Iterable<ReliabilityCheck> checks) =>
    checks.where((check) => check.state == ReliabilityState.broken).length;

/// The first check, in attention order, that is not fine. Null when every
/// check passes.
ReliabilityCheck? wakeWorstCheck(Iterable<ReliabilityCheck> checks) {
  for (final check in orderByAttention(checks)) {
    if (_isProblem(check.state)) return check;
  }
  return null;
}

/// The four stops of the way an alarm takes, in order.
enum WakeStop { tool, server, push, phone }

/// Where a check sits on the path. The tool is outside the app and has none.
/// A check this table does not know sits on the phone, so a new source never
/// hides a problem.
WakeStop wakeStopOf(ReliabilityCheckId id) => switch (id.value) {
  'push_token_confirmed' => WakeStop.server,
  'last_push_received' || 'time_sensitive' || 'weekly_check' => WakeStop.push,
  _ => WakeStop.phone,
};

/// How one stop stands: the worst state of the checks behind it and how many
/// of them are not fine.
@immutable
final class WakeStopStatus {
  const WakeStopStatus({
    required this.stop,
    required this.state,
    required this.problems,
  });

  final WakeStop stop;

  /// [ReliabilityState.fine], [ReliabilityState.needsLook] or
  /// [ReliabilityState.broken].
  final ReliabilityState state;
  final int problems;

  bool get isFine => state == ReliabilityState.fine;

  @override
  bool operator ==(Object other) =>
      other is WakeStopStatus &&
      other.stop == stop &&
      other.state == state &&
      other.problems == problems;

  @override
  int get hashCode => Object.hash(stop, state, problems);

  @override
  String toString() => 'WakeStopStatus(${stop.name}, ${state.name}, $problems)';
}

/// The four stops, in order, with how each stands. A stop never reads better
/// than the checks behind it. Your tool is always fine: the app cannot see
/// it.
List<WakeStopStatus> wakePathFor(Iterable<ReliabilityCheck> checks) {
  final worst = {for (final stop in WakeStop.values) stop: 0};
  final counts = {for (final stop in WakeStop.values) stop: 0};
  for (final check in checks) {
    if (!_isProblem(check.state)) continue;
    final stop = wakeStopOf(check.id);
    counts[stop] = counts[stop]! + 1;
    final rank = check.state == ReliabilityState.broken ? 2 : 1;
    worst[stop] = math.max(worst[stop]!, rank);
  }
  return [
    for (final stop in WakeStop.values)
      WakeStopStatus(
        stop: stop,
        state: switch (worst[stop]) {
          2 => ReliabilityState.broken,
          1 => ReliabilityState.needsLook,
          _ => ReliabilityState.fine,
        },
        problems: counts[stop]!,
      ),
  ];
}

/// The stops that are not fine, in path order.
List<WakeStopStatus> wakeBadStops(List<WakeStopStatus> path) => [
  for (final status in path)
    if (!status.isFine) status,
];

// ---------------------------------------------------------------------------
// The line under the word.

/// Which line sits under the answer.
enum WakeLineKind {
  /// Yes, and a test rang here. Uses [WakeLine.since].
  testRang,

  /// Yes, and no test ever rang here. A nudge to ring one.
  noTestYet,

  /// One check to name. Uses [WakeLine.checkId].
  check,

  /// Several checks are broken. Uses [WakeLine.count].
  several,

  /// A source did not answer and nothing else is wrong.
  couldNotRun,
}

/// The line under the answer, as data. The widget picks the words.
@immutable
final class WakeLine {
  const WakeLine(this.kind, {this.since, this.checkId, this.count = 0});

  final WakeLineKind kind;
  final Duration? since;
  final ReliabilityCheckId? checkId;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is WakeLine &&
      other.kind == kind &&
      other.since == since &&
      other.checkId == checkId &&
      other.count == count;

  @override
  int get hashCode => Object.hash(kind, since, checkId, count);

  @override
  String toString() => 'WakeLine($kind, $since, $checkId, $count)';
}

/// The line for a read of the checks.
///
/// - Yes: when the newest test rang, else the nudge.
/// - No: the count when more than one check is broken, else the worst
///   check.
/// - Maybe: the worst check, or "a check could not run" when a source failed
///   and nothing else is wrong.
WakeLine wakeLineFor(
  Iterable<ReliabilityCheck> checks, {
  required bool incomplete,
  required DateTime now,
  DateTime? lastTestAt,
}) {
  final answer = wakeAnswerForSnapshot(checks, incomplete: incomplete);
  final worst = wakeWorstCheck(checks);
  switch (answer) {
    case WakeAnswer.yes:
      if (lastTestAt == null) return const WakeLine(WakeLineKind.noTestYet);
      final since = now.difference(lastTestAt);
      return WakeLine(
        WakeLineKind.testRang,
        since: since.isNegative ? Duration.zero : since,
      );
    case WakeAnswer.no:
      final broken = wakeBrokenCount(checks);
      if (broken > 1) return WakeLine(WakeLineKind.several, count: broken);
      return WakeLine(WakeLineKind.check, checkId: worst?.id);
    case WakeAnswer.maybe:
      if (worst == null) return const WakeLine(WakeLineKind.couldNotRun);
      return WakeLine(WakeLineKind.check, checkId: worst.id);
  }
}

/// The newest of the times a test rang, or null when none did.
DateTime? newestTestAt(Iterable<DateTime> times) {
  DateTime? newest;
  for (final time in times) {
    if (newest == null || time.isAfter(newest)) newest = time;
  }
  return newest;
}

// ---------------------------------------------------------------------------
// The size of the answer.

/// How the header lays out the word and the face.
typedef WakeAnswerLayout = ({
  double fontSize,
  double faceSize,
  bool isStacked,
  double wordWidth,
  double columnWidth,
});

/// The side margin of the header, either side.
const double wakeSideMargin = 20;

/// The gap between the word column and the face when they sit side by side.
const double wakeFaceGap = 12;

/// The type size of the word at a 390 point wide screen.
double wakeBaseFontSize(WakeAnswer word) => switch (word) {
  WakeAnswer.yes => 76,
  WakeAnswer.maybe => 62,
  WakeAnswer.no => 68,
};

/// The face's size at a 390 point wide screen.
double wakeBaseFaceSize(WakeAnswer word) => switch (word) {
  WakeAnswer.yes => 124,
  WakeAnswer.maybe || WakeAnswer.no => 104,
};

/// How wide the word is, in ems of its type size: a cautious figure for
/// Bricolage Grotesque at weight 800 with the header's tight spacing.
double wakeWordEms(WakeAnswer word) => switch (word) {
  WakeAnswer.yes => 1.72,
  WakeAnswer.maybe => 2.92,
  WakeAnswer.no => 1.42,
};

/// The type size and the face size of the answer on a screen [width] points
/// wide at [textScale], and whether the face drops under the word.
///
/// - Both scale with the width, between 0.75 and 1.1 of the 390 point board.
/// - The word stops growing with the text size at 1.3, the limit the other
///   headers use, and its width is checked instead.
/// - Side by side, the word has the room left of the face. When it does not
///   fit even at 0.8 of its size the face drops under it and the word gets
///   the whole width.
///
/// The returned word width is never more than the column it sits in, and in
/// the side by side layout the word and the face never meet.
WakeAnswerLayout wakeAnswerSize(
  WakeAnswer word,
  double width,
  double textScale,
) {
  final shape = (width / 390).clamp(0.75, 1.1);
  final grow = textScale.clamp(1.0, 1.3);
  var fontSize = wakeBaseFontSize(word) * shape * grow;
  final ems = wakeWordEms(word);
  final isLargeText = textScale > 1.3;
  final faceSize = wakeBaseFaceSize(word) * shape * (isLargeText ? 0.75 : 1);

  final whole = math.max(0, width - 2 * wakeSideMargin).toDouble();
  final beside = math.max(0, whole - faceSize - wakeFaceGap).toDouble();
  if (!isLargeText && fontSize * ems <= beside) {
    return (
      fontSize: fontSize,
      faceSize: faceSize,
      isStacked: false,
      wordWidth: fontSize * ems,
      columnWidth: beside,
    );
  }
  // A little smaller keeps the face beside it.
  final smaller = fontSize * 0.8;
  if (!isLargeText && smaller * ems <= beside) {
    fontSize = beside / ems;
    return (
      fontSize: fontSize,
      faceSize: faceSize,
      isStacked: false,
      wordWidth: fontSize * ems,
      columnWidth: beside,
    );
  }
  fontSize = math.min(fontSize, whole / ems);
  return (
    fontSize: fontSize,
    faceSize: faceSize,
    isStacked: true,
    wordWidth: fontSize * ems,
    columnWidth: whole,
  );
}

// ---------------------------------------------------------------------------
// The motion, as functions of one clock in seconds.

/// How long the dot takes for one trip along the path, in seconds.
const double wakeLoopSeconds = 3;

/// The part of the loop the dot is on screen, as shares of the loop.
const double wakeDotStart = 0.08;
const double wakeDotLand = 0.70;
const double wakeDotGone = 0.78;

/// How long the red ring of a stop that is not fine takes to go out, in
/// seconds.
const double wakePulseSeconds = 1.6;

/// How far that ring reaches, in points.
const double wakePulseReach = 10;

/// How long the disc behind the face takes for one breath, in seconds.
final double wakeBreathSeconds = AppDurations.ambient.inMilliseconds / 1000;

/// How far the disc grows at the top of a breath.
const double wakeBreathGrowth = 0.035;

/// Where the dot is and how clearly.
///
/// `progress` is the share of the wire from the first stop to the last, 0 to
/// 1. `opacity` is 1 while the dot travels and falls to 0 after it lands.
typedef WakeDot = ({double progress, double opacity});

/// The travelling dot at clock [seconds], or null when it is not on screen.
///
/// - It is on screen from 8% to 70% of each 3 second loop, then fades by
///   78%.
/// - It eases from the first stop to the last and lands there.
/// - With [brokenStop] it stops at that stop instead, and fades there.
/// - With more than one stop not fine ([brokenCount]) there is no dot.
WakeDot? wakePathDotAt(
  double seconds, {
  WakeStop? brokenStop,
  int? brokenCount,
}) {
  final count = brokenCount ?? (brokenStop == null ? 0 : 1);
  if (count > 1) return null;
  final u = (seconds % wakeLoopSeconds) / wakeLoopSeconds;
  if (u < wakeDotStart || u > wakeDotGone) return null;
  final travel = ((u - wakeDotStart) / (wakeDotLand - wakeDotStart))
      .clamp(0, 1)
      .toDouble();
  // Smoothstep: slow out of the first stop, slow into the last.
  final eased = travel * travel * (3 - 2 * travel);
  final stall = brokenStop == null
      ? 1.0
      : brokenStop.index / (WakeStop.values.length - 1);
  final opacity = u <= wakeDotLand
      ? 1.0
      : 1 - (u - wakeDotLand) / (wakeDotGone - wakeDotLand);
  return (progress: math.min(eased, stall), opacity: opacity);
}

/// The scale of the last stop as the dot lands: 1, up to 1.18, down to 0.96
/// and back to 1. Always 1 away from the landing.
double wakeLandScaleAt(double seconds) {
  final u = (seconds % wakeLoopSeconds) / wakeLoopSeconds;
  double lerp(double from, double to, double a, double b) =>
      from + (to - from) * ((u - a) / (b - a));
  if (u < 0.68) return 1;
  if (u < 0.76) return lerp(1, 1.18, 0.68, 0.76);
  if (u < 0.86) return lerp(1.18, 0.96, 0.76, 0.86);
  if (u < 1) return lerp(0.96, 1, 0.86, 1);
  return 1;
}

/// The ring round a stop that is not fine at clock [seconds]: how far out it
/// is, 0 to [wakePulseReach], and how strong, 1 to 0.
({double reach, double strength}) wakePulseAt(double seconds) {
  final u = (seconds % wakePulseSeconds) / wakePulseSeconds;
  final out = 1 - math.pow(1 - u, 3).toDouble();
  return (reach: wakePulseReach * out, strength: 1 - u);
}

/// The scale of the disc behind the face at clock [seconds]: 1 at the start
/// of a breath, [wakeBreathGrowth] more at the top.
double wakeBreathAt(double seconds) {
  final u = (seconds % wakeBreathSeconds) / wakeBreathSeconds;
  return 1 + wakeBreathGrowth * (0.5 - 0.5 * math.cos(2 * math.pi * u));
}
