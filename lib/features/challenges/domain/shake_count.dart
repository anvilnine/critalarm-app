import 'dart:math';

import 'package:critalarm/core/motion/motion_sensor.dart';

/// The numbers of the shake rule, in one place.
///
/// None of them was measured on a phone in a hand. Each comes from the
/// reasoning next to it and wants a try on a real iPhone and a real Android
/// phone before it ships: above all [threshold] and [minGap], which decide
/// how hard and how fast a person has to shake.
abstract final class ShakeRule {
  /// How many shakes pass the challenge. The idea board said 40. 30 is long
  /// enough to wake the arms and short enough that the phone stays in the
  /// hand: at the fastest pace [minGap] allows it is 7.5 seconds, and at an
  /// easy two a second it is 15.
  static const int target = 30;

  /// How hard a movement must be, in g with gravity taken out, before it
  /// can be part of a shake.
  ///
  /// A phone carried on a walk moves at about 0.3 to 0.8 g, and a heel
  /// strike in a pocket can reach 1 g. A phone shaken by hand passes 2 g
  /// with ease. The shake detectors Android apps commonly copy ask for
  /// 2.7 g with gravity still in, which is 1.7 g without it when the shake
  /// is along gravity. 1.5 sits above a walk and under a real shake.
  static const double threshold = 1.5;

  /// How far a hard movement must turn from the last one to be the way
  /// back: the cosine of the angle between the two, at most this. -0.5 is
  /// 120 degrees or more. A straight shake turns 180. A tighter number
  /// would refuse a shake that curves through the wrist, and a looser one
  /// would count a swirl.
  static const double reversalDot = -0.5;

  /// The least time between two counts, so one swing out and back is one
  /// shake however many readings it spans. A hand shakes a phone three to
  /// five times a second, and 250 ms lets four of those through. It is also
  /// what keeps 30 from being done in two seconds.
  static const Duration minGap = Duration(milliseconds: 250);

  /// How long after a hard movement the way back still belongs to it.
  /// Slower than this is a wave of the arm, a turn of the wrist or one
  /// knock, and the next hard movement starts over. 500 ms is half of a
  /// one-a-second back and forth.
  static const Duration reversalWindow = Duration(milliseconds: 500);

  /// How fast the gravity estimate follows the readings: the time constant
  /// of the low pass. At 300 ms it lets about a tenth of a 4 a second shake
  /// through, so nearly all of the shake is left once it is taken out, and
  /// it still settles within a second of the phone being turned over.
  static const Duration gravitySettle = Duration(milliseconds: 300);

  /// A hole in the stream this long means what was known is stale: gravity
  /// is taken from the next reading and a half-made shake is dropped. The
  /// sensor reports about every 20 ms, so this is 25 missed readings.
  static const Duration streamGap = Duration(milliseconds: 500);

  /// How long the sensor may give nothing before taps are offered. The
  /// task's number: long enough for a slow sensor to start, short enough
  /// that nobody is left shaking at a phone that cannot feel it.
  static const Duration silentAfter = Duration(seconds: 5);
}

/// Counts shakes in a stream of accelerometer readings.
///
/// A shake is a hard movement followed, soon, by a hard movement the other
/// way:
///
/// 1. Gravity is taken out with a low pass ([ShakeRule.gravitySettle]), so
///    a phone at rest reads nothing whichever way it lies.
/// 2. What is left must be at least [ShakeRule.threshold].
/// 3. It must point away from the last hard movement
///    ([ShakeRule.reversalDot]) within [ShakeRule.reversalWindow].
/// 4. Two counts are at least [ShakeRule.minGap] apart.
///
/// It knows no clock but the readings' own, no widget and no sensor, so the
/// same readings always give the same count.
final class ShakeCounter {
  int _count = 0;

  double _gravityX = 0;
  double _gravityY = 0;
  double _gravityZ = 0;
  Duration? _lastAt;

  /// The direction of the last hard movement, one unit long, and when the
  /// phone last moved hard without turning back.
  double _fromX = 0;
  double _fromY = 0;
  double _fromZ = 0;
  Duration? _fromAt;

  Duration? _countedAt;

  /// How many shakes so far.
  int get count => _count;

