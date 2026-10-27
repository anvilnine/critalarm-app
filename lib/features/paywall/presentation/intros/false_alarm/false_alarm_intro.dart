import 'dart:math' as math;

import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/presentation/intros/false_alarm/false_alarm_timeline.dart';
import 'package:critalarm/features/paywall/presentation/intros/intro_parts.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_cue_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

FaceShape _shapeOf(FalseAlarmFace face) => faceFor(switch (face) {
  FalseAlarmFace.alarmed => FaceState.alarmed,
  FalseAlarmFace.sheepish => FaceState.proud,
  FalseAlarmFace.glad => FaceState.happy,
});

/// The face of the large mascot at [t], held upright: the lean is the
/// ring's, never the face's own.
FaceShape _faceAt(double t) {
  final face = FalseAlarmTimeline.face(t);
  final blend = Curves.easeInOutCubic.transform(face.blend);
  final shape = FaceShape.lerp(_shapeOf(face.from), _shapeOf(face.to), blend);
  final upright = FaceShape(
    leftEye: shape.leftEye,
    rightEye: shape.rightEye,
    mouth: shape.mouth,
    leftBrow: shape.leftBrow,
    rightBrow: shape.rightBrow,
    head: shape.head,
    props: shape.props,
  );
  final blink = FalseAlarmTimeline.blink(t);
  if (blink <= 0) return upright;
  return FaceShape.lerp(upright, upright.blinking, blink);
}

/// The false alarm: the alarm red floods out from where the mascot stands,
/// the mascot pops up and the big word lands. The screen looks like an
/// alarm for about a second, the mascot blinks and admits it, and the red
/// opens from the same place to show the layout under it.
///
/// A silent picture of an alarm. The app makes none. The score is the only
/// sound and owns the whole intro: air that rises with the red, a soft
/// ringing figure for as long as the screen rings, two small notes for the
/// admission while the figure dies away, and the arrival from the reveal.
/// Nothing is felt while the screen rings. A tap that skips the joke plays
/// the arrival alone.
const PaywallIntro falseAlarmIntro = PaywallIntro(
  seconds: FalseAlarmTimeline.end,
  handover: FalseAlarmTimeline.handover,
  skipTo: FalseAlarmTimeline.reveal,
  tone: PaywallTone.crit,
  cue: PaywallEntranceCue.none,
  score: PaywallCue.scoreFalseAlarm,
  beats: [
    PaywallIntroBeat.tap(FalseAlarmTimeline.reveal, HapticPattern.tripleRise),
  ],
  skipCue: PaywallCue.introArrive,
  quietAfter:
      FalseAlarmTimeline.reveal +
      paywallIntroArrivalSeconds -
      FalseAlarmTimeline.handover,
  tag: _tag,
  builder: _build,
);

String _tag() => LocaleKeys.paywall_false_alarm_admission.tr();

Widget _build(BuildContext context, PaywallIntroScope scope) =>
    FalseAlarmIntro(scope: scope);

/// Draws the false alarm for the second its scope's clock reads: the red
/// flooding in, the mascot large and ringing, one big word, then the
/// admission. Where the red has opened it draws nothing.
class FalseAlarmIntro extends StatelessWidget {
  const FalseAlarmIntro({required this.scope, super.key});

  final PaywallIntroScope scope;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final ink = PaywallToneColors.of(context, PaywallTone.crit).ink;
    final word = LocaleKeys.paywall_false_alarm_word.tr();
    final admission = LocaleKeys.paywall_false_alarm_admission.tr();
    final size = scope.size;
    final top = scope.padding.top;
    final face = math.min(size.width * 0.52, size.height * 0.26);
    final centre = Offset(size.width / 2, top + (size.height - top) * 0.34);
    final wordSize = math.min(size.width * 0.21, 84).toDouble();

    return PaywallClockBuilder(
      clock: scope.clock,
      builder: (context, t, _) {
        if (FalseAlarmTimeline.isOver(t)) return const SizedBox.shrink();
        final ringing = FalseAlarmTimeline.ringing(t);
        final saysAlarm = FalseAlarmTimeline.saysAlarm(t);
        final arrive = FalseAlarmTimeline.arrive(t);
        final wordIn = AppCurves.easeOut.transform(
          FalseAlarmTimeline.wordIn(t),
        );
        final admit = AppCurves.easeBack.transform(
          FalseAlarmTimeline.admission(t),
        );

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: IntroAlarmRedPainter(
                  centre: centre,
                  face: face,
                  flood: Curves.easeInOutCubic.transform(
                    FalseAlarmTimeline.flood(t),
                  ),
                  cover: colors.canvas,
                  wipe: Curves.easeInOutCubic.transform(
                    FalseAlarmTimeline.wipe(t),
                  ),
                  rings: [
                    FalseAlarmTimeline.ring(0, t),
                    FalseAlarmTimeline.ring(1, t),
                  ],
                  red: colors.critCanvas,
                  ring: ink.withValues(alpha: 0.3),
                ),
              ),
            ),
            IntroCrit(
              box: Rect.fromCenter(center: centre, width: face, height: face),
              scope: scope,
              shape: _faceAt(t),
              leave: FalseAlarmTimeline.leave(t),
              angle: FalseAlarmTimeline.shake(t),
              // It pops up from just under where it stands.
              scale:
                  AppCurves.easeBack.transform(arrive) * (1 + 0.05 * ringing),
              offset: Offset(
                0,
                face * 0.18 * (1 - AppCurves.easeOut.transform(arrive)),
              ),
            ),
            Positioned(
              left: Spacing.s5,
              right: Spacing.s5,
              top: centre.dy + face / 2 + Spacing.s6,
              height: wordSize * 1.1,
              child: Opacity(
                opacity: saysAlarm
                    ? wordIn
                    : admit.clamp(0, 1) * FalseAlarmTimeline.words(t),
                child: Transform.scale(
                  // The word lands from a little large, then swells with
                  // each ring.
                  scale: saysAlarm
                      ? 1.3 - 0.3 * wordIn + 0.06 * ringing
                      : 0.8 + 0.2 * admit,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      saysAlarm ? word : admission,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: saysAlarm
                          ? AppTypography.display(ink, fontSize: wordSize)
                          : AppTypography.headline(
                              ink,
                              fontSize: wordSize * 0.5,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
