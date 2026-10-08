import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_product.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_atmosphere.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_lines.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_mascot.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

// The parts every version of the step after a purchase is drawn with, so a
// version's own file is only its idea. No part holds a timer: each draws
// the frame it is handed.

/// The side inset of the words and the button, the same as the buy
/// block's.
const double thanksSideInset = 20;

/// The headline of the resting frame: what the buyer has now.
String thanksHeadline(PaywallProduct product) => switch (product) {
  PaywallProduct.hosted => LocaleKeys.paywall_thanks_headline_hosted.tr(),
  PaywallProduct.pro => LocaleKeys.paywall_thanks_headline_pro.tr(),
};

/// The lines under it, one for each benefit this build has.
List<String> thanksLines(PaywallThanksScope scope) => [
  for (final benefit in scope.benefits) heroLineFor(benefit),
];

/// Where a version stands its mascot and writes its words, on one phone.
///
/// The mascot's box and the words under it are centred as one block in the
/// room above the button, a little above the middle, with air over the
/// mascot's head for a jump and for what it wears.
@immutable
class ThanksStage {
  const ThanksStage({
    required this.crit,
    required this.words,
    required this.headlineSize,
    required this.lineSize,
    required this.rowGap,
  });

  factory ThanksStage.of({
    required Size size,
    required EdgeInsets padding,
    required int lines,
    double textScale = 1,
  }) {
    final room = Rect.fromLTRB(
      0,
      padding.top,
      size.width,
      size.height - padding.bottom - paywallThanksButtonRoom,
    );
    final isCompact = size.height <= 667;
    final headlineSize = isCompact ? 30.0 : 34.0;
    final lineSize = isCompact ? 16.0 : 17.0;
    final rowGap = isCompact ? 8.0 : 10.0;
    final row = math.max(markSize, lineSize * 1.3 * textScale) + rowGap;
    final wordsHeight =
        headlineSize * 1.15 * textScale + headlineGap + lines * row;
    final edge = math.min(size.width * 0.5, room.height * 0.3);
    final gap = edge * 0.3;
    final headroom = edge * 0.24;
    final spare = room.height - headroom - edge - gap - wordsHeight;
    final top = room.top + headroom + math.max(0, spare) * 0.45;
    final crit = Rect.fromLTWH((size.width - edge) / 2, top, edge, edge);
    return ThanksStage(
      crit: crit,
      words: Rect.fromLTRB(
        thanksSideInset,
        crit.bottom + gap,
        size.width - thanksSideInset,
        room.bottom,
      ),
      headlineSize: headlineSize,
      lineSize: lineSize,
      rowGap: rowGap,
    );
  }

  /// The edge of the small mark that leads each line.
  static const double markSize = 22;

  /// The gap between the headline and the first line.
  static const double headlineGap = Spacing.s4;

  /// The mascot at rest. Its foot is the floor everything lands on.
  final Rect crit;

  /// The headline and the lines, top down.
  final Rect words;
  final double headlineSize;
  final double lineSize;
  final double rowGap;

  double get floor => crit.bottom;
}

/// One face on the way to another.
typedef ThanksFace = ({HeroFace from, HeroFace to, double blend});

/// The face the mascot wears [since] seconds into its rest: [rest], and
/// every few seconds [now] for a moment, so it does not hold one face.
ThanksFace thanksIdleFace(
  double since, {
  HeroFace rest = HeroFace.glad,
  HeroFace now = HeroFace.winking,
}) {
  const every = 5.6;
  const from = 3.6;
  const until = 4.6;
  if (since <= 0) return (from: rest, to: rest, blend: 1);
  final local = loopT(since, every);
  if (local < from) return (from: now, to: rest, blend: 1);
  if (local < until) {
    return (from: rest, to: now, blend: phase(local, from, from + 0.2));
  }
  return (from: now, to: rest, blend: phase(local, until, until + 0.24));
}

/// Where a version's mascot starts: over the layout's own, [mascot], and
/// a little larger, so the one under it does not show at its edge in the
/// moment before the cover reaches it. Null with no mascot to start from.
Rect? thanksStartBox(Rect? mascot) => mascot?.inflate(mascot.width * 0.04);

