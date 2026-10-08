import 'dart:math' as math;

import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/features/paywall/presentation/thanks/confetti/confetti_timeline.dart';
import 'package:critalarm/features/paywall/presentation/thanks/thanks_parts.dart';
import 'package:flutter/material.dart';

/// Confetti: the button bursts, the mascot jumps into a crown, the
/// confetti settles on the floor and the lines check themselves off.
const PaywallThanks confettiThanks = PaywallThanks(
  seconds: ConfettiTimeline.end,
  cover: ConfettiTimeline.cover,
  buttonAt: ConfettiTimeline.goOn,
  beats: confettiBeats,
  builder: _build,
);

/// What is felt on the way. While the purchase cue sounds every beat is a
/// haptic alone. The last one comes as it ends: the confetti settling,
/// which is heard.
List<PaywallThanksBeat> confettiBeats(int lines) => [
  // The crown meets the mascot at the top of the jump.
  const PaywallThanksBeat.tap(ConfettiTimeline.apex, HapticPattern.medium),
  // It lands.
  const PaywallThanksBeat.tap(ConfettiTimeline.land, HapticPattern.light),
  // Each line is checked.
  for (var i = 0; i < lines; i++)
    PaywallThanksBeat.tap(
      ConfettiTimeline.checkAt(i, lines),
      HapticPattern.tick,
    ),
  // The last piece lies still.
  const PaywallThanksBeat(ConfettiTimeline.settled, PaywallCue.settle),
];

Widget _build(BuildContext context, PaywallThanksScope scope) =>
    ConfettiThanks(scope: scope);

/// Draws the confetti version for the second its scope's clock reads.
class ConfettiThanks extends StatelessWidget {
  const ConfettiThanks({required this.scope, super.key});

  final PaywallThanksScope scope;

  static const PaywallTone _tone = PaywallTone.canvas;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tone = PaywallToneColors.of(context, _tone);
    final lines = thanksLines(scope);
    final stage = ThanksStage.of(
      size: scope.size,
      padding: scope.padding,
      lines: lines.length,
      textScale: MediaQuery.textScalerOf(context).scale(1),
    );
    final headline = thanksHeadline(scope.product);
    final origin = scope.origin;
    // No cobalt among them: that is the button's.
    final inks = [colors.onCanvas, colors.surface, colors.crit, colors.cream];

    return PaywallClockBuilder(
      clock: scope.clock,
      builder: (context, t, _) {
        final rest = t - ConfettiTimeline.end;
        final box = Rect.lerp(
          thanksStartBox(scope.mascot) ?? stage.crit,
          stage.crit,
          ConfettiTimeline.travel(t),
        )!;
        final button = ConfettiTimeline.button(t);

        return Stack(
          children: [
            ThanksCover(
              color: tone.background,
              centre: scope.source,
              grown: ConfettiTimeline.covered(t),
            ),
            ThanksDisc(
              stage: stage,
              tone: _tone,
              grown: ConfettiTimeline.disc(t),
            ),
            // The pressed button, swelling as it bursts.
            if (origin != null && button > 0)
              Positioned.fromRect(
                rect: origin,
                child: Transform.scale(
                  scale: button,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.cobalt,
                      borderRadius: BorderRadius.circular(origin.height / 2),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: CustomPaint(
                painter: ThanksConfettiPainter(
                  t: t - ConfettiTimeline.burst,
                  origin: scope.source,
                  floor: stage.floor,
                  inks: inks,
                ),
              ),
            ),
            ThanksCrit(
              box: box,
              face: ConfettiTimeline.face(t),
              lift: ConfettiTimeline.lift(t, lines: lines.length),
              stretch: ConfettiTimeline.stretch(t),
              angle: ConfettiTimeline.lean(t),
              blink: rest > 0 ? heroBlinkAt(rest) : 0,
              bob: math.max(0, rest),
              props: {
                if (ConfettiTimeline.crown(t) > 0)
                  HeroProp.crown: ConfettiTimeline.crown(t),
              },
              shadow: ConfettiTimeline.travel(t),
            ),
            ThanksWords(
              stage: stage,
              tone: _tone,
              headline: headline,
              lines: lines,
              headlineIn: ConfettiTimeline.headlineIn(t),
              lineIn: (i) => ConfettiTimeline.lineIn(t, i),
              lineStrong: (i) => ConfettiTimeline.check(t, i, lines.length),
              mark: (i) => ThanksCheck(
                on: ConfettiTimeline.check(t, i, lines.length),
                tone: _tone,
              ),
            ),
          ],
        );
      },
    );
  }
}
