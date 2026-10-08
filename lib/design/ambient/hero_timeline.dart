import 'dart:math' as math;

import 'package:critalarm/design_system/screen_clock.dart';
import 'package:flutter/foundation.dart';

// The hero scene's ambient layer as a table of loops, worked out from one
// clock: seconds since the scene appeared. Everything is a pure function of
// that number, so the resting frame is simply the frame at second zero and a
// capture can step to any second.
//
//   disc    breathes 1 -> 1.035 -> 1 over 9 s
//   ring    the same breath, starting 1.2 s later
//   dots    float up 9 points and back over 7 s, the second one 3.4 s later
//   face    bobs up 3 points and back over 3.8 s
//   blink   a lid closes for 0.16 s at gaps that look random and repeat
//           every 19 s
//   glance  pupils slide to the list, hold 1.5 s, and slide back

/// How long one breath of the disc and the ring takes.
const double heroBreatheSeconds = 9;

/// How far the disc and the ring grow at the top of a breath.
const double heroBreatheGrow = 0.035;

/// How long after the disc the ring starts to breathe.
const double heroRingDelaySeconds = 1.2;

/// How long a dot takes to float up and back.
const double heroFloatSeconds = 7;

/// How far a dot floats up, in points.
const double heroFloatRise = 9;

/// How long after the first dot the second one starts to float.
const double heroSecondDotDelaySeconds = 3.4;

/// How long the face takes to bob up and back.
const double heroBobSeconds = 3.8;

/// How far the face bobs up, in points.
const double heroBobRise = 3;

/// How long a blink keeps the lids shut, from first touch to open again.
const double heroBlinkSeconds = 0.16;

/// The gaps between blinks. They read as random and repeat as a set, so a
/// capture at one second always shows the same frame.
const List<double> heroBlinkGaps = [2.8, 4.1, 3.3, 5.2, 3.6];

/// How long the pupils take to slide away on a glance.
const double heroGlanceInSeconds = 0.35;

/// How long the pupils hold on the list.
const double heroGlanceHoldSeconds = 1.5;

/// How long the pupils take to slide back.
const double heroGlanceOutSeconds = 0.45;

/// What the ambient layer looks like at one moment.
@immutable
class HeroSceneFrame {
  const HeroSceneFrame({
    required this.discScale,
    required this.ringScale,
    required this.firstDotRise,
    required this.secondDotRise,
    required this.faceRise,
    required this.blink,
  });

  /// Scale of the disc, 1 at rest.
  final double discScale;

  /// Scale of the ring, 1 at rest.
  final double ringScale;

  /// How far the first dot has floated up, in points. 0 at rest.
  final double firstDotRise;

  /// How far the second dot has floated up, in points. 0 at rest.
  final double secondDotRise;

  /// How far the face has bobbed up, in points. 0 at rest.
  final double faceRise;

  /// How shut the lids are, 0 open to 1 shut. 0 at rest.
  final double blink;

  @override
  bool operator ==(Object other) =>
      other is HeroSceneFrame &&
      other.discScale == discScale &&
      other.ringScale == ringScale &&
      other.firstDotRise == firstDotRise &&
      other.secondDotRise == secondDotRise &&
      other.faceRise == faceRise &&
      other.blink == blink;

  @override
  int get hashCode => Object.hash(
    discScale,
    ringScale,
    firstDotRise,
    secondDotRise,
    faceRise,
    blink,
  );

  @override
  String toString() =>
      'HeroSceneFrame(disc $discScale, ring $ringScale, dots $firstDotRise '
      '$secondDotRise, face $faceRise, blink $blink)';
}

/// The frame the scene holds when nothing moves: reduce motion, a still
/// above, or a scene told it has no motion.
const HeroSceneFrame heroRestFrame = HeroSceneFrame(
  discScale: 1,
  ringScale: 1,
  firstDotRise: 0,
  secondDotRise: 0,
  faceRise: 0,
  blink: 0,
);

/// A smooth 0 to 1 and back over [period] seconds, starting after [delay].
/// Before [delay] it rests at 0, so a delayed loop does not start part way.
double _swell(double t, double period, {double delay = 0}) {
  final local = t - delay;
  if (local < 0) return 0;
  return 0.5 - 0.5 * math.cos(2 * math.pi * loopT(local, period) / period);
}

/// How shut the lids are at second [t], from 0 (open) to 1 (shut).
///
/// A blink closes and opens on a triangle over [heroBlinkSeconds]. The first
/// one lands at the first gap, so the opening frame is always open.
double heroBlink(double t) {
  if (t < 0) return 0;
  final cycle = heroBlinkGaps.fold<double>(0, (sum, gap) => sum + gap);
  final local = loopT(t, cycle);
  var start = 0.0;
  for (final gap in heroBlinkGaps) {
    start += gap;
    final into = local - start;
    if (into >= 0 && into < heroBlinkSeconds) {
      const half = heroBlinkSeconds / 2;
      return 1 - (into - half).abs() / half;
    }
  }
  return 0;
}

/// The ambient layer at second [t] of the scene's clock.
HeroSceneFrame heroTimeline(double t) => HeroSceneFrame(
  discScale: 1 + heroBreatheGrow * _swell(t, heroBreatheSeconds),
  ringScale:
      1 +
      heroBreatheGrow *
          _swell(t, heroBreatheSeconds, delay: heroRingDelaySeconds),
  firstDotRise: heroFloatRise * _swell(t, heroFloatSeconds),
  secondDotRise:
      heroFloatRise *
      _swell(t, heroFloatSeconds, delay: heroSecondDotDelaySeconds),
  faceRise: heroBobRise * _swell(t, heroBobSeconds),
  blink: heroBlink(t),
);

/// How far the pupils have slid from where they rest to the list, 0 to 1,
/// [since] seconds after a glance began. Before it began, and once it is
/// over, it is 0.
///
/// The slide out takes [heroGlanceInSeconds], the pupils hold for
/// [heroGlanceHoldSeconds], and the slide back takes [heroGlanceOutSeconds].
double heroGlance(double since) {
  if (since < 0) return 0;
  const hold = heroGlanceInSeconds + heroGlanceHoldSeconds;
  const end = hold + heroGlanceOutSeconds;
  if (since >= end) return 0;
  if (since < heroGlanceInSeconds) {
    return _easeInOut(since / heroGlanceInSeconds);
  }
  if (since < hold) return 1;
  return 1 - _easeInOut((since - hold) / heroGlanceOutSeconds);
}

/// How long a glance lasts, start to finish.
const double heroGlanceSeconds =
    heroGlanceInSeconds + heroGlanceHoldSeconds + heroGlanceOutSeconds;

double _easeInOut(double x) => x * x * (3 - 2 * x);