/// Up and back down across a window, 0 at both ends and 1 in the middle.
double thanksArc(double p) => 4 * p * (1 - p);

/// The tone's colour growing as a disc from [centre] until it covers the
/// box. A version puts it first in its stack, so the paywall under it is
/// covered from the button outward and never cut to.
class ThanksCover extends StatelessWidget {
  const ThanksCover({
    required this.color,
    required this.centre,
    required this.grown,
    super.key,
  });

  final Color color;
  final Offset centre;

  /// 0 to 1. One covers every corner.
  final double grown;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: CustomPaint(painter: _CoverPainter(color, centre, grown)),
  );
}

class _CoverPainter extends CustomPainter {
  const _CoverPainter(this.color, this.centre, this.grown);

  final Color color;
  final Offset centre;
  final double grown;

  @override
  void paint(Canvas canvas, Size size) {
    if (grown <= 0) return;
    final paint = Paint()..color = color;
    if (grown >= 1) return canvas.drawRect(Offset.zero & size, paint);
    final reach = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((corner) => (corner - centre).distance).reduce(math.max);
    canvas.drawCircle(centre, reach * grown, paint);
  }

  @override
  bool shouldRepaint(_CoverPainter old) =>
      grown != old.grown || color != old.color || centre != old.centre;
}

/// The soft disc the mascot stands in front of, [grown] of its size.
class ThanksDisc extends StatelessWidget {
  const ThanksDisc({
    required this.stage,
    required this.tone,
    this.grown = 1,
    super.key,
  });

  final ThanksStage stage;
  final PaywallTone tone;
  final double grown;

  @override
  Widget build(BuildContext context) {
    final radius = stage.crit.width * 0.76 * grown;
    if (radius <= 0) return const SizedBox.shrink();
    return Positioned.fromRect(
      rect: Rect.fromCircle(center: stage.crit.center, radius: radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: HeroAtmosphereColors.of(context, tone).disc,
        ),
      ),
    );
  }
}

/// The mascot, in [box], with the moves a version gives it. A direct child
/// of the version's `Stack`.
///
/// Every move ends at rest: [lift] at zero, [stretch] at one, [angle] at
/// zero. It casts a small shadow on the floor under [box], which shrinks
/// as it leaves the ground.
class ThanksCrit extends StatelessWidget {
  const ThanksCrit({
    required this.box,
    required this.face,
    this.lift = 0,
    this.stretch = 1,
    this.angle = 0,
    this.blink = 0,
    this.bob = 0,
    this.props = const {},
    this.shadow = 1,
    super.key,
  });

  final Rect box;
  final ThanksFace face;

  /// How high off the floor it is, as a share of its own height.
  final double lift;

  /// Its height against its rest height. Its width gives what its height
  /// takes, so a squash looks soft. One at rest.
  final double stretch;
  final double angle;
  final double blink;

  /// The seconds its idle bob reads. Zero holds it level.
  final double bob;
  final Map<HeroProp, double> props;

  /// How much of the shadow shows, 0 to 1.
  final double shadow;