  /// Takes one reading. True when it completed a shake.
  bool add(MotionReading reading) {
    final x = reading.x;
    final y = reading.y;
    final z = reading.z;
    if (!x.isFinite || !y.isFinite || !z.isFinite) return false;
    final at = reading.at;
    final last = _lastAt;
    // The same stamp twice is one reading delivered twice. It says nothing
    // new, and no time has passed to measure it over.
    if (last != null && at == last) return false;
    _lastAt = at;
    if (last == null || at < last || at - last > ShakeRule.streamGap) {
      // The first reading, a clock that went back, or a hole in the stream.
      // Gravity is whatever the phone reads now, and nothing is half made.
      _gravityX = x;
      _gravityY = y;
      _gravityZ = z;
      _fromAt = null;
      _countedAt = null;
      return false;
    }

    final step = (at - last).inMicroseconds;
    final share = step / (ShakeRule.gravitySettle.inMicroseconds + step);
    _gravityX += share * (x - _gravityX);
    _gravityY += share * (y - _gravityY);
    _gravityZ += share * (z - _gravityZ);

    final moveX = x - _gravityX;
    final moveY = y - _gravityY;
    final moveZ = z - _gravityZ;
    final strength = sqrt(moveX * moveX + moveY * moveY + moveZ * moveZ);
    if (strength < ShakeRule.threshold) return false;

    final toX = moveX / strength;
    final toY = moveY / strength;
    final toZ = moveZ / strength;
    final fromAt = _fromAt;
    _fromAt = at;
    if (fromAt == null || at - fromAt > ShakeRule.reversalWindow) {
      // The first hard movement, or the last one was too long ago to be
      // the other half of this one.
      _fromX = toX;
      _fromY = toY;
      _fromZ = toZ;
      return false;
    }
    final turn = toX * _fromX + toY * _fromY + toZ * _fromZ;
    // Still going the same way, or off to one side.
    if (turn > ShakeRule.reversalDot) return false;

    // The way back. The next shake is measured from here.
    _fromX = toX;
    _fromY = toY;
    _fromZ = toZ;
    final countedAt = _countedAt;
    if (countedAt != null && at - countedAt < ShakeRule.minGap) return false;
    _countedAt = at;
    _count++;
    return true;
  }
}

/// How many shakes [readings] hold.
int countShakes(Iterable<MotionReading> readings) {
  final counter = ShakeCounter();
  readings.forEach(counter.add);
  return counter.count;
}

/// How Crit takes the shaking, from the first shake to the last.
enum ShakeMood {
  /// Nothing yet. Watching, waiting for it.
  ready,

  /// The first third. Wide eyed.
  jolted,

  /// The middle third. Eyes squeezed shut, holding on.
  squeezed,

  /// The last third. Spiral eyes.
  dizzy,
}

/// The face for [count] shakes out of [target]: the table of the one
/// timeline this challenge has. It only ever moves forward.
ShakeMood shakeMoodFor(int count, {int target = ShakeRule.target}) {
  if (count <= 0 || target <= 0) return ShakeMood.ready;
  final share = count / target;
  if (share < 1 / 3) return ShakeMood.jolted;
  if (share < 2 / 3) return ShakeMood.squeezed;
  return ShakeMood.dizzy;
}

/// How much of the way to [target] [count] is, from 0 to 1.
double shakeProgress(int count, {int target = ShakeRule.target}) {
  if (target <= 0) return 1;
  return (count / target).clamp(0.0, 1.0);
}

/// The most the face rocks to one side after a shake, in radians: about 3
/// degrees after the first and 12 after the last. The dizzier, the further.
double shakeRockReach(int count, {int target = ShakeRule.target}) =>
    (3 + 9 * shakeProgress(count, target: target)) * pi / 180;

/// The angle of the face [t] of the way through the rock one shake sets
/// off, with [t] from 0 to 1. It swings out, back through the middle, a
/// little the other way, and ends at exactly zero: the face never rests at
/// an angle.
double shakeRockAngle(int count, double t, {int target = ShakeRule.target}) {
  if (count <= 0 || t <= 0 || t >= 1) return 0;
  return shakeRockReach(count, target: target) * sin(2 * pi * t) * (1 - t);
}
