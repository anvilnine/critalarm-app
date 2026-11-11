import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:critalarm/design/faces/face_state.dart';

/// What Crit does when somebody taps the hero face.
///
/// Each one is a short beat that ends where it began: on the screen's own
/// face, upright, at full size. The faces are picked for being poked: glad,
/// tickled, startled, curious, cheeky, fond, and dizzy once it is too much.
enum FaceTapReaction {
  /// A squash and a springy stretch, eyes curved shut with a warm smile.
  boop(FaceState.happy, 0.9),

  /// A giggle: the head wobbles side to side and settles.
  giggle(FaceState.laughing, 1.1),

  /// Startled: a small hop up, wide eyes, round mouth, a soft landing.
  startle(FaceState.surprised, 1),

  /// Curious: the eyes go to where the finger landed and the head leans in.
  peek(FaceState.interested, 1.4),

  /// A wink and a small cock of the head.
  wink(FaceState.cheeky, 1.1),

  /// Fond: a slow swell with a heart above the head.
  love(FaceState.love, 1.5),

  /// Too many taps too fast: swirl eyes and a slow sway, then it settles.
  dizzy(FaceState.dizzy, 2.6),

  /// A sleepy face snaps awake for a moment, then lets its eyes droop again.
  wake(FaceState.wakesUp, 1.4),

  /// The screen's face says something is wrong. Play is out of place, so
  /// Crit only blinks to say it noticed.
  notice(FaceState.blink, 0.5);

  const FaceTapReaction(this.face, this.seconds);

  /// The face the reaction wears at its peak.
  final FaceState face;

  /// How long the whole beat runs, from tap to rest.
  final double seconds;
}

/// The playful reactions, in the order taps cycle through them.
const List<FaceTapReaction> faceTapCycle = [
  FaceTapReaction.boop,
  FaceTapReaction.giggle,
  FaceTapReaction.startle,
  FaceTapReaction.peek,
  FaceTapReaction.wink,
  FaceTapReaction.love,
];

/// Faces that mean something is wrong. A tap on one only gets a blink.
const Set<FaceState> faceTapSeriousFaces = {
  FaceState.worried,
  FaceState.sad,
  FaceState.concerned,
  FaceState.confused,
  FaceState.skeptical,
};

/// Faces that never react: an alarm is ringing, or the face is already busy
/// doing its own thing (a refresh, a shake).
const Set<FaceState> faceTapStillFaces = {
  FaceState.alarmed,
  FaceState.shocked,
  FaceState.working,
};

/// Faces that are asleep or nearly. A fresh tap wakes them.
const Set<FaceState> faceTapSleepyFaces = {
  FaceState.sleepy,
  FaceState.dozing,
  FaceState.yawn,
};

/// Picks the reaction for each tap and keeps count of quick taps.
///
/// - A tap within [streakGap] of the last one adds to the streak. The
///   [dizzyAfter]th tap of a streak makes Crit dizzy.
/// - While dizzy, taps are ignored until the beat is over.
/// - Every other tap plays the next reaction in [faceTapCycle].
/// - After [cycleResetAfter] with no tap, the cycle starts again from the
///   boop, so the first tap on a screen is always the same friendly one.
///
/// Holds no widgets and reads time only through the `now` it is given, so
/// it tests with a fake clock.
class FaceTapSequencer {
  /// [now] is only swapped out by tests.
  FaceTapSequencer({DateTime Function()? now}) : _now = now ?? debugNow;

  /// The clock a sequencer reads when it is given none. Capture tools point
  /// it at the test binding's fake clock, so taps a tool spaces out in fake
  /// time are not all one streak in real time.
  static DateTime Function() debugNow = DateTime.now;

  final DateTime Function() _now;

  /// The longest gap between two taps that still counts as one streak.
  static const Duration streakGap = Duration(milliseconds: 700);

  /// How many quick taps make Crit dizzy.
  static const int dizzyAfter = 5;

  /// How long with no tap before the cycle starts again.
  static const Duration cycleResetAfter = Duration(seconds: 6);

  DateTime? _lastTap;
  DateTime? _busyUntil;
  int _streak = 0;
  int _cycle = 0;

  /// How many quick taps in a row so far.
  int get streak => _streak;

