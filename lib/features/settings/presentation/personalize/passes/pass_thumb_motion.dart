import 'dart:math' as math;

// The motion of the two thumbnails on the Personalize root that move: the
// Look pass's mini phone and the Sound pass's bars. Pure functions of one
// clock, in seconds, so they are tested and a capture can freeze them. Each
// has a complete resting frame, which reduce motion and a held clock show.

/// How long the mini phone takes for one rock there and back, in seconds.
const double passThumbRockPeriod = 1.2;

/// How far the mini phone swings either side of upright, in degrees.
const double passThumbRockDegrees = 4;

/// The mini phone's angle at clock [t] in degrees, positive clockwise. It is
/// 0 at t = 0, swings [passThumbRockDegrees] either side of upright, and
/// repeats every [passThumbRockPeriod] seconds. With [isStill] it is the
/// resting frame, upright.
double passThumbRock(double t, {bool isStill = false}) {
  if (isStill) return 0;
  return passThumbRockDegrees * math.sin(2 * math.pi * t / passThumbRockPeriod);
}

/// How long one bar takes to rise and fall, in seconds.
const double passBarPeriod = 1;

/// How many bars the Sound thumbnail has.
const int passBarCount = 8;

/// The shortest a bar gets while it moves, as a share of its full height.
const double passBarLow = 0.5;

/// The delay of bar [index] in seconds. Counting bars from 1, every second
/// bar waits 0.15 s and every third waits 0.3 s, and a bar that is both
/// (the sixth) waits 0.3 s.
double passBarDelay(int index) {
  final n = index + 1;
  if (n % 3 == 0) return 0.3;
  if (n.isEven) return 0.15;
  return 0;
}

/// The vertical scale of bar [index] at clock [t], from [passBarLow] up to
/// 1. With [isStill] every bar is at full height: the resting frame.
double passBarScale(int index, double t, {bool isStill = false}) {
  if (isStill) return 1;
  final phase = (t - passBarDelay(index)) / passBarPeriod;
  // A bar starts low, rises to full height at half a period and comes back.
  final wave = 0.5 - 0.5 * math.cos(2 * math.pi * phase);
  return passBarLow + (1 - passBarLow) * wave;
}

/// The least height a bar has, as a share of the thumbnail's height.
const double passBarFloor = 0.18;

/// The most height a bar has.
const double passBarCeiling = 0.94;

/// The heights of the [passBarCount] bars as shares of the thumbnail's
/// height, from the sound's loudness [peaks] (0 to 1, in even slices).
///
/// Each bar is the mean of its slice, scaled so the loudest bar reaches
/// [passBarCeiling]. A sound with no peaks gets [passBarCount] flat low bars
/// at [passBarFloor], which the thumbnail holds still: nothing that looks
/// like a waveform but is not one.
List<double> passBarHeights(List<double>? peaks) {
  if (peaks == null || peaks.length < passBarCount) {
    return List<double>.filled(passBarCount, passBarFloor);
  }
  final means = <double>[];
  for (var i = 0; i < passBarCount; i++) {
    final from = (i * peaks.length / passBarCount).floor();
    final to = math.max(
      from + 1,
      ((i + 1) * peaks.length / passBarCount).floor(),
    );
    var sum = 0.0;
    for (var j = from; j < to; j++) {
      sum += peaks[j].clamp(0.0, 1.0);
    }
    means.add(sum / (to - from));
  }
  final loudest = means.reduce(math.max);
  if (loudest <= 0) return List<double>.filled(passBarCount, passBarFloor);
  return [
    for (final mean in means)
      passBarFloor + (passBarCeiling - passBarFloor) * (mean / loudest),
  ];
}

/// Whether the Sound thumbnail moves for [peaks]: only a real waveform does.
bool passBarsMove(List<double>? peaks) =>
    peaks != null && peaks.length >= passBarCount;
