import 'dart:math' as math;
import 'dart:ui';

import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks_rules.dart';
import 'package:critalarm/features/paywall/presentation/outros/break_lift_ring/break_lift_ring_timeline.dart';

export 'package:critalarm/features/paywall/presentation/outros/break_lift_ring/break_lift_ring_timeline.dart'
    show BreakLiftRingPose, BreakPiece;

// The calm cut of Break, lift, ring as numbers. Crit breaks the paywall and
// rises into the night in one eased move. There is no flash, no ring, no
// cut and no word that pops: every value below is a smooth function of the
// seconds since the purchase, so any second can be drawn and tested alone.
// The wind up and the pieces of the wall are Break, lift, ring's own.

/// A star: where it sits across the screen and down it before the rise, as
/// shares of the screen, its edge and the share of the rise it slides by.
typedef BreakLiftStar = ({
  double x,
  double y,
  double edge,
  double slide,
  double alpha,
});

abstract final class BreakLiftTimeline {
  /// The reference screen the numbers are worked out on.
  static const Size reference = BreakLiftRingTimeline.reference;

  /// The wall breaks: Crit reaches the screen.
  static const double hit = BreakLiftRingTimeline.hit;

  /// He hangs, glad, from the hit to here, and the lift starts.
  static const double liftFrom = 0.9;

  /// The lift ends: he is at rest where the end state stands him.
  static const double liftTo = 2.4;

  /// The welcome line fades in at [wordsFrom] and is out again at
  /// [wordsTo].
  static const double wordsFrom = 1.45;
  static const double wordsTo = 2.5;

  /// The end state is built under the outro from here and the night fades
  /// off it.
  static const double uncover = 2.6;

  /// The swap.
  static const double end = 2.8;

  /// How far the stars slide down the screen in the whole lift, in
  /// reference points, for a star that slides by one.
  static const double starReach = 320;

  /// The sine ease: 0 at 0, 1 at 1, slow at both ends.
  static double sine(double x) =>
      (1 - math.cos(math.pi * x.clamp(0.0, 1.0))) / 2;

  static double phase(double t, double a, double b) =>
      BreakLiftRingTimeline.phase(t, a, b);

  static double _lerp(double a, double b, double x) =>
      x >= 1 ? b : a + (b - a) * x;

  /// How far through the lift, 0 to 1. One sine ease, fastest at its
  /// middle, 1.65.
  static double lift(double t) => sine(phase(t, liftFrom, liftTo));

  /// How fast the lift is, 0 at both ends and 1 in the middle, easing in
  /// and out so what hangs on it never has a corner.
  static double speed(double t) {
    final s = math.sin(math.pi * phase(t, liftFrom, liftTo));
    return s * s;
  }

  // ---- the night

  /// How much night shows where the wall was, 0 to 1. It comes in
  /// together with the lift's whole length, never at once.
  static double night(double t) => sine(phase(t, hit, liftTo));

  /// How far the outro has faded off the end state, 0 at [uncover] and 1
  /// at [end].
  static double fadeOut(double t) => sine(phase(t, uncover, end));

  /// 44 seeded stars in three depths. They do not twinkle: each one only
  /// slides, at the rate of its depth.
  static final List<BreakLiftStar> stars = List.unmodifiable([
    for (var i = 0; i < 44; i++)
      () {
        final depth = i % 3;
        return (
          x: 0.04 + BreakLiftRingTimeline.rnd(i + 90) * 0.92,
          y: -0.38 + BreakLiftRingTimeline.rnd(i + 91) * 1.34,
          edge: [1.6, 2.4, 3.4][depth] + BreakLiftRingTimeline.rnd(i + 92),
          slide: [0.25, 0.5, 0.85][depth],
          alpha: 0.35 + depth * 0.2 + BreakLiftRingTimeline.rnd(i + 93) * 0.15,
        );
      }(),
  ]);

