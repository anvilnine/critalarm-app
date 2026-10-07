import 'dart:math' as math;

import 'package:critalarm/features/onboarding/domain/welcome_timing.dart';

/// A moment in a setup animation that the phone answers with a haptic.
enum HeroCue {
  /// A ladder card slid into place.
  cardLands,

  /// The terminal typed a character.
  typeTick,

  /// The terminal sent its command.
  commandSent,

  /// One beat of a ringing phone.
  ringPulse,
}

/// A [HeroCue] and when it plays, in seconds on the animation's own clock.
typedef TimedCue = ({double at, HeroCue cue});

/// A cue this many seconds late or more is skipped. After a dropped frame,
/// or a hero that was hidden for a while, the old cues are gone for good
/// and never play as a burst.
const double cueMaxLateness = 0.1;

/// Typing ticks never come closer together than this: 25 a second.
const double typeTickMinGap = 1 / 25;

/// A tick this close behind the last one played is skipped. Frames do not
/// land on the schedule, so two ticks 40 ms apart can play 33 ms apart on a
/// 60 Hz screen, and that is fine. A tick that played late with the next one
/// right on its heels is not.
const double typeTickChaseGap = typeTickMinGap / 2;

/// Android ticks once for this many typed characters.
const int typeTickEveryOnAndroid = 3;

/// When the terminal starts typing, on its hero's clock.
const double terminalTypingStartsAt = 0.3;

/// How long the terminal takes to type the whole command.
const double terminalTypingTakes = 1.9;

/// How fast a ringing phone shakes: the drawing turns by `sin(t * rate)`.
const double phoneShakeRate = 50;

/// How fast the ringing ladder card shakes.
const double ladderShakeRate = 60;

/// A ringing phone pulses once for this many shakes.
const int ringPulseEveryShakes = 4;

/// The most pulses one ring plays. They come at the start of the ring, and
/// after them the drawing carries it alone.
const int ringPulseMax = 4;

/// The cues in [schedule] that play when the clock moves from [a] to [b]:
/// later than [a], no later than [b], and less than [maxLateness] old at
/// [b]. Each kind is listed once however many of it fell in the window, so
/// one frame never plays the same haptic twice.
List<HeroCue> heroCuesBetween(
  List<TimedCue> schedule,
  double a,
  double b, {
  double maxLateness = cueMaxLateness,
}) {
  if (b <= a) return const [];
  final from = math.max(a, b - maxLateness);
  final due = <HeroCue>{};
  for (final timed in schedule) {
    if (timed.at > from && timed.at <= b) due.add(timed.cue);
  }
  return due.toList();
}

/// Walks one hero's [schedule] as its clock moves forward. A schedule holds
/// the clock times of one pass of the hero's story. A hero whose story
/// starts over every [loopsEvery] seconds plays its cues again on every
/// pass. With no [loopsEvery] the story plays once.
class HeroCueClock {
  HeroCueClock(this.schedule, {this.loopsEvery});

  final List<TimedCue> schedule;

  /// How long one pass of the story takes, or null when it does not loop.
  final double? loopsEvery;

  double _at = 0;
  double _lastTickAt = double.negativeInfinity;

  /// The cues to play now that the clock reads [seconds]. Call it on every
  /// frame, also while the hero may not play anything, so that cues it
  /// missed are not kept for later.
  List<HeroCue> advanceTo(double seconds) {
    final every = loopsEvery;
    final now = every == null ? seconds : seconds % every;
    if (now < _at) {
      // The story started over. What was left of the last pass is dropped.
      _at = 0;
      _lastTickAt = double.negativeInfinity;
    }
    final due = heroCuesBetween(schedule, _at, now);
    _at = now;
    if (due.contains(HeroCue.typeTick)) {
      // A tick that played late must not be chased by the next one.
      if (now - _lastTickAt < typeTickChaseGap) {
        due.remove(HeroCue.typeTick);
      } else {
        _lastTickAt = now;
      }
    }
    return due;
  }
}

/// One tick per typed character of a command [length] characters long, then
/// the send. Ticks closer together than [typeTickMinGap] are left out, and
/// Android ticks on every third character. The last character has no tick
/// of its own: the send plays there. The typing starts at [startsAt] and
/// lasts [takes], which are the story terminal's unless given.
List<TimedCue> typingCues({
  required int length,
  required bool isAndroid,
  double startsAt = terminalTypingStartsAt,
  double takes = terminalTypingTakes,
}) {
  final end = startsAt + takes;
  final every = isAndroid ? typeTickEveryOnAndroid : 1;
  final cues = <TimedCue>[];
  var last = double.negativeInfinity;
  for (var typed = every; typed < length; typed += every) {
    final at = startsAt + takes * typed / length;
    // The small allowance keeps a gap of exactly the limit from being
    // dropped by rounding.
    if (at - last < typeTickMinGap - 1e-9) continue;
    if (end - at < typeTickMinGap - 1e-9) break;
    cues.add((at: at, cue: HeroCue.typeTick));
    last = at;
  }
  if (length > 0) cues.add((at: end, cue: HeroCue.commandSent));
  return cues;
}

/// Pulses for a phone that rings from [from] until [to] and shakes at
/// [shakeRate]. One pulse every [ringPulseEveryShakes] shakes, so the pulses
/// keep time with the drawing, and no more than [ringPulseMax] of them, all
/// at the start of the ring.
List<TimedCue> ringCues({
  required double from,
  required double to,
  double shakeRate = phoneShakeRate,
}) {
  final gap = ringPulseEveryShakes * 2 * math.pi / shakeRate;
  return [
    for (var n = 0; n < ringPulseMax && from + n * gap < to; n++)
      (at: from + n * gap, cue: HeroCue.ringPulse),
  ];
}

/// The priority ladder: each card landing, then the first pulses of the
/// last card ringing.
List<TimedCue> ladderCues() => [
  for (var index = 0; index < ladderCardCount; index++)
    (at: ladderCardShownAt(index), cue: HeroCue.cardLands),
  ...ringCues(
    from: ladderRingStartsAt,
    to: ladderRingEndsAt,
    shakeRate: ladderShakeRate,
  ),
];