  /// Answers a tap on a face resting at [rest]. Null means do nothing: the
  /// face never plays, or it is dizzy and still recovering.
  FaceTapReaction? tap(FaceState rest) {
    if (faceTapStillFaces.contains(rest)) return null;
    final now = _now();
    final busy = _busyUntil;
    if (busy != null && now.isBefore(busy)) return null;
    _busyUntil = null;

    final last = _lastTap;
    final gap = last == null ? null : now.difference(last);
    _lastTap = now;

    final quick = gap != null && gap <= streakGap;
    _streak = quick ? _streak + 1 : 1;
    if (gap == null || gap >= cycleResetAfter) _cycle = 0;

    if (faceTapSeriousFaces.contains(rest)) return FaceTapReaction.notice;

    if (_streak >= dizzyAfter) {
      _streak = 0;
      _lastTap = null;
      _cycle = 0;
      _busyUntil = now.add(_duration(FaceTapReaction.dizzy));
      return FaceTapReaction.dizzy;
    }

    // A sleepy face wakes on the first tap of a streak. Quick taps after
    // that play as usual, so it can still be made dizzy.
    if (faceTapSleepyFaces.contains(rest) && !quick) {
      return FaceTapReaction.wake;
    }

    final reaction = faceTapCycle[_cycle % faceTapCycle.length];
    _cycle++;
    return reaction;
  }

  static Duration _duration(FaceTapReaction r) =>
      Duration(milliseconds: (r.seconds * 1000).round());
}

/// One frame of a reaction.
///
/// - `mix`: how far the face is from the screen's own face (0) to the
///   reaction's face (1).
/// - `scaleX`, `scaleY`: squash and stretch, about the foot of the face.
/// - `angle`: turn in radians, about the middle. Always back to 0 at rest.
/// - `lift`: how far the face is raised, as a share of its size.
/// - `lean`: how far the face is moved sideways, as a share of its size.
typedef FaceTapFrame = ({
  double mix,
  double scaleX,
  double scaleY,
  double angle,
  double lift,
  double lean,
});

/// The resting frame: the screen's own face, upright, full size.
const FaceTapFrame faceTapRest = (
  mix: 0,
  scaleX: 1,
  scaleY: 1,
  angle: 0,
  lift: 0,
  lean: 0,
);

/// How long the face takes to turn into the reaction, how long it holds it,
/// and when it starts turning back, in seconds from the tap.
({double enter, double leaveAt}) faceTapFaceTimes(FaceTapReaction r) =>
    switch (r) {
      FaceTapReaction.boop => (enter: 0.12, leaveAt: 0.55),
      FaceTapReaction.giggle => (enter: 0.12, leaveAt: 0.75),
      FaceTapReaction.startle => (enter: 0.06, leaveAt: 0.6),
      FaceTapReaction.peek => (enter: 0.18, leaveAt: 0.95),
      FaceTapReaction.wink => (enter: 0.1, leaveAt: 0.7),
      FaceTapReaction.love => (enter: 0.25, leaveAt: 1.0),
      FaceTapReaction.dizzy => (enter: 0.2, leaveAt: 2.05),
      FaceTapReaction.wake => (enter: 0.08, leaveAt: 0.75),
      FaceTapReaction.notice => (enter: 0.08, leaveAt: 0.2),
    };

