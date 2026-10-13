import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_outro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/features/paywall/presentation/outros/break_lift/break_lift_painters.dart';
import 'package:critalarm/features/paywall/presentation/outros/break_lift/break_lift_timeline.dart';
import 'package:critalarm/features/paywall/presentation/outros/break_lift_ring/break_lift_ring_painters.dart'
    show BreakPainter;
import 'package:critalarm/features/paywall/presentation/outros/outro_parts.dart';
import 'package:flutter/material.dart';

typedef _T = BreakLiftTimeline;

/// Break and lift: the calm cut of Break, lift, ring. Crit breaks the
/// paywall, the pieces drift off and the night comes through, and he rises
/// in one eased move to where the end state stands him, which then opens
/// from him. No flash, no ring, no cobalt and no word that pops. Two light
/// taps and no score of its own: the purchase cue plays as it does with
/// none.
const PaywallOutro breakLift = PaywallOutro(
  seconds: BreakLiftTimeline.end,
  uncover: BreakLiftTimeline.uncover,
  beats: BreakLiftTimeline.beats,
  builder: _build,
);

Widget _build(BuildContext context, PaywallOutroScope scope) =>
    BreakLift(scope: scope);

/// Draws the outro for the second its scope's clock reads.
class BreakLift extends StatefulWidget {
  const BreakLift({required this.scope, super.key});

  final PaywallOutroScope scope;

  @override
  State<BreakLift> createState() => _BreakLiftState();
}

class _BreakLiftState extends State<BreakLift> {
  late List<BreakPiece> _pieces = _T.pieces(widget.scope.size);

  @override
  void didUpdateWidget(BreakLift old) {
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
        return Stack(
          fit: StackFit.expand,
          children: [
            // Everything under him fades off the end state at the hand
            // over. He stays whole until the swap.
            Opacity(
              opacity: 1 - _T.fadeOut(t),
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: t < _T.hit
                      ? BreakPainter(
                          t: t,
                          pieces: _pieces,
                          colors: palette,
                          wall: scope.wall,
                          focus: pose.centre,
                        )
                      : BreakLiftPainter(
                          t: t,
                          pieces: _pieces,
                          colors: palette,
                          wall: scope.wall,
                          crit: pose.box,
                        ),
                ),
              ),
            ),
            _Welcome(
              alpha: _T.wordsAlpha(t),
              line: scope.words,
              size: size,
              k: k,
              color: panel.ink,
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

/// The welcome line, whole, in one place, fading in and out once.
class _Welcome extends StatelessWidget {
  const _Welcome({
    required this.alpha,
    required this.line,
    required this.size,
    required this.k,
    required this.color,
  });

  final double alpha;
  final String line;
  final Size size;
  final double k;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (alpha <= 0 || line.trim().isEmpty) return const SizedBox.shrink();
    final fontSize = 36 * k;
    return Positioned(
      left: size.width * 28 / 390,
      right: size.width * 28 / 390,
      top: size.height * 0.68,
      child: IgnorePointer(
        child: RepaintBoundary(
          child: Opacity(
            opacity: alpha,
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: Text(
                line,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.display(
                  color,
                  fontSize: fontSize,
                ).copyWith(letterSpacing: -fontSize * 0.03, height: 1.1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
