import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/thanks/thanks_parts.dart';
import 'package:flutter/widgets.dart';

// The limits lifted version, as numbers. The mascot comes to the stage
// small. Under it every limit of the free plan stands at its cap, a bar
// run up against a stop. One after another the stop breaks, the bar runs
// to the end and the number rolls up to the product's. The mascot grows a
// little with each, and a whole size at the end. Where a product has no
// counters, each row is a locked card that turns over to its open face.
//
// The times follow the purchase cue, which starts at zero: a click, a
// short pick up, one big swell that starts at 0.4 and peaks at 0.6, and a
// long tail that is over by 2.2. The first limit goes on the peak and the
// rest down the tail, felt and not heard. The mascot grows after the cue
// is over, so that moment has a sound of its own.

/// The show's timeline. Every value is a pure function of the seconds
/// since the purchase was confirmed.
abstract final class LimitsTimeline {
  /// The paywall under the show is covered.
  static const double cover = 0.34;

  /// The mascot stays where the layout had it until the cover has passed
  /// under it, so the layout's own is never seen beside it.
  static const double setOff = 0.14;

  /// The rows rise in, each at its cap, on the pick up.
  static const double rows = 0.1;

  /// The first limit is lifted, on the swell's peak.
  static const double firstLift = 0.6;

  /// How long one limit takes: the stop breaks, the bar runs, the number
  /// rolls.
  static const double liftSeconds = 0.5;

  /// The host's button is on.
  static const double goOn = 1.1;

  /// The mascot grows a size, after the purchase cue is over, and is
  /// back on the floor.
  static const double grow = 2.3;
  static const double grown = 2.72;

  /// The resting frame.
  static const double end = 3;

  /// How much of a bar the free plan's cap is. A picture, the same for
  /// every row: the numbers are in the words beside it.
  static const double capShare = 0.26;

  /// A lifted bar at rest against one at its cap: its height and how much
  /// ink it has.
  static const double restThick = 0.34;
  static const double restInk = 0.3;

  /// The mascot's size against its rest size: as it arrives, once every
  /// limit is lifted, and at rest.
  static const double small = 0.6;
  static const double middle = 0.78;

  /// The seconds between two limits with [count] rows: the last one is
  /// done before the mascot grows.
  static double liftEvery(int count) =>
      count <= 1 ? 0 : math.min(0.6, 1.2 / (count - 1));

  /// The second limit [index] of [count] is lifted.
  static double liftAt(int index, int count) =>
      firstLift + index * liftEvery(count);

  /// How far the cover has grown out of the button at [t], 0 to 1.
  static double covered(double t) =>
      Curves.easeOutCubic.transform(phase(t, 0, cover));

  /// How far the mascot is from where the layout had it to the stage at
  /// [t], 0 to 1.
  static double travel(double t) =>
      Curves.easeInOutCubic.transform(phase(t, setOff, 0.4));

  /// How far in row [index] is at [t], 0 to 1.
  static double rowIn(double t, int index) =>
      phase(stagger(index, t, each: 0.03, start: rows), 0, 0.22);

  /// How far limit [index] of [count] is lifted at [t], 0 to 1.
  static double lifted(double t, int index, int count) {
    final at = liftAt(index, count);
    return phase(t, at, at + liftSeconds);
  }

  /// How far the stop of bar [index] has broken away at [t], 0 to 1. At
  /// one it is gone.
  static double broken(double t, int index, int count) {
    final at = liftAt(index, count);
    return phase(t, at, at + 0.26);
  }

  /// How much of bar [index] is filled at [t]: [capShare] until its stop
  /// breaks, then on to one.
  static double filled(double t, int index, int count) {
    final at = liftAt(index, count);
    final run = Curves.easeOutCubic.transform(
      phase(t, at + 0.04, at + liftSeconds - 0.04),
    );
    return capShare + (1 - capShare) * run;
  }

