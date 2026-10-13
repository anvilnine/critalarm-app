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

/// A cloud: where it is centred across and down before the lift, in
/// reference points, and how wide it is.
typedef BreakLiftCloud = ({double x, double y, double width});

/// The three depths of cloud, slowest first.
enum BreakLiftLayer { far, mid, near }

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
  static const double starReach = 300;

  /// How far each layer of cloud falls in the whole lift, in reference
  /// points. Every layer rides the one eased [lift], so the speed of all of
  /// them follows the same sine and none starts or stops on its own.
  static const double farReach = 520;
  static const double midReach = 860;
  static const double nearReach = 1300;

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

  /// The night is all the way in. It is on before the welcome line shows,
  /// so the line reads on it.
  static const double nightTo = 1.7;

  /// How much night shows where the wall was, 0 to 1. It eases in from
  /// the hit, never at once.
  static double night(double t) => _night(t);

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
          slide: [0.2, 0.35, 0.55][depth],
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

  /// What shows behind and between the pieces: [ground], the colour the
  /// screen is at the hit, easing into [night] and never lighter than
  /// [ground] on the way. There is no paper step and no flash.
  static Color backdrop(
    double t, {
    required Color ground,
    required Color night,
  }) {
    final target = night.computeLuminance() <= ground.computeLuminance()
        ? night
        : ground;
    return Color.lerp(ground, target, _night(t))!;
  }

  static double _night(double t) => sine(phase(t, hit, nightTo));

  static double _unit(Size size) => math.min(
    size.width / reference.width,
    size.height / reference.height,
  );

  // ---- the clouds

  /// How far layer [layer] falls in the lift, in reference points.
  static double reach(BreakLiftLayer layer) => switch (layer) {
    BreakLiftLayer.far => farReach,
    BreakLiftLayer.mid => midReach,
    BreakLiftLayer.near => nearReach,
  };

  /// How tall a cloud is against its width.
  static const double cloudRatio = 0.36;

  static const List<BreakLiftCloud> _far = [
    (x: 70, y: -60, width: 84),
    (x: 330, y: -170, width: 70),
    (x: 150, y: -280, width: 96),
    (x: 350, y: -390, width: 76),
    (x: 60, y: -480, width: 88),
  ];
  static const List<BreakLiftCloud> _mid = [
    (x: 340, y: -80, width: 150),
    (x: 50, y: -260, width: 130),
    (x: 300, y: -440, width: 150),
    (x: 60, y: -620, width: 160),
    (x: 330, y: -800, width: 140),
  ];

  /// Near clouds hang off the sides so that a part shows, and fall faster
  /// than everything else. They pass beside him and never touch him.
  static const List<BreakLiftCloud> _near = [
    (x: 500, y: -160, width: 300),
    (x: -112, y: -540, width: 320),
    (x: 506, y: -920, width: 320),
    (x: -106, y: -1260, width: 300),
  ];

  /// The clouds of [layer], as they sit before the lift: every one above
  /// the screen, so each comes in from the top already on its way.
  static List<BreakLiftCloud> clouds(BreakLiftLayer layer) => switch (layer) {
    BreakLiftLayer.far => _far,
    BreakLiftLayer.mid => _mid,
    BreakLiftLayer.near => _near,
  };

  /// Where cloud [i] of [layer] is centred at [t]. It only falls, by
  /// [reach] times the one eased lift.
  static Offset cloudAt(BreakLiftLayer layer, int i, double t, Size size) {
    final cloud = clouds(layer)[i];
    final k = _unit(size);
    return Offset(
      cloud.x * size.width / reference.width,
      (cloud.y + reach(layer) * lift(t)) * k,
    );
  }

  /// The whole of cloud [i]: the pill and its bumps.
  static Rect cloudBox(BreakLiftLayer layer, int i, double t, Size size) {
    final width = clouds(layer)[i].width * _unit(size);
    final height = width * cloudRatio;
    final c = cloudAt(layer, i, t, size);
    return Rect.fromLTRB(
      c.dx - width / 2,
      c.dy - height * 0.56,
      c.dx + width / 2,
      c.dy + height * 0.5,
    );
  }

  /// How much of the clouds shows: they come with the night they sit on.
  static double cloudAlpha(double t) => _night(t);

  // ---- the plume

  /// How solid the plume under him is, 0 at rest.
  static double plumeAlpha(double t) => 0.85 * speed(t);

  /// How long the plume is, in points. It breathes a little on the clock.
  static double plumeLength(double t, Size size) =>
      150 * _unit(size) * speed(t) * (1 + 0.05 * math.sin(t * 6.5));

  /// How wide the plume is where it leaves him, in points.
  static double plumeWidth(double t, Size size) => 110 * _unit(size) * speed(t);

  /// How far the tip of the plume sways to one side, in points: a slow
  /// sine on the clock that comes and goes with the speed.
  static double plumeSway(double t, Size size) =>
      10 * _unit(size) * speed(t) * math.sin(t * 5);

  /// How far down he has sunk to go, 0 to 1 and back: eased in from
  /// 0.62, at its deepest as the lift starts and eased out as he rises.
  static double crouch(double t) =>
      sine(phase(t, 0.62, liftFrom)) * (1 - sine(phase(t, liftFrom, 1.3)));

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
    final aspect = land.width == 0 ? 1.0 : land.height / land.width;
    if (t >= liftTo) {
      return BreakLiftRingPose(
        centre: land.center,
        size: land.width,
        squashY: aspect,
        face: face(t),
      );
    }
    final hang = sine(phase(t, hit, liftFrom));
    final hangSize = _lerp(300, 252, hang) * k;
    final hangCentre = Offset(195 * sx, _lerp(350, 388, hang) * sy);
    final rise = lift(t);
    final fly = speed(t);
    final sunk = crouch(t);
    final bend = math.sin(math.pi * rise);
    return BreakLiftRingPose(
      // He sinks, goes, and arcs a little to one side on the way up.
      centre: Offset(
        _lerp(hangCentre.dx, land.center.dx, rise) + 24 * k * bend,
        _lerp(hangCentre.dy, land.center.dy, rise) + 16 * k * sunk,
      ),
      size: _lerp(hangSize, land.width, rise),
      // Squashed in the crouch, a little long in the flight.
      squashX: (1 - 0.05 * fly) * (1 + 0.05 * sunk),
      squashY: _lerp(1, aspect, rise) * (1 + 0.1 * fly) * (1 - 0.08 * sunk),
      // He leans into the arc: one way going out, the other coming back.
      angle: 0.06 * math.sin(2 * math.pi * rise),
      face: face(t),
    );
  }

  /// Two light taps: the hit and the arrival.
  static const List<PaywallThanksBeat> beats = [
    PaywallThanksBeat.tap(hit, HapticPattern.light),
    PaywallThanksBeat.tap(liftTo, HapticPattern.light),
  ];
}
