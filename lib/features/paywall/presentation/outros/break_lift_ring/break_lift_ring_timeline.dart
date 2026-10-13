import 'dart:math' as math;
import 'dart:ui';

import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks_rules.dart';
import 'package:critalarm/features/paywall/presentation/outros/break_pieces.dart';

export 'package:critalarm/features/paywall/presentation/outros/break_pieces.dart'
    show BreakPiece;

// The Pro outro as numbers. Crit breaks the paywall like a wall, lifts off
// into the night, slows to a stop in the middle of the sky, and three rings
// fire from him with one word each. Everything is a function of the seconds
// since the purchase, so any second can be drawn and tested alone. Places
// are worked out on a 390 by 844 screen and scaled to the real one.

/// Where Crit stands, how big he is and how he leans, at one second.
class BreakLiftRingPose {
  const BreakLiftRingPose({
    required this.centre,
    required this.size,
    required this.face,
    this.squashX = 1,
    this.squashY = 1,
    this.angle = 0,
  });

  /// The middle of the box he is drawn in.
  final Offset centre;

  /// The edge of the square he is drawn in, before the squash.
  final double size;
  final FaceState face;

  /// His width and height against [size]. One at rest.
  final double squashX;
  final double squashY;

  /// Radians.
  final double angle;

  /// The box he fills, squash included.
  Rect get box => Rect.fromCenter(
    center: centre,
    width: size * squashX,
    height: size * squashY,
  );

  /// The smallest upright box that holds him as he leans, which is what
  /// must stay on screen.
  Rect get turnedBox {
    final cos = math.cos(angle).abs();
    final sin = math.sin(angle).abs();
    final w = size * squashX;
    final h = size * squashY;
    return Rect.fromCenter(
      center: centre,
      width: w * cos + h * sin,
      height: w * sin + h * cos,
    );
  }
}

abstract final class BreakLiftRingTimeline {
  /// The reference screen the numbers below are worked out on.
  static const Size reference = Size(390, 844);

  /// The wall breaks: Crit reaches the screen.
  static const double hit = 0.36;

  /// The hard cut to the night.
  static const double cut = 1.15;

  /// The night holds Crit still, in the middle of the sky.
  static const double sky = 2.10;

  /// The ring part's own zero. Its beats and the dip are read from here.
  static const double ringsFrom = 1.8;

  /// The three rings, each with its word.
  static const List<double> rings = [2.20, 2.46, 2.72];

  /// The rings are done and the cobalt disc grows.
  static const double cobalt = 3.10;

  /// The yellow floods out and the end state shows under it.
  static const double uncover = 3.55;

  /// The swap. Crit stands on the end state's own.
  static const double end = 3.75;

  static const int cols = 4;
  static const int rowCount = 7;
  static const int pieceCount = cols * rowCount * 2;

  /// Seconds the rings last.
  static const double ringSeconds = 0.52;

  static double phase(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);
  static double easeOut(double x) => 1 - math.pow(1 - x, 3).toDouble();
  static double fast(double x) => 1 - math.pow(1 - x, 5).toDouble();
  static double easeIn(double x) => x * x * x;
  static double back(double x) {
    const c1 = 1.70158;
    const c3 = c1 + 1;
    return 1 + c3 * math.pow(x - 1, 3) + c1 * math.pow(x - 1, 2);
  }

  static double arc(double p) => 4 * p * (1 - p);
  static double lerp(double a, double b, double x) => a + (b - a) * x;

  /// The same fixed pseudo random number for [i], 0 to 1.
  static double rnd(num i) {
    final x = math.sin(i * 127.1 + 311.7) * 43758.5453;
    return x - x.floorToDouble();
  }

  /// Seconds the break has slowed to, for the pieces: normal for 0.1 s,
  /// then 30 percent.
  static double slow(double t) {
    final q = (t - hit).clamp(0.0, double.infinity);
    return q < 0.1 ? q : 0.1 + (q - 0.1) * 0.3;
  }

