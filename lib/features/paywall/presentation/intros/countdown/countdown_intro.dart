import 'dart:math' as math;

import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/presentation/intros/countdown/countdown_timeline.dart';
import 'package:critalarm/features/paywall/presentation/intros/intro_parts.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The countdown: a film leader counts three, two, and the mascot will not
/// wait for one. It drops in on the number, flattens it, and the leader's
/// hand sweeps the screen away off the layout.
///
/// The count is a picture of a film leader. It times nothing and nothing
/// runs out.
const PaywallIntro countdownIntro = PaywallIntro(
  seconds: CountdownTimeline.end,
  handover: CountdownTimeline.handover,
  skipTo: CountdownTimeline.reveal,
  cue: PaywallEntranceCue.none,
  beats: [
    PaywallIntroBeat(0, _onCount),
    PaywallIntroBeat(CountdownTimeline.two, _onCount),
    PaywallIntroBeat(CountdownTimeline.squash, _onSquash),
    PaywallIntroBeat(CountdownTimeline.reveal, _onReveal),
  ],
  tag: _tag,
  builder: _build,
);

/// A number comes up.
void _onCount(PaywallCues cues) => cues.tick();

/// The mascot lands on the one.
void _onSquash(PaywallCues cues) {
  cues.gag();
  AppHaptics.capture();
}

/// The hand sweeps the screen away.
void _onReveal(PaywallCues cues) => cues.open();

String _tag() => LocaleKeys.paywall_intro_countdown_line.tr();

Widget _build(BuildContext context, PaywallIntroScope scope) =>
    CountdownIntro(scope: scope);

/// Draws the countdown for the second its scope's clock reads. Where the
/// hand has swept it draws nothing.
class CountdownIntro extends StatelessWidget {
  const CountdownIntro({required this.scope, super.key});

  final PaywallIntroScope scope;

  @override
  Widget build(BuildContext context) {
    final tone = PaywallToneColors.of(context, PaywallTone.canvas);
    final size = scope.size;
    final stage = introStageFor(size, scope.padding.top);
    final edge = stage.face.width;
    final line = LocaleKeys.paywall_intro_countdown_line.tr();

    return PaywallClockBuilder(
      clock: scope.clock,
      builder: (context, t, _) {
        if (CountdownTimeline.isOver(t)) return const SizedBox.shrink();
        final number = CountdownTimeline.number(t);
        final flat = CountdownTimeline.flat(t);
        final comesUp = AppCurves.easeBack.transform(
          CountdownTimeline.numberIn(t),
        );
        final fall = CountdownTimeline.fall(t);
        final squat = CountdownTimeline.squat(t);
        final said = AppCurves.easeBack.transform(CountdownTimeline.line(t));

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _LeaderPainter(
                  centre: stage.face.center,
                  radius: edge * 0.62,
                  sweep: CountdownTimeline.sweep(t),
                  burst: CountdownTimeline.burst(t),
                  wipe: Curves.easeInOutCubic.transform(
                    CountdownTimeline.wipe(t),
                  ),
                  paper: tone.background,
                  ink: tone.ink,
                ),
              ),
            ),
            if (number > 0)
              Positioned.fromRect(
                rect: stage.face,
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.diagonal3Values(
                    (0.7 + 0.3 * comesUp) * (1 + 0.5 * flat),
                    (0.7 + 0.3 * comesUp) * (1 - 0.94 * flat),
                    1,
                  ),
                  child: FittedBox(
                    child: Text(
                      '$number',
                      textScaler: TextScaler.noScaling,
                      style: AppTypography.display(tone.ink, fontSize: edge),
                    ),
                  ),
                ),
              ),
            if (fall > 0)
              IntroCrit(
                box: stage.face,
                scope: scope,
                shape: introFaceShape(CountdownTimeline.face(t)),
                leave: CountdownTimeline.leave(t),
                scale: 1 + 0.05 * squat,
                offset: Offset(
                  0,
                  -(stage.face.bottom + edge * 0.2) * (1 - fall) +
                      edge * 0.04 * squat,
                ),
              ),
            IntroWord(
              text: line,
              box: stage.word,
              style: AppTypography.display(tone.ink, fontSize: stage.wordSize),
              opacity: said * CountdownTimeline.words(t),
              scale: 0.8 + 0.2 * said,
            ),
          ],
        );
      },
    );
  }
}

/// The film leader: the screen, a ring about the number with cross hairs,
/// and the hand going round it. On the way out the hand sweeps the whole
/// screen away from the top, clockwise, and nothing is painted where it
/// has been.
class _LeaderPainter extends CustomPainter {
  const _LeaderPainter({
    required this.centre,
    required this.radius,
    required this.sweep,
    required this.burst,
    required this.wipe,
    required this.paper,
    required this.ink,
  });

  final Offset centre;
  final double radius;
  final double sweep;
  final double burst;
  final double wipe;
  final Color paper;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    final reach = size.longestSide * 2;
    const top = -math.pi / 2;
    if (wipe > 0) {
      canvas
        ..save()
        ..clipPath(
          Path.combine(
            PathOperation.difference,
            Path()..addRect(screen),
            Path()
              ..moveTo(centre.dx, centre.dy)
              ..arcTo(
                Rect.fromCircle(center: centre, radius: reach),
                top,
                2 * math.pi * wipe * 0.9999,
                false,
              )
              ..close(),
          ),
        );
    }
    canvas.drawRect(screen, Paint()..color = paper);

    final faint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = ink.withValues(alpha: 0.22);
    final out = AppCurves.easeOut.transform(burst);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = ink.withValues(alpha: 1 - out);
    final r = radius * (1 + 0.5 * out);
    if (burst <= 0) {
      canvas
        ..drawLine(
          Offset(0, centre.dy),
          Offset(size.width, centre.dy),
          faint,
        )
        ..drawLine(
          Offset(centre.dx, centre.dy - radius * 1.5),
          Offset(centre.dx, centre.dy + radius * 1.5),
          faint,
        )
        ..drawCircle(centre, radius, faint)
        // The hand: the part of the ring it has been round is inked in.
        ..drawArc(
          Rect.fromCircle(center: centre, radius: radius),
          top,
          2 * math.pi * sweep,
          false,
          ring,
        );
    } else if (burst < 1) {
      canvas.drawCircle(centre, r, ring);
    }
    if (wipe > 0) canvas.restore();
    // The hand itself, on the edge of what it has swept.
    if (wipe > 0 && wipe < 1) {
      final angle = top + 2 * math.pi * wipe;
      canvas.drawLine(
        centre,
        centre + Offset(math.cos(angle), math.sin(angle)) * reach,
        Paint()
          ..strokeWidth = 3
          ..color = ink.withValues(alpha: 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(_LeaderPainter old) =>
      sweep != old.sweep ||
      burst != old.burst ||
      wipe != old.wipe ||
      centre != old.centre ||
      radius != old.radius ||
      paper != old.paper ||
      ink != old.ink;
}