  /// How far bar [index] has let go at [t], 0 to 1: once it has run to
  /// its end it thins and pales, so the lifted rows rest light.
  static double eased(double t, int index, int count) =>
      Curves.easeOut.transform(phase(lifted(t, index, count), 0.8, 1));

  /// The number row [index] shows at [t], rolling from [from] to [to].
  static int count(
    double t,
    int index,
    int count, {
    required int from,
    required int to,
  }) {
    final at = liftAt(index, count);
    final run = Curves.easeOutCubic.transform(
      phase(t, at, at + liftSeconds - 0.04),
    );
    return from + ((to - from) * run).round();
  }

  /// How far over card [index] has turned at [t], 0 to 1: its locked face
  /// up to a half, its open face after. At one it lies flat.
  static double turned(double t, int index, int count) =>
      Curves.easeInOut.transform(lifted(t, index, count));

  /// The angle card [index] is seen at, in radians. Zero at both ends:
  /// the open face comes round from the far side.
  static double turnAngle(double t, int index, int count) {
    final p = turned(t, index, count);
    return p < 0.5 ? math.pi * p : math.pi * (p - 1);
  }

  /// The mascot's size against its rest size at [t]: a step for each
  /// limit lifted, then the last and largest, with a small overshoot.
  static double size(double t, {required int count}) {
    var steps = 0.0;
    for (var i = 0; i < count; i++) {
      final at = liftAt(i, count);
      steps += AppCurves.easeBack.transform(phase(t, at + 0.1, at + 0.4));
    }
    final last = AppCurves.easeBack.transform(phase(t, grow, grow + 0.36));
    return small +
        (middle - small) * steps / math.max(1, count) +
        (1 - middle) * last;
  }

  /// How high the mascot is at [t], as a share of its own height: a hop
  /// for each limit, then the jump it grows in.
  static double lift(double t, {required int count}) {
    if (t >= grow) return 0.3 * thanksArc(phase(t, grow, grown));
    for (var i = 0; i < count; i++) {
      final at = liftAt(i, count) + 0.08;
      if (t >= at && t < at + 0.2) {
        return 0.07 * thanksArc(phase(t, at, at + 0.2));
      }
    }
    return 0;
  }

  /// The mascot's height against its rest height at [t]: down before it
  /// grows and as it lands, one everywhere else.
  static double stretch(double t) {
    if (t < grow - 0.14) return 1;
    if (t < grow) return 1 - 0.16 * phase(t, grow - 0.14, grow);
    if (t < grown) {
      return 0.84 + 0.16 * Curves.easeOut.transform(phase(t, grow, grow + 0.1));
    }
    final p = phase(t, grown, grown + 0.24);
    return 1 - 0.2 * math.sin(math.pi * p) * (1 - p);
  }

  /// The face at [t]: eyes on the rows, keener with each limit, winning
  /// as it grows, then glad, which is the idle of the resting frame.
  static ThanksFace face(double t, {required int count}) {
    final last = liftAt(math.max(0, count - 1), count);
    if (t < firstLift) {
      return (
        from: HeroFace.glad,
        to: HeroFace.watching,
        blend: phase(t, 0.12, 0.3),
      );
    }
    if (t < last + liftSeconds) {
      return (
        from: HeroFace.watching,
        to: HeroFace.keen,
        blend: phase(t, firstLift, firstLift + 0.2),
      );
    }
    if (t < grow) {
      return (
        from: HeroFace.keen,
        to: HeroFace.proud,
        blend: phase(t, last + liftSeconds, last + liftSeconds + 0.16),
      );
    }
    if (t < end - 0.2) {
      return (
        from: HeroFace.proud,
        to: HeroFace.winning,
        blend: phase(t, grow, grow + 0.12),
      );
    }
    if (t < end) {
      return (
        from: HeroFace.winning,
        to: HeroFace.glad,
        blend: phase(t, end - 0.2, end - 0.02),
      );
    }
    return thanksIdleFace(t - end);
  }