  /// How far the cracks have spread, 0 to 1.
  static double crack(double t) => phase(t, 0.04, hit);

  /// How white the flash at the hit is, 1 to 0 over 0.12 s.
  static double hitFlash(double t) {
    final q = t - hit;
    return q < 0 || q >= 0.12 ? 0 : 1 - q / 0.12;
  }

  /// How white the flash at the cut is, 1 to 0 over 0.1 s.
  static double cutFlash(double t) {
    final q = t - cut;
    return q < 0 || q >= 0.1 ? 0 : 1 - q / 0.1;
  }

  /// Which scene is drawn under Crit at [t].
  static BreakLiftRingScene scene(double t) {
    if (t < hit) return BreakLiftRingScene.wall;
    if (t < cut) return BreakLiftRingScene.broken;
    if (t < sky) return BreakLiftRingScene.flight;
    if (t < cobalt) return BreakLiftRingScene.rings;
    if (t < uncover) return BreakLiftRingScene.cobalt;
    return BreakLiftRingScene.flood;
  }

  /// The share of the way through the flight, 0 to 1.
  static double flight(double t) => phase(t, cut, sky);

  /// How much of the flight's zoom is on, 1 to 1.06.
  static double zoom(double t) => 1 + 0.06 * math.sin(flight(t) * math.pi);

  /// How far the speed lines still show, 1 to 0.
  static double speedAlpha(double t) => 1 - phase(flight(t), 0.55, 0.94);

  /// How far the trail behind him is drawn, 1 to 0.
  static double trail(double t) => 1 - easeOut(phase(flight(t), 0.5, 0.96));

  /// The speed lines' lean, radians.
  static double flightLean(double t) {
    final turn = easeOut(phase(flight(t), 0.42, 1));
    return lerp(42, 0, turn) * math.pi / 180;
  }

  /// The share of the way through the rings part, in seconds from its zero.
  static double ringTime(double t) => t - ringsFrom;

  /// His size at [t] in reference units while the rings fire: a small dip,
  /// then a size up with each ring.
  static double ringSize(double t) {
    final tr = ringTime(t);
    return 200 -
        18 * arc(phase(tr, 0.24, 0.40)) +
        48 * back(phase(tr, 0.40, 0.54)) +
        46 * back(phase(tr, 0.66, 0.80)) +
        48 * back(phase(tr, 0.92, 1.06));
  }

  /// How far ring [i] is out at [t], 0 to 1, or null when it is not drawn.
  static double? ring(int i, double t) {
    final p = phase(t, rings[i], rings[i] + ringSeconds);
    return p > 0 && p < 1 ? p : null;
  }

  /// The two thin pulse rings behind the cobalt disc, 0 to 1, or null.
  static double? pulse(int i, double t) {
    final tr = ringTime(t);
    if (tr <= 1.42 || t >= uncover) return null;
    return ((tr - 1.42) / 0.9 + i * 0.5) % 1;
  }

  /// How far the cobalt disc has grown, 0 to 1.
  static double disc(double t) => fast(phase(ringTime(t), 1.3, 1.6));

  /// How far the clip that uncovers the end state has grown, 0 to 1.
  static double flood(double t) => fast(phase(t, uncover, uncover + 0.33));

  /// Which ring's word shows at [t]: 0 to 2, or -1 before the first.
  static int wordIndex(double t) {
    var index = -1;
    for (var i = 0; i < rings.length; i++) {
      if (t >= rings[i]) index = i;
    }
    return index;
  }

  /// How far in word [i] is, 0 to 1 (its pop, from 1.3 times down to 1).
  static double wordPop(int i, double t) =>
      fast(phase(t, rings[i], rings[i] + 0.14));

  /// The word's opacity, 0 to 1.
  static double wordFade(int i, double t) =>
      phase(t, rings[i], rings[i] + 0.05);