  /// Where star [i] is at [t] on a screen of [size].
  static Offset starAt(int i, double t, Size size) {
    final star = stars[i];
    final k = math.min(
      size.width / reference.width,
      size.height / reference.height,
    );
    return Offset(
      star.x * size.width,
      star.y * size.height + lift(t) * star.slide * starReach * k,
    );
  }

  /// How solid the trail under him is: one soft column that comes with the
  /// speed of the lift and goes with it.
  static double trailAlpha(double t) => 0.38 * speed(t);

  /// How long the trail is, in points.
  static double trailLength(double t, Size size) {
    final k = math.min(
      size.width / reference.width,
      size.height / reference.height,
    );
    return 150 * k * speed(t);
  }

  // ---- the wall

  /// The 56 pieces of the wall, the same ones Break, lift, ring breaks.
  static List<BreakPiece> pieces(Size size) =>
      BreakLiftRingTimeline.pieces(size);

  /// Where [piece] is at [t]: its offset from where it started, its turn
  /// in radians, its scale and how solid it is. It drifts off slower than
  /// in Break, lift, ring, grows far less towards the viewer, and fades out
  /// as it goes.
  static ({Offset shift, double turn, double scale, double alpha}) flightOf(
    BreakPiece piece,
    double t, {
    required double k,
  }) {
    final q = phase(t, hit, hit + 1.3);
    final e = 1 - (1 - q) * (1 - q);
    return (
      shift: Offset(
        piece.velocity.dx * 0.4 * e,
        piece.velocity.dy * 0.4 * e + 180 * k * e * e,
      ),
      turn: piece.spin * 0.5 * e,
      scale: 1 + piece.depth * piece.depth * 0.4 * e,
      alpha: 1 - sine(phase(t, hit + 0.3, hit + 0.85)),
    );
  }

  // ---- the words

  /// The welcome line, whole, in one place: in, then out, once.
  static double wordsAlpha(double t) =>
      sine(phase(t, wordsFrom, wordsFrom + 0.5)) *
      (1 - sine(phase(t, wordsTo - 0.5, wordsTo)));

  // ---- Crit

  /// His face at [t]: set for the hit, glad after it, and the end state's
  /// own once it opens.
  static FaceState face(double t) {
    if (t < hit) return FaceState.determined;
    if (t < uncover) return FaceState.happy;
    return FaceState.surprised;
  }

  /// His pose at [t] on a screen of [size].
  ///
  /// [mascot] is where the layout's own Crit stood (null: he starts at the
  /// stage), [land] where the end state's Crit stands at [end]. From
  /// [liftTo] on the box is exactly [land], upright and unsquashed in
  /// width.
  static BreakLiftRingPose pose(
    double t, {
    required Size size,
    required Rect land,
    Rect? mascot,
  }) {
    if (t < hit) {
      return BreakLiftRingTimeline.pose(
        t,
        size: size,
        land: land,
        mascot: mascot,
      );
    }
    final sx = size.width / reference.width;
    final sy = size.height / reference.height;
    final k = math.min(sx, sy);
    final hang = sine(phase(t, hit, liftFrom));
    final hangSize = _lerp(300, 308, hang) * k;
    final hangCentre = Offset(195 * sx, _lerp(350, 362, hang) * sy);
    final rise = lift(t);
    final aspect = land.width == 0 ? 1.0 : land.height / land.width;
    return BreakLiftRingPose(
      centre: Offset(
        _lerp(hangCentre.dx, land.center.dx, rise),
        _lerp(hangCentre.dy, land.center.dy, rise),
      ),
      size: _lerp(hangSize, land.width, rise),
      squashY: _lerp(1, aspect, rise),
      face: face(t),
    );
  }

  /// Two light taps: the hit and the arrival.
  static const List<PaywallThanksBeat> beats = [
    PaywallThanksBeat.tap(hit, HapticPattern.light),
    PaywallThanksBeat.tap(liftTo, HapticPattern.light),
  ];
}
