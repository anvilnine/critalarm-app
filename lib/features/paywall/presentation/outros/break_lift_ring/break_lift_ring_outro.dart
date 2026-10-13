import 'dart:math' as math;

import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_outro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/features/paywall/presentation/outros/break_lift_ring/break_lift_ring_painters.dart';
import 'package:critalarm/features/paywall/presentation/outros/break_lift_ring/break_lift_ring_timeline.dart';
import 'package:critalarm/features/paywall/presentation/outros/outro_parts.dart';
import 'package:flutter/material.dart';

typedef _T = BreakLiftRingTimeline;

/// Crit breaks the paywall like a wall, lifts off into the night, and
/// three rings fire from him, one word each. A cobalt flash, then the end
/// state opens from him. Silent: the purchase cue owns the first seconds,
/// so the beats are haptics alone.
const PaywallOutro breakLiftRing = PaywallOutro(
  seconds: BreakLiftRingTimeline.end,
  uncover: BreakLiftRingTimeline.uncover,
  beats: BreakLiftRingTimeline.beats,
  score: PaywallCue.scoreBreakLiftRing,
  scoreSeconds: breakLiftRingScoreSeconds,
  builder: _build,
);

/// How long the score file is. It starts on the purchase frame and rings
/// 1.15 s past the swap, 17 dB under its peak at the swap.
const double breakLiftRingScoreSeconds = 4.9;

Widget _build(BuildContext context, PaywallOutroScope scope) =>
    BreakLiftRing(scope: scope);

/// Draws the outro for the second its scope's clock reads.
class BreakLiftRing extends StatefulWidget {
  const BreakLiftRing({required this.scope, super.key});

  final PaywallOutroScope scope;

  @override
  State<BreakLiftRing> createState() => _BreakLiftRingState();
}

class _BreakLiftRingState extends State<BreakLiftRing> {
  late List<BreakPiece> _pieces = _T.pieces(widget.scope.size);

  @override
  void didUpdateWidget(BreakLiftRing old) {
    super.didUpdateWidget(old);
    if (old.scope.size != widget.scope.size) {
      _pieces = _T.pieces(widget.scope.size);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = widget.scope;
    final colors = context.appColors;
    final panel = PaywallToneColors.of(context, PaywallTone.panel);
    final cobalt = PaywallToneColors.of(context, PaywallTone.cobalt);
    final palette = BreakLiftRingColors(
      paper: colors.surface,
      line: colors.ink,
      edge: colors.inkFixed,
      night: panel.background,
      cream: panel.ink,
      yellow: colors.yellow,
      cobalt: cobalt.background,
      onCobalt: cobalt.ink,
      ground: scope.ground,
    );
    final words = _T.words(scope.words);
    final size = scope.size;
    final k = math.min(
      size.width / _T.reference.width,
      size.height / _T.reference.height,
    );

    return PaywallClockBuilder(
      clock: scope.clock,
      builder: (context, t, _) {
        final pose = _T.pose(
          t,
          size: size,
          land: scope.land,
          mascot: scope.mascot,
        );
        final scene = _T.scene(t);
        final early =
            scene == BreakLiftRingScene.wall ||
            scene == BreakLiftRingScene.broken;
        return Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: early
                    ? BreakPainter(
                        t: t,
                        pieces: _pieces,
                        colors: palette,
                        wall: scope.wall,
                        focus: pose.centre,
                      )
                    : SkyPainter(
                        t: t,
                        colors: palette,
                        crit: (
                          centre: pose.centre,
                          size: pose.size,
                          angle: pose.angle,
                        ),
                      ),
              ),
            ),
            if (scene == BreakLiftRingScene.rings && words.isNotEmpty)
              _Word(
                t: t,
                words: words,
                size: size,
                k: k,
                colors: palette,
                scale: math.min(MediaQuery.textScalerOf(context).scale(1), 1.3),
              ),
            OutroCrit(
              centre: pose.centre,
              size: pose.size,
              face: pose.face,
              squashX: pose.squashX,
              squashY: pose.squashY,
              angle: pose.angle,
            ),
          ],
        );
      },
    );
  }
}

/// The ring's word, very large, on one line however long it is.
class _Word extends StatelessWidget {
  const _Word({
    required this.t,
    required this.words,
    required this.size,
    required this.k,
    required this.colors,
    required this.scale,
  });

  final double t;
  final List<String> words;
  final Size size;
  final double k;
  final BreakLiftRingColors colors;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final index = math.min(_T.wordIndex(t), words.length - 1);
    if (index < 0) return const SizedBox.shrink();
    final pop = _T.wordPop(index, t);
    final fontSize = 128 * k;
    return Positioned(
      left: size.width * 27 / 390,
      width: size.width * 336 / 390,
      top: 650 * size.height / _T.reference.height - fontSize * 0.7,
      height: fontSize * 1.4,
      child: RepaintBoundary(
        child: Opacity(
          opacity: _T.wordFade(index, t),
          child: Transform.scale(
            scale: _T.lerp(1.3, 1, pop),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  words[index],
                  maxLines: 1,
                  softWrap: false,
                  style: AppTypography.display(
                    index == 1 ? colors.yellow : colors.cream,
                    fontSize: fontSize,
                  ).copyWith(letterSpacing: -fontSize * 0.04, height: 1),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