  /// His face at [t].
  static FaceState face(double t) {
    if (t < 0.98) return t < hit ? FaceState.determined : FaceState.happy;
    if (t < rings.first) return FaceState.determined;
    if (t < uncover) return FaceState.happy;
    return FaceState.surprised;
  }

  /// His pose at [t] on a screen of [size].
  ///
  /// [mascot] is where the layout's own Crit stood (null: he starts at the
  /// stage), [land] where the end state's Crit stands at [end]. At [end]
  /// and after, the box is exactly [land], upright and unsquashed.
  static BreakLiftRingPose pose(
    double t, {
    required Size size,
    required Rect land,
    Rect? mascot,
  }) {
    final sx = size.width / reference.width;
    final sy = size.height / reference.height;
    final k = math.min(sx, sy);
    Offset at(double x, double y) => Offset(x * sx, y * sy);

    if (t >= end) {
      return BreakLiftRingPose(
        centre: land.center,
        size: land.width,
        squashY: land.width == 0 ? 1 : land.height / land.width,
        face: FaceState.surprised,
      );
    }

    if (t < hit) {
      final start =
          mascot ??
          Rect.fromCenter(
            center: at(195, 350),
            width: 200 * k,
            height: 200 * k,
          );
      final sq = easeOut(phase(t, 0, 0.2));
      final go = easeIn(phase(t, 0.2, hit));
      final s = lerp(start.width * 1.05, 300 * k, go);
      final sh = 1 - 0.2 * sq * (1 - go);
      final to = at(195, 350);
      final c = Offset(
        lerp(start.center.dx, to.dx, go),
        lerp(start.center.dy, to.dy, go) + (1 - sh) * s * 0.5,
      );
      return BreakLiftRingPose(
        centre: c,
        size: s,
        squashX: 1 + 0.12 * sq * (1 - go),
        squashY: sh,
        face: FaceState.determined,
      );
    }

    if (t < cut) {
      final hang = phase(t, hit, 1.22);
      final s = lerp(300, 338, hang) * k;
      final y = lerp(350, 372, hang);
      final sq = easeOut(phase(t, 1, cut)) * 0.9;
      final sh = 1 - 0.2 * sq;
      final c = at(195, y) + Offset(0, (1 - sh) * s * 0.5);
      return BreakLiftRingPose(
        centre: c,
        size: s,
        squashX: 1 + 0.14 * sq,
        squashY: sh,
        angle: t > 0.98 ? 0 : math.sin(t * 9) * 2 * math.pi / 180,
        face: face(t),
      );
    }

    if (t < sky) {
      final p = flight(t);
      final e = easeOut(p);
      final turn = easeOut(phase(p, 0.42, 1));
      final z = zoom(t);
      final x = lerp(172, 195, e) + math.sin(p * math.pi) * 24;
      final y = lerp(640, 330, e);
      // The dip before the first ring starts here, so his size does not
      // jump where the rings part takes over.
      final dip = -18 * arc(phase(ringTime(t), 0.24, 0.40));
      final pivot = at(195, 422);
      final c = pivot + (at(x, y) - pivot) * z;
      return BreakLiftRingPose(
        centre: c,
        size: (lerp(216, 200, turn) + dip) * k * z,
        squashX: lerp(0.96, 1, turn),
        squashY: lerp(1.06, 1, turn),
        angle: flightLean(t),
        face: FaceState.determined,
      );
    }

    final tr = ringTime(t);
    final s = ringSize(t) * k;
    final c = at(195, 330);
    if (t < uncover) {
      // The rock starts and ends at zero, so he never jumps.
      final rock =
          phase(tr, 0.40, 0.50) *
          (1 - phase(tr, 1.1, 1.3)) *
          math.sin((tr - 0.4) * math.pi * 2 * 2.6) *
          3 *
          math.pi /
          180;
      return BreakLiftRingPose(
        centre: c,
        size: s,
        angle: rock,
        face: face(t),
      );
    }
    final m = fast(phase(t, uncover, end));
    final from = c;
    return BreakLiftRingPose(
      centre: Offset.lerp(from, land.center, m)!,
      size: lerp(s, land.width, m),
      squashY: lerp(1, land.width == 0 ? 1 : land.height / land.width, m),
      face: FaceState.surprised,
    );
  }