  @override
  Widget build(BuildContext context) {
    final edge = box.width;
    final ink = context.appColors.inkFixed;
    final near = 1 - (lift * 1.4).clamp(0.0, 0.7);
    return Positioned.fromRect(
      rect: box,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: edge * (0.5 - 0.32 * near),
            width: edge * 0.64 * near,
            top: edge * 0.97,
            height: edge * 0.07,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: ink.withValues(alpha: 0.12 * shadow * near),
                borderRadius: BorderRadius.all(Radius.elliptical(edge, edge)),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(0, -lift * edge),
            child: Transform.rotate(
              angle: angle,
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.diagonal3Values(
                  1 + (1 - stretch) * 0.6,
                  stretch,
                  1,
                ),
                child: HeroMascot(
                  size: edge,
                  face: face.to,
                  fromFace: face.from,
                  faceBlend: face.blend.clamp(0, 1).toDouble(),
                  blink: blink,
                  bob: bob,
                  props: props,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The small round mark that leads a line once it is checked: [on] of the
/// way there, from an empty ring.
class ThanksCheck extends StatelessWidget {
  const ThanksCheck({required this.on, required this.tone, super.key});

  final double on;
  final PaywallTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final ink = PaywallToneColors.of(context, tone).ink;
    const size = ThanksStage.markSize;
    final pop = AppCurves.easeBack.transform(on.clamp(0, 1).toDouble());
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (on < 1)
            Container(
              width: size - 4,
              height: size - 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: ink.withValues(alpha: 0.28),
                  width: 2,
                ),
              ),
            ),
          if (on > 0)
            Transform.scale(
              scale: pop,
              child: Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.highlight,
                ),
                child: AppGlyph(
                  GlyphType.check,
                  size: size * 0.56,
                  color: colors.onHighlight,
                  strokeWidth: 3.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The headline and the lines of the resting frame, in the stage's words
/// box. A direct child of the version's `Stack`.
///
/// The caller says, for this frame, how far in the headline and each line
/// are and how strong each line reads, and draws each line's mark. At rest
/// all of it is one: there.
class ThanksWords extends StatelessWidget {
  const ThanksWords({
    required this.stage,
    required this.tone,
    required this.headline,
    required this.lines,
    required this.mark,
    this.headlineIn = 1,
    this.lineIn = _whole,
    this.lineStrong = _whole,
    super.key,
  });

  static double _whole(int index) => 1;

  final ThanksStage stage;
  final PaywallTone tone;
  final String headline;
  final List<String> lines;

  /// The mark that leads line `index`, [ThanksStage.markSize] square.
  final Widget Function(int index) mark;

  /// 0 to 1: the headline pops in.
  final double headlineIn;

  /// 0 to 1 for each line: it rises in.
  final double Function(int index) lineIn;

  /// 0 to 1 for each line: from a quiet promise to something held.
  final double Function(int index) lineStrong;

  @override
  Widget build(BuildContext context) {
    final colors = PaywallToneColors.of(context, tone);
    final said = AppCurves.easeBack.transform(headlineIn.clamp(0, 1));

    return Positioned.fromRect(
      rect: stage.words,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: stage.words.width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: (headlineIn * 2.5).clamp(0, 1).toDouble(),
                child: Transform.scale(
                  scale: 0.86 + 0.14 * said,
                  child: Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      headline,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: AppTypography.display(
                        colors.ink,
                        fontSize: stage.headlineSize,
                      ).copyWith(height: 1.15),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: ThanksStage.headlineGap),
              // One block in the middle with one left edge of its own.
              IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (index, line) in lines.indexed)
                      _line(index, line, colors),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(int index, String line, PaywallToneColors colors) {
    final entered = lineIn(index).clamp(0, 1).toDouble();
    final strong = lineStrong(index).clamp(0, 1).toDouble();
    final rise = AppCurves.easeOut.transform(entered);
    return Padding(
      padding: EdgeInsets.only(bottom: stage.rowGap),
      child: Opacity(
        opacity: entered,
        child: Transform.translate(
          offset: Offset(0, (1 - rise) * Spacing.s3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              mark(index),
              const SizedBox(width: Spacing.s3),
              Flexible(
                child: Text(
                  line,
                  style: AppTypography.small(
                    Color.lerp(colors.muted, colors.ink, strong)!,
                    fontSize: stage.lineSize,
                  ).copyWith(fontWeight: FontWeight.w600, height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The quiet frame a restore that worked gets: the mascot, a check, and
/// one line. No show. The host fades it in and puts the button under it.
class ThanksQuiet extends StatelessWidget {
  const ThanksQuiet({required this.scope, required this.tone, super.key});

  final PaywallThanksScope scope;
  final PaywallTone tone;

  /// The mascot nods once as the frame comes in.
  static const double nod = 0.18;
  static const double nodEnd = 0.52;

  @override
  Widget build(BuildContext context) {
    final colors = PaywallToneColors.of(context, tone);
    final stage = ThanksStage.of(
      size: scope.size,
      padding: scope.padding,
      lines: 0,
      textScale: MediaQuery.textScalerOf(context).scale(1),
    );
    final line = switch (scope.product) {
      PaywallProduct.hosted => LocaleKeys.paywall_thanks_restored_hosted.tr(),
      PaywallProduct.pro => LocaleKeys.paywall_thanks_restored_pro.tr(),
    };
    final badge = stage.crit.width * 0.3;

    return ColoredBox(
      color: colors.background,
      child: PaywallClockBuilder(
        clock: scope.clock,
        builder: (context, t, _) {
          final rest = t - paywallThanksQuietSeconds;
          return Stack(
            children: [
              ThanksDisc(stage: stage, tone: tone),
              ThanksCrit(
                box: stage.crit,
                face: thanksIdleFace(rest, now: HeroFace.relieved),
                lift: 0.08 * thanksArc(phase(t, nod, nodEnd)),
                blink: rest > 0 ? heroBlinkAt(rest) : 0,
                bob: math.max(0, rest),
              ),
              Positioned(
                left: stage.crit.right - badge * 0.8,
                top: stage.crit.bottom - badge * 0.9,
                child: Transform.scale(
                  scale: badge / ThanksStage.markSize,
                  alignment: Alignment.topLeft,
                  child: ThanksCheck(on: phase(t, nod, nodEnd), tone: tone),
                ),
              ),
              ThanksWords(
                stage: stage,
                tone: tone,
                headline: line,
                lines: const [],
                mark: (_) => const SizedBox.shrink(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One piece of confetti at one moment.
typedef ThanksConfettiPiece = ({
  Offset at,
  double angle,
  double alpha,
  int shape,
  int ink,
});

/// Confetti thrown from one point, as numbers. Every value is a pure
/// function of the seconds since the burst.
abstract final class ThanksConfetti {
  /// How many pieces fly.
  static const int pieces = 42;

  /// How deep the strip of floor the pieces come to lie on is, in points.
  static const double floorDepth = 18;

  /// The seconds a piece flies up and out before it starts down.
  static const double _turn = 0.46;

  /// What pulls a piece down, in points a second a second.
  static const double _pull = 70;

  /// A number from 0 up to 1 that is always the same for one piece and one
  /// `salt`.
  static double _roll(int index, int salt) {
    final x = math.sin(index * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  /// Whether piece [index] ends lying on the floor. The others fade on
  /// the way down, so the floor is strewn, not buried.
  static bool settles(int index) => index % 5 < 2;

  /// The top of the room the pieces fly in, over a floor at [floor].
  static double _top(Size size, double floor) =>
      math.max(0, floor - size.width * 0.9).toDouble();

  /// How long piece [index] falls from its high point to where it lies.
  static double _fall(int index, {required Size size, required double floor}) {
    final top = _top(size, floor);
    final high = top + (floor - top) * 0.62 * _roll(index, 3);
    final speed = 150 + 190 * _roll(index, 4);
    // Each lies at its own depth, so they read as on a floor, not a line.
    final room = floor - high + floorDepth * _roll(index, 8);
    // Solved for the moment it reaches the floor.
    return (-speed + math.sqrt(speed * speed + 4 * _pull * room)) / (2 * _pull);
  }

  /// The seconds after the burst by which the last piece lies still, over
  /// a screen [size] with the floor at [floor].
  static double settledBy({required Size size, required double floor}) {
    var last = 0.0;
    for (var i = 0; i < pieces; i++) {
      if (!settles(i)) continue;
      last = math.max(
        last,
        _roll(i, 1) * 0.07 + _turn + _fall(i, size: size, floor: floor),
      );
    }
    return last;
  }

  /// Piece [index], [t] seconds after the burst, thrown from [origin] over
  /// a screen [size] with the floor at [floor] points down. Null while it
  /// is not thrown yet and once it has faded.
  ///
  /// A piece flies up and out to its own high point, then flutters down.
  /// One that settles lands on the floor and lies flat. At rest every
  /// piece left is flat on the floor.
  static ThanksConfettiPiece? piece(
    int index,
    double t, {
    required Offset origin,
    required Size size,
    required double floor,
  }) {
    final since = t - _roll(index, 1) * 0.07;
    if (since <= 0) return null;
    final top = _top(size, floor);
    final high = Offset(
      size.width * (0.05 + 0.9 * _roll(index, 2)),
      top + (floor - top) * 0.62 * _roll(index, 3),
    );
    final up = Curves.easeOutCubic.transform(phase(since, 0, _turn + 0.1));
    final falling = math.max(0, since - _turn).toDouble();
    final speed = 150 + 190 * _roll(index, 4);
    final landsAfter = _fall(index, size: size, floor: floor);
    final fallen = math.min(falling, landsAfter);
    final drop = speed * fallen + _pull * fallen * fallen;
    final sway =
        math.sin(fallen * (3 + 2 * _roll(index, 5)) + _roll(index, 6) * 6.28) *
        12 *
        (1 - phase(falling, landsAfter - 0.2, landsAfter));
    final at = Offset.lerp(origin, high, up)! + Offset(sway, drop);
    final spin = (_roll(index, 7) * 2 - 1) * 9;
    final spun = spin * math.min(since, _turn + landsAfter);
    // It lies flat: the nearest half turn.
    final flat = (spun / math.pi).roundToDouble() * math.pi;
    final lies = phase(falling, landsAfter - 0.16, landsAfter);
    final angle = spun + (flat - spun) * lies;
    final alpha = settles(index)
        ? 1.0
        : 1 - phase(falling, landsAfter * 0.45, landsAfter * 0.95);
    if (alpha <= 0) return null;
    return (
      at: at,
      angle: lies >= 1 ? 0 : angle,
      alpha: alpha,
      shape: index % 3,
      ink: index % 4,
    );
  }
}

/// Every piece of confetti, [t] seconds after the burst.
class ThanksConfettiPainter extends CustomPainter {
  const ThanksConfettiPainter({
    required this.t,
    required this.origin,
    required this.floor,
    required this.inks,
  });

  final double t;
  final Offset origin;
  final double floor;
  final List<Color> inks;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < ThanksConfetti.pieces; i++) {
      final piece = ThanksConfetti.piece(
        i,
        t,
        origin: origin,
        size: size,
        floor: floor,
      );
      if (piece == null) continue;
      final paint = Paint()
        ..color = inks[piece.ink % inks.length].withValues(alpha: piece.alpha);
      canvas
        ..save()
        ..translate(piece.at.dx, piece.at.dy)
        ..rotate(piece.angle);
      switch (piece.shape) {
        case 0:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: 10, height: 5),
              const Radius.circular(1.5),
            ),
            paint,
          );
        case 1:
          canvas.drawCircle(Offset.zero, 3, paint);
        default:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: 14, height: 3.5),
              const Radius.circular(1.75),
            ),
            paint,
          );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ThanksConfettiPainter old) =>
      t != old.t || origin != old.origin || floor != old.floor;
}

/// Where a version that prints a slip puts its parts on one phone: the
/// mascot, the slip it holds by the top edge, and the headline under the
/// slip. The three are centred as one block in the room above the button,
/// and grow with the room so a tall phone is used.
@immutable
class ThanksSlipPlan {
  const ThanksSlipPlan({
    required this.crit,
    required this.paper,
    required this.headline,
    required this.headlineSize,
    required this.unit,
    required this.lines,
    required this.floor,
  });

  /// [foot] is room kept clear under the headline, above the button.
  factory ThanksSlipPlan.of({
    required Size size,
    required EdgeInsets padding,
    required int lines,
    double textScale = 1,
    double foot = 0,
  }) {
    final room = Rect.fromLTRB(
      0,
      padding.top,
      size.width,
      size.height - padding.bottom - paywallThanksButtonRoom - foot,
    );
    final unit = (room.height / 687).clamp(0.78, 1.12);
    final headlineSize = size.height <= 667 ? 30.0 : 34.0;
    final headlineHeight = headlineSize * 1.15 * math.min(textScale, 1.3);
    final edge = math.min(size.width * 0.46, room.height * 0.26);
    final paperWidth = math.min(size.width - 2 * 32, 330 * unit);
    final paperHeight = paperHeightFor(lines, unit);
    final overlap = edge * holdShare;
    final gap = 20 * unit;
    final headroom = edge * 0.14;
    final block = edge - overlap + paperHeight + gap + headlineHeight;
    final spare = room.height - headroom - block;
    final top = room.top + headroom + math.max(0, spare) * 0.44;
    final crit = Rect.fromLTWH((size.width - edge) / 2, top, edge, edge);
    final paper = Rect.fromLTWH(
      (size.width - paperWidth) / 2,
      crit.bottom - overlap,
      paperWidth,
      paperHeight,
    );
    return ThanksSlipPlan(
      crit: crit,
      paper: paper,
      headline: Rect.fromLTRB(
        thanksSideInset,
        paper.bottom + gap,
        size.width - thanksSideInset,
        room.bottom,
      ),
      headlineSize: headlineSize,
      unit: unit,
      lines: lines,
      floor: room.bottom,
    );
  }

  /// How much of the mascot's height the slip's top edge covers: it is
  /// held in front.
  static const double holdShare = 0.16;

  /// The parts of the slip top down, in points at a unit of one.
  static const double lead = 18;
  static const double header = 22;
  static const double rule = 16;
  static const double row = 38;
  static const double stampRoom = 84;
  static const double tear = 12;
  static const double pad = 20;

  /// The height of a slip with [lines] lines at [unit].
  static double paperHeightFor(int lines, double unit) =>
      (lead + header + rule + row * lines + rule + stampRoom + tear) * unit;

  /// The mascot at rest.
  final Rect crit;

  /// The slip at rest.
  final Rect paper;

  /// The headline's box, under the slip.
  final Rect headline;
  final double headlineSize;

  /// What every measure of the slip is multiplied by on this phone.
  final double unit;
  final int lines;

  /// The foot of the headline's box. With a foot kept clear, the top of
  /// it.
  final double floor;

  double get rowsTop => (lead + header + rule) * unit;
  double get rowHeight => row * unit;
  double get stampTop => rowsTop + rowHeight * lines + rule * unit;

  /// The middle of the stamp, on the slip at rest.
  Offset get stampCentre => Offset(
    paper.center.dx,
    paper.top + stampTop + (stampRoom - 8) * unit / 2,
  );

  /// The slip's box [fed] of the way from a slot at [slotTop] to the
  /// mascot.
  Rect paperAt(double fed, double slotTop) {
    final top = slotTop + (paper.top - slotTop) * fed;
    return Rect.fromLTWH(paper.left, top, paper.width, paper.height);
  }
}

/// Keeps what is above a line [y] points down the box.
class ThanksAboveClipper extends CustomClipper<Rect> {
  const ThanksAboveClipper(this.y);

  final double y;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width, math.max(0, y));

  @override
  bool shouldReclip(ThanksAboveClipper old) => y != old.y;
}

/// The mascot's two hands on the top edge of a slip at [paper]. Direct
/// children of the version's `Stack`.
List<Widget> thanksHands(
  BuildContext context, {
  required Rect paper,
  required double edge,
}) {
  final colors = context.appColors;
  final mitt = edge * 0.085;
  return [
    for (final side in const [-1.0, 1.0])
      Positioned.fromRect(
        rect: Rect.fromCircle(
          center: Offset(
            paper.center.dx + side * edge * 0.3,
            paper.top + mitt * 0.2,
          ),
          radius: mitt,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.faceFill,
            border: Border.all(color: colors.faceStroke, width: edge * 0.034),
          ),
        ),
      ),
  ];
}

/// The rubber stamp: [text] in a double frame.
class ThanksStampMark extends StatelessWidget {
  const ThanksStampMark({
    required this.text,
    required this.color,
    required this.unit,
    super.key,
  });

  final String text;
  final Color color;
  final double unit;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(2.5 * unit),
    decoration: BoxDecoration(
      border: Border.all(color: color, width: 3 * unit),
      borderRadius: BorderRadius.circular(Radii.xs + 4),
    ),
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 16 * unit, vertical: 5 * unit),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.2 * unit),
        borderRadius: BorderRadius.circular(Radii.xs + 1),
      ),
      child: Text(
        text.toUpperCase(),
        maxLines: 1,
        style: AppTypography.monoBold(
          color,
          fontSize: 27 * unit,
        ).copyWith(letterSpacing: 4, height: 1.2),
      ),
    ),
  );
}

/// The paper of a slip, with a torn edge along its foot, on its shadow.
class ThanksPaperPainter extends CustomPainter {
  const ThanksPaperPainter({
    required this.color,
    required this.tooth,
    required this.shadows,
  });

  final Color color;
  final double tooth;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final teeth = (size.width / 9).round();
    final step = size.width / teeth;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - tooth);
    for (var i = teeth - 1; i >= 0; i--) {
      path
        ..lineTo(step * (i + 0.5), size.height)
        ..lineTo(step * i, size.height - tooth);
    }
    path.close();
    for (final shadow in shadows) {
      canvas.drawPath(path.shift(shadow.offset), shadow.toPaint());
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(ThanksPaperPainter old) =>
      color != old.color || tooth != old.tooth || shadows != old.shadows;
}

/// A dashed rule across the middle of the box.
class ThanksDashPainter extends CustomPainter {
  const ThanksDashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + 4, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ThanksDashPainter old) => color != old.color;
}

/// [count] written as the plan numbers are: a comma between thousands.
String limitsCountText(int count) {
  final digits = '$count';
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// What a row's value reads while its number is [count], on the way from
/// the free plan's to the product's.
///
/// [now] is the product's value as the app writes it and [to] the number
/// in it. The words around the number stay and only the number changes.
/// Null when [now] does not hold the number, which is a row that has no
/// count to roll.
String? limitsRolling(String now, {required int to, required int count}) {
  final written = limitsCountText(to);
  if (!now.contains(written)) return null;
  return now.replaceFirst(written, limitsCountText(count));
}

/// One limit as a row shows it. Every word and number is the app's own:
/// the compare table's label and cells for the benefit, and the plan
/// numbers they are written from.
@immutable
class LimitsRow {
  const LimitsRow({
    required this.label,
    required this.free,
    required this.now,
    this.freeCount,
    this.nowCount,
  });

  final String label;

  /// What the free plan stops at, and what the product gives.
  final String free;
  final String now;

  /// The two as numbers, where the limit is one on both plans.
  final int? freeCount;
  final int? nowCount;

  /// Whether the value has a number to roll from one plan's to the
  /// other's.
  bool get rolls => freeCount != null && nowCount != null;

  /// What the value reads [run] of the way through its lift, at [count].
  /// A row with both numbers rolls from one to the other. Any other row
  /// reads the free value and then the product's.
  String valueAt(double run, int count) {
    if (run <= 0) return free;
    final to = nowCount;
    if (run >= 1 || to == null || freeCount == null) return now;
    return limitsRolling(now, to: to, count: count) ?? now;
  }
}

/// The Hosted benefit behind [benefit], where the plan numbers are kept,
/// or null for a benefit that is not a Hosted limit.
HostedBenefit? limitsHostedFor(PaywallBenefit benefit) {
  final id = switch (benefit.id) {
    PaywallBenefitId.topics => HostedBenefitId.topics,
    PaywallBenefitId.pushes => HostedBenefitId.pushes,
    PaywallBenefitId.history => HostedBenefitId.history,
    PaywallBenefitId.appIcons => HostedBenefitId.appIcons,
    _ => null,
  };
  for (final hosted in HostedBenefit.all) {
    if (hosted.id == id) return hosted;
  }
  return null;
}

/// The rows for [benefits], or null when one of them has no limit to
/// show. Then a version draws something else for each.
List<LimitsRow>? limitsRowsFor(List<PaywallBenefit> benefits) {
  final rows = <LimitsRow>[];
  for (final benefit in benefits) {
    final hosted = limitsHostedFor(benefit);
    if (hosted == null) return null;
    rows.add(
      LimitsRow(
        label: hosted.compareLabelKey.tr(namedArgs: HostedBenefit.args),
        free: hosted.compareFreeKey.tr(namedArgs: HostedBenefit.args),
        now: hosted.compareHostedKey.tr(namedArgs: HostedBenefit.args),
        freeCount: hosted.freeValue,
        nowCount: hosted.hostedValue,
      ),
    );
  }
  return rows.isEmpty ? null : rows;
}
