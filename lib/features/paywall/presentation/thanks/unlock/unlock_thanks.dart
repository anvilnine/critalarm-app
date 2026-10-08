import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/features/paywall/presentation/thanks/thanks_parts.dart';
import 'package:critalarm/features/paywall/presentation/thanks/unlock/unlock_timeline.dart';
import 'package:flutter/material.dart';

/// Unlock: every line comes in behind a padlock, the padlocks open one
/// after another, and the mascot jumps when the last one is open.
const PaywallThanks unlockThanks = PaywallThanks(
  seconds: UnlockTimeline.end,
  cover: UnlockTimeline.cover,
  buttonAt: UnlockTimeline.button,
  tone: PaywallTone.panel,
  beats: unlockBeats,
  builder: _build,
);

/// What is felt on the way. The purchase cue is sounding the whole time,
/// so every beat is a haptic alone: one small click a padlock, then the
/// landing.
List<PaywallThanksBeat> unlockBeats(int lines) => [
  for (var i = 0; i < lines; i++)
    PaywallThanksBeat.tap(
      UnlockTimeline.openAt(i, lines) + UnlockTimeline.openSeconds / 2,
      HapticPattern.tick,
    ),
  PaywallThanksBeat.tap(UnlockTimeline.landed(lines), HapticPattern.medium),
];

Widget _build(BuildContext context, PaywallThanksScope scope) =>
    UnlockThanks(scope: scope);

/// Draws the unlock version for the second its scope's clock reads.
class UnlockThanks extends StatelessWidget {
  const UnlockThanks({required this.scope, super.key});

  final PaywallThanksScope scope;

  static const PaywallTone _tone = PaywallTone.panel;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tone = PaywallToneColors.of(context, _tone);
    final lines = thanksLines(scope);
    final count = lines.length;
    final stage = ThanksStage.of(
      size: scope.size,
      padding: scope.padding,
      lines: count,
      textScale: MediaQuery.textScalerOf(context).scale(1),
    );
    final headline = thanksHeadline(scope.product);

    return PaywallClockBuilder(
      clock: scope.clock,
      builder: (context, t, _) {
        final rest = t - UnlockTimeline.end;
        final box = Rect.lerp(
          thanksStartBox(scope.mascot) ?? stage.crit,
          stage.crit,
          UnlockTimeline.travel(t),
        )!;
        final ring = UnlockTimeline.ring(t, count: count);

        return Stack(
          children: [
            ThanksCover(
              color: tone.background,
              centre: scope.source,
              grown: UnlockTimeline.covered(t),
            ),
            ThanksDisc(
              stage: stage,
              tone: _tone,
              grown: UnlockTimeline.disc(t, count: count),
            ),
            // One ring leaves the disc as the mascot jumps, and is gone.
            if (ring > 0 && ring < 1)
              Positioned.fromRect(
                rect: Rect.fromCircle(
                  center: stage.crit.center,
                  radius: stage.crit.width * (0.76 + 0.5 * ring),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: tone.ink.withValues(alpha: 0.22 * (1 - ring)),
                      width: 3,
                    ),
                  ),
                ),
              ),
            ThanksCrit(
              box: box,
              face: UnlockTimeline.face(t, count: count),
              lift: UnlockTimeline.lift(t, count: count),
              stretch: UnlockTimeline.stretch(t, count: count),
              blink: rest > 0 ? heroBlinkAt(rest) : 0,
              bob: math.max(0, rest),
              shadow: UnlockTimeline.travel(t),
            ),
            ThanksWords(
              stage: stage,
              tone: _tone,
              headline: headline,
              lines: lines,
              headlineIn: UnlockTimeline.headlineIn(t, count: count),
              lineIn: (i) => UnlockTimeline.lineIn(t, i),
              lineStrong: (i) => UnlockTimeline.open(t, i, count),
              mark: (i) {
                final open = UnlockTimeline.open(t, i, count);
                return Transform.rotate(
                  angle: UnlockTimeline.shake(t, i, count),
                  child: CustomPaint(
                    size: const Size.square(ThanksStage.markSize),
                    painter: _LockPainter(
                      open: open,
                      shut: tone.muted,
                      disc: colors.highlight,
                      ink: colors.onHighlight,
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// A small padlock in a round mark. Shut, it is an outline. As it opens
/// its shackle lifts straight up out of the body on one side, and the
/// mark fills in behind it. It ends upright.
class _LockPainter extends CustomPainter {
  const _LockPainter({
    required this.open,
    required this.shut,
    required this.disc,
    required this.ink,
  });

  /// 0 to 1.
  final double open;
  final Color shut;
  final Color disc;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final centre = size.center(Offset.zero);
    // The shackle gives in the second half of the opening.
    final given = AppCurves.easeBack.transform(
      ((open - 0.5) * 2).clamp(0.0, 1.0),
    );
    final filled = (open * 2).clamp(0.0, 1.0);
    if (filled > 0) {
      canvas.drawCircle(
        centre,
        s / 2 * (0.7 + 0.3 * AppCurves.easeBack.transform(filled)),
        Paint()..color = disc.withValues(alpha: filled),
      );
    }
    final color = Color.lerp(shut, ink, filled)!;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.27, s * 0.47, s * 0.46, s * 0.33),
      Radius.circular(s * 0.08),
    );
    final lift = s * 0.13 * given;
    final legs = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.09
      ..strokeCap = StrokeCap.round;
    final left = s * 0.37;
    final right = s * 0.63;
    final top = s * 0.34 - lift;
    // The left leg stays in the body. The right one comes out of it.
    final shackle = Path()
      ..moveTo(left, s * 0.5)
      ..lineTo(left, top)
      ..arcToPoint(
        Offset(right, top),
        radius: Radius.circular((right - left) / 2),
      )
      ..lineTo(right, s * 0.48 - lift * 1.5);
    canvas
      ..drawPath(shackle, legs)
      ..drawRRect(body, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LockPainter old) =>
      open != old.open || shut != old.shut || disc != old.disc;
}