  /// The 56 pieces of the wall on a screen of [size]: a 4 by 7 grid with
  /// its inner points moved by a fixed amount, each cell cut in two one way
  /// or the other. The same on every run.
  static List<BreakPiece> pieces(Size size) {
    final sx = size.width / reference.width;
    final sy = size.height / reference.height;
    final k = math.min(sx, sy);
    Offset point(int i, int j) {
      final edge = i == 0 || i == cols || j == 0 || j == rowCount;
      final dx = edge ? 0.0 : (rnd(i * 13 + j * 7) - 0.5) * 60;
      final dy = edge ? 0.0 : (rnd(i * 5 + j * 11 + 3) - 0.5) * 70;
      return Offset(
        i / cols * reference.width * sx + dx * sx,
        j / rowCount * reference.height * sy + dy * sy,
      );
    }

    final origin = Offset(195 * sx, 330 * sy);
    final triangles = <List<Offset>>[];
    for (var j = 0; j < rowCount; j++) {
      for (var i = 0; i < cols; i++) {
        final a = point(i, j);
        final b = point(i + 1, j);
        final d = point(i, j + 1);
        final e = point(i + 1, j + 1);
        final flip = rnd(i * 3 + j * 17) > 0.5;
        triangles
          ..add(flip ? [a, b, d] : [a, b, e])
          ..add(flip ? [b, e, d] : [a, e, d]);
      }
    }
    return [
      for (var n = 0; n < triangles.length; n++)
        () {
          final p = triangles[n];
          final centre = (p[0] + p[1] + p[2]) / 3;
          final away = centre - origin;
          final length = away.distance == 0 ? 1.0 : away.distance;
          final dir = away / length;
          return BreakPiece(
            a: p[0],
            b: p[1],
            c: p[2],
            centre: centre,
            reach: length,
            velocity: Offset(
              dir.dx * (260 + rnd(n) * 520) * k,
              dir.dy * (260 + rnd(n + 1) * 520) * k - 120 * k,
            ),
            spin: (rnd(n + 2) - 0.5) * 7,
            depth: rnd(n + 3),
          );
        }(),
    ];
  }

  /// Where [piece] is at [t]: its offset from where it started, its turn
  /// in radians and its scale.
  static ({Offset shift, double turn, double scale}) flightOf(
    BreakPiece piece,
    double t, {
    required double k,
  }) {
    final s = slow(t);
    return (
      shift: Offset(
        piece.velocity.dx * s * 1.5,
        piece.velocity.dy * s * 1.5 + 900 * k * s * s,
      ),
      turn: piece.spin * s,
      scale: 1 + piece.depth * piece.depth * s * 2.4,
    );
  }

  /// The words, one a ring, from the line the outro writes. The line is
  /// upper cased and split on spaces. Past three words the rest join the
  /// third, and a line of fewer gives fewer.
  static List<String> words(String line) {
    final parts = line
        .trim()
        .toUpperCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (parts.length <= rings.length) return parts;
    return [
      ...parts.take(rings.length - 1),
      parts.skip(rings.length - 1).join(' '),
    ];
  }

  /// A haptic tap at the hit, the cut and each ring.
  static const List<PaywallThanksBeat> beats = [
    PaywallThanksBeat.tap(hit, HapticPattern.light),
    PaywallThanksBeat.tap(cut, HapticPattern.light),
    PaywallThanksBeat.tap(2.20, HapticPattern.light),
    PaywallThanksBeat.tap(2.46, HapticPattern.light),
    PaywallThanksBeat.tap(2.72, HapticPattern.light),
  ];
}

/// What is drawn under Crit.
enum BreakLiftRingScene { wall, broken, flight, rings, cobalt, flood }
