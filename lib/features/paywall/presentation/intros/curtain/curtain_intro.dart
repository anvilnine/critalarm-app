import 'dart:math' as math;

import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/presentation/intros/curtain/curtain_timeline.dart';
import 'package:critalarm/features/paywall/presentation/intros/intro_parts.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_cue_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The curtain call: a closed curtain, the mascot peeking out between its
/// halves, a look left, a look right, and then it sees you and throws the
/// curtain open on the layout.
///
/// Its score is a hush with a note for each look, stops dead as the mascot
/// sees you and arrives from the reveal.
const PaywallIntro curtainIntro = PaywallIntro(
  seconds: CurtainTimeline.end,
  handover: CurtainTimeline.handover,
  skipTo: CurtainTimeline.reveal,
  tone: PaywallTone.cobalt,
  cue: PaywallEntranceCue.none,
  score: PaywallCue.scoreCurtain,
  beats: [
    // The mascot sees you.
    PaywallIntroBeat.tap(CurtainTimeline.spot, HapticPattern.light),
    // The curtain is thrown open.
    PaywallIntroBeat.tap(CurtainTimeline.reveal, HapticPattern.light),
  ],
  skipCue: PaywallCue.introArrive,
  quietAfter:
      CurtainTimeline.reveal +
      paywallIntroArrivalSeconds -
      CurtainTimeline.handover,
  tag: _tag,
  builder: _build,
);

String _tag() => LocaleKeys.paywall_intro_curtain_tag.tr();

Widget _build(BuildContext context, PaywallIntroScope scope) =>
    CurtainIntro(scope: scope);

/// Draws the curtain call for the second its scope's clock reads. Between
/// the halves it draws nothing but the mascot.
class CurtainIntro extends StatelessWidget {
  const CurtainIntro({required this.scope, super.key});

  final PaywallIntroScope scope;

  @override
  Widget build(BuildContext context) {
    final tone = PaywallToneColors.of(context, PaywallTone.cobalt);
    final colors = context.appColors;
    final size = scope.size;
    final stage = introStageFor(size, scope.padding.top);
    final line = LocaleKeys.paywall_intro_curtain_line.tr();

    return PaywallClockBuilder(
      clock: scope.clock,
      builder: (context, t, _) {
        if (CurtainTimeline.isOver(t)) return const SizedBox.shrink();
        final gap = size.width * CurtainTimeline.gap(t);
        final isBehind = CurtainTimeline.isBehind(t);
        final backstage = CurtainTimeline.backstage(t);
        final poke = AppCurves.easeBack.transform(CurtainTimeline.pokeOut(t));
        final said = AppCurves.easeBack.transform(CurtainTimeline.line(t));
        final crit = IntroCrit(
          box: stage.face,
          scope: scope,
          shape: introFaceShape(CurtainTimeline.face(t)),
          leave: CurtainTimeline.leave(t),
          scale: isBehind ? 0.9 : 0.9 + 0.1 * poke,
        );
        final curtain = Positioned.fill(
          child: CustomPaint(
            painter: _CurtainPainter(
              gap: gap,
              sway: CurtainTimeline.rustle(t) * 3,
              cloth: tone.background,
              fold: colors.inkFixed.withValues(alpha: 0.16),
              shine: tone.ink.withValues(alpha: 0.1),
            ),
          ),
        );

        return Stack(
          children: [
            // The dark of the stage behind the curtain, until it opens.
            // Behind the curtain the mascot is seen only through the gap.
            if (backstage > 0 && gap > 0)
              Positioned(
                left: (size.width - gap) / 2,
                width: gap,
                top: 0,
                bottom: 0,
                child: ColoredBox(
                  color: colors.inkFixed.withValues(alpha: backstage),
                ),
              ),
            if (isBehind)
              Positioned.fill(
                child: ClipRect(
                  clipper: _GapClipper(gap),
                  child: Stack(children: [crit]),
                ),
              ),
            curtain,
            if (!isBehind) crit,
            IntroWord(
              text: line,
              box: stage.word,
              style: AppTypography.display(tone.ink, fontSize: stage.wordSize),
              opacity: said * CurtainTimeline.words(t),
              scale: 0.8 + 0.2 * said,
            ),
          ],
        );
      },
    );
  }
}

/// Lets through only what stands in the gap between the halves.
class _GapClipper extends CustomClipper<Rect> {
  const _GapClipper(this.gap);

  final double gap;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH((size.width - gap) / 2, 0, gap, size.height);

  @override
  bool shouldReclip(_GapClipper old) => gap != old.gap;
}

/// The two halves of the curtain, each from its side of the screen to its
/// edge of the gap, with folds that bunch up as a half is drawn back.
class _CurtainPainter extends CustomPainter {
  const _CurtainPainter({
    required this.gap,
    required this.sway,
    required this.cloth,
    required this.fold,
    required this.shine,
  });

  final double gap;
  final double sway;
  final Color cloth;
  final Color fold;
  final Color shine;

  static const int _folds = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final half = math.max(0, (size.width - gap) / 2).toDouble();
    if (half <= 0) return;
    final clothPaint = Paint()..color = cloth;
    final foldPaint = Paint()..color = fold;
    final shinePaint = Paint()..color = shine;

    for (final isLeft in [true, false]) {
      // The hanging edge sways a little at the foot before the peek.
      final edge = isLeft ? half : size.width - half;
      final foot = edge + (isLeft ? sway : -sway);
      final side = isLeft ? 0.0 : size.width;
      canvas.drawPath(
        Path()
          ..moveTo(side, 0)
          ..lineTo(edge, 0)
          ..lineTo(foot, size.height)
          ..lineTo(side, size.height)
          ..close(),
        clothPaint,
      );
      final width = half / _folds;
      for (var i = 0; i < _folds; i++) {
        final x = isLeft ? width * i : size.width - width * (i + 1);
        canvas
          ..drawRect(
            Rect.fromLTWH(x + width * 0.62, 0, width * 0.38, size.height),
            foldPaint,
          )
          ..drawRect(
            Rect.fromLTWH(x + width * 0.14, 0, width * 0.12, size.height),
            shinePaint,
          );
      }
    }
  }

  @override
  bool shouldRepaint(_CurtainPainter old) =>
      gap != old.gap ||
      sway != old.sway ||
      cloth != old.cloth ||
      fold != old.fold ||
      shine != old.shine;
}