/// The frame [t] seconds after the tap. With [still] (reduce motion, or a
/// face too small to move) only the face changes: it switches to the
/// reaction at once, holds, and switches back, with no movement at all.
FaceTapFrame faceTapFrame(
  FaceTapReaction r,
  double t, {
  bool still = false,
  double leanSign = 0,
}) {
  if (t <= 0 || t >= r.seconds) return faceTapRest;
  final times = faceTapFaceTimes(r);
  if (still) {
    return (
      mix: t < times.leaveAt + (r.seconds - times.leaveAt) / 2 ? 1 : 0,
      scaleX: 1,
      scaleY: 1,
      angle: 0,
      lift: 0,
      lean: 0,
    );
  }

  final mix = t < times.enter
      ? _ease(t / times.enter)
      : t < times.leaveAt
      ? 1.0
      : 1 - _ease((t - times.leaveAt) / (r.seconds - times.leaveAt));

  const deg = math.pi / 180;
  var scaleX = 1.0;
  var scaleY = 1.0;
  var angle = 0.0;
  var lift = 0.0;
  var lean = 0.0;

  switch (r) {
    case FaceTapReaction.boop:
      // Pressed down for a moment, then a springy stretch that settles.
      final s = _squash(t, press: 0.08, settle: 0.5, depth: 0.1);
      scaleY = 1 - s;
      scaleX = 1 + s * 0.6;
    case FaceTapReaction.giggle:
      final k = _decay(t, 0.9);
      angle = math.sin(t * 2 * math.pi * 3.2) * 4 * deg * k;
      lift = math.sin(t * 2 * math.pi * 3.2).abs() * 0.02 * k;
    case FaceTapReaction.startle:
      // Up fast, down slower, a small squash on the landing.
      lift = t < 0.14
          ? 0.07 * _easeOut(t / 0.14)
          : t < 0.42
          ? 0.07 * (1 - _easeIn((t - 0.14) / 0.28))
          : 0;
      if (t >= 0.42) {
        final s = _squash(t - 0.42, press: 0.06, settle: 0.4, depth: 0.05);
        scaleY = 1 - s;
        scaleX = 1 + s * 0.6;
      }
    case FaceTapReaction.peek:
      lean = 0.025 * leanSign * mix;
      lift = 0.01 * mix;
    case FaceTapReaction.wink:
      angle = 3 * deg * leanSign * _hump(t, 0.1, 0.8);
    case FaceTapReaction.love:
      final s = 0.05 * _hump(t, 0.25, 1.3);
      scaleX = 1 + s;
      scaleY = 1 + s;
    case FaceTapReaction.dizzy:
      final k = t < 1.8 ? 1.0 : 1 - _ease((t - 1.8) / 0.6);
      angle = math.sin(t * 2 * math.pi * 0.9) * 3 * deg * k;
      lean = math.sin(t * 2 * math.pi * 0.45) * 0.015 * k;
    case FaceTapReaction.wake:
      lift = t < 0.1
          ? 0.04 * _easeOut(t / 0.1)
          : t < 0.4
          ? 0.04 * (1 - _easeIn((t - 0.1) / 0.3))
          : 0;
    case FaceTapReaction.notice:
      final s = 0.03 * _hump(t, 0.05, 0.4);
      scaleY = 1 - s;
      scaleX = 1 + s * 0.5;
  }

  return (
    mix: mix,
    scaleX: scaleX,
    scaleY: scaleY,
    angle: angle,
    lift: lift,
    lean: lean,
  );
}

/// Where the pupils look for a tap at [local] on a face of [size], in the
/// face's 200 unit box. The farther from the middle, the farther they look,
/// up to [reach].
Offset faceTapGaze(Offset local, Size size, {double reach = 9}) {
  if (size.isEmpty) return Offset.zero;
  final dx = (local.dx / size.width * 2 - 1).clamp(-1.0, 1.0);
  final dy = (local.dy / size.height * 2 - 1).clamp(-1.0, 1.0);
  return Offset(dx * reach, dy * reach);
}

/// A face smaller than this changes expression only and never moves. Motion
/// starts at about hero size.
const double kFaceTapMoveMinSize = 100;

/// A pressed squash: in over [press] seconds, then a springy release with
/// one small overshoot, done by [settle].
double _squash(
  double t, {
  required double press,
  required double settle,
  required double depth,
}) {
  if (t <= 0 || t >= settle) return 0;
  if (t < press) return depth * _easeOut(t / press);
  final u = (t - press) / (settle - press);
  // A damped cosine: from depth through a small stretch back to rest.
  return depth * math.cos(u * math.pi * 1.5) * (1 - u) * (1 - u);
}

/// Up and back down between [start] and [end], smooth at both ends.
double _hump(double t, double start, double end) {
  if (t <= start || t >= end) return 0;
  return math.sin((t - start) / (end - start) * math.pi);
}

/// From 1 down to 0 over [over] seconds.
double _decay(double t, double over) =>
    t >= over ? 0 : math.pow(1 - t / over, 2).toDouble();

double _ease(double x) {
  final v = x.clamp(0.0, 1.0);
  return v * v * (3 - 2 * v);
}

double _easeOut(double x) {
  final v = 1 - x.clamp(0.0, 1.0);
  return 1 - v * v * v;
}

double _easeIn(double x) {
  final v = x.clamp(0.0, 1.0);
  return v * v;
}
