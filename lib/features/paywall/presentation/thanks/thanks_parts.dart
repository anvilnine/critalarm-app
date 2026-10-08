import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
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