  /// How far in the disc behind the mascot and the headline are at [t], 0
  /// to 1. The disc is the size the mascot grows into. The headline lands
  /// on the swell's peak, with the first limit.
  static double disc(double t) =>
      AppCurves.easeBack.transform(phase(t, 0.36, 0.7));
  static double headlineIn(double t) => phase(t, firstLift, firstLift + 0.3);

  /// How far the one ring that leaves the disc as the mascot grows has
  /// gone at [t], 0 to 1. At one it is gone.
  static double ring(double t) => phase(t, grow + 0.06, grow + 0.6);
}

/// Where the limits version puts its parts on one phone: the mascot, the
/// headline under it and the rows under that, centred as one block in the
/// room above the button. The rows are tall and the mascot large, so a
/// tall phone is used.
@immutable
class LimitsPlan {
  const LimitsPlan({
    required this.crit,
    required this.headline,
    required this.rows,
    required this.headlineSize,
    required this.rowHeight,
    required this.rowGap,
    required this.unit,
  });

  factory LimitsPlan.of({
    required Size size,
    required EdgeInsets padding,
    required int count,
    required bool isCards,
    double textScale = 1,
  }) {
    final room = Rect.fromLTRB(
      0,
      padding.top,
      size.width,
      size.height - padding.bottom - paywallThanksButtonRoom,
    );
    final unit = (room.height / 687).clamp(0.78, 1.12);
    final headlineSize = size.height <= 667 ? 30.0 : 34.0;
    final headlineHeight = headlineSize * 1.15 * math.min(textScale, 1.3);
    final edge = math.min(size.width * 0.46, room.height * 0.27);
    final headroom = edge * 0.12;
    final gap = edge * 0.2;
    final rowsGap = 22 * unit;
    final rowGap = (isCards ? 12 : 16) * unit;
    final above = headroom + edge + gap + headlineHeight + rowsGap;
    final gaps = rowGap * math.max(0, count - 1);
    final most = (room.height - above - Spacing.s3 - gaps) / math.max(1, count);
    final rowHeight = math.min((isCards ? 96 : 54) * unit, most);
    final rowsHeight = rowHeight * count + gaps;
    final spare = room.height - above - rowsHeight;
    final top = room.top + headroom + math.max(0, spare) * 0.44;
    final crit = Rect.fromLTWH((size.width - edge) / 2, top, edge, edge);
    final headline = Rect.fromLTWH(
      thanksSideInset,
      crit.bottom + gap,
      size.width - 2 * thanksSideInset,
      headlineHeight + rowsGap,
    );
    final inset = isCards ? thanksSideInset : thanksSideInset + Spacing.s4;
    return LimitsPlan(
      crit: crit,
      headline: headline,
      rows: Rect.fromLTWH(
        inset,
        headline.bottom,
        size.width - 2 * inset,
        rowsHeight,
      ),
      headlineSize: headlineSize,
      rowHeight: rowHeight,
      rowGap: rowGap,
      unit: unit,
    );
  }

  /// A card shorter than this has no room for its second line.
  static const double noteFrom = 68;

  /// The mascot at rest, full size. Its foot is the floor it grows from.
  final Rect crit;

  /// The headline's box.
  final Rect headline;

  /// The rows, top down.
  final Rect rows;
  final double headlineSize;
  final double rowHeight;
  final double rowGap;
  final double unit;

  /// Whether a card has room for the line under its title.
  bool get hasNote => rowHeight >= noteFrom;

  /// The box of row [index].
  Rect row(int index) => Rect.fromLTWH(
    rows.left,
    rows.top + (rowHeight + rowGap) * index,
    rows.width,
    rowHeight,
  );

  /// The mascot's box at [share] of its rest size, on the same floor.
  Rect critAt(double share) => Rect.fromLTWH(
    crit.center.dx - crit.width * share / 2,
    crit.bottom - crit.height * share,
    crit.width * share,
    crit.height * share,
  );
}
