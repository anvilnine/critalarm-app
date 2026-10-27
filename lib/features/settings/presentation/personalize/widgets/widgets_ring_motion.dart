import 'dart:math' as math;

// The one motion on the Widgets page: the face on the large Open incidents
// widget rings a few degrees either side of upright for one second, twice,
// and then rests. A pure function of one clock, in seconds since the page
// appeared, so it is tested and a capture can freeze it. Its resting frame is
// upright, which reduce motion and every moment outside the two rings show.

/// When the first ring starts, in seconds. The page grows in over 0.6 s, so
/// the ring starts as the body is fully there.
const double widgetsRingBegin = 0.6;

/// How long one ring lasts, in seconds.
const double widgetsRingLength = 1;

/// The quiet gap between the two rings, in seconds.
const double widgetsRingGap = 0.4;

/// How many rings there are.
const int widgetsRingCount = 2;

/// How many swings, there and back, one ring makes.
const int widgetsRingSwings = 4;

/// The most the face turns either side of upright, in degrees.
const double widgetsRingDegrees = 5;

/// When the last ring ends, and the face rests for good, in seconds.
const double widgetsRingEnd =
    widgetsRingBegin +
    widgetsRingCount * widgetsRingLength +
    (widgetsRingCount - 1) * widgetsRingGap;

/// The face's angle at clock [t] in degrees, positive clockwise.
///
/// It is 0 before the first ring, between the two rings and after the
/// second. Inside a ring it swings [widgetsRingSwings] times, its reach
/// swelling from nothing to [widgetsRingDegrees] and back to nothing, so a
/// ring starts and ends upright. With [isStill] it is the resting frame.
double widgetsRingAngle(double t, {bool isStill = false}) {
  if (isStill) return 0;
  for (var i = 0; i < widgetsRingCount; i++) {
    final start = widgetsRingBegin + i * (widgetsRingLength + widgetsRingGap);
    final p = (t - start) / widgetsRingLength;
    if (p < 0 || p > 1) continue;
    return widgetsRingDegrees *
        math.sin(math.pi * p) *
        math.sin(2 * math.pi * widgetsRingSwings * p);
  }
  return 0;
}
