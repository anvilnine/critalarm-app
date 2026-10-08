import 'dart:math' as math;

import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/intros/false_alarm/false_alarm_timeline.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
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

/// The false alarm: the screen looks like an alarm for about a second, the
/// mascot blinks and admits it, and the red opens from where the mascot
/// stands to show the layout under it.
///
/// A silent picture of an alarm. The app makes none.
const PaywallIntro falseAlarmIntro = PaywallIntro(
  seconds: FalseAlarmTimeline.end,
  handover: FalseAlarmTimeline.handover,
  skipTo: FalseAlarmTimeline.reveal,
  tone: PaywallTone.crit,
  cue: PaywallEntranceCue.gag,
  builder: _build,
);

Widget _build(BuildContext context, PaywallIntroScope scope) =>
    FalseAlarmIntro(scope: scope);

/// Draws the false alarm for the second its scope's clock reads: the
/// screen in the alarm red, the mascot large and ringing, one big word,
/// then the admission. Where the red has opened it draws nothing.
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
        final presence = FalseAlarmTimeline.presence(t);
        final leave = Curves.easeIn.transform(1 - presence);
        final saysAlarm = FalseAlarmTimeline.saysAlarm(t);
        final admit = AppCurves.easeBack.transform(
          FalseAlarmTimeline.admission(t),
        );

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RedPainter(
                  centre: centre,
                  face: face,
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
            Positioned(
              left: centre.dx - face / 2,
              top: centre.dy - face / 2,
              child: Transform.rotate(
                angle: FalseAlarmTimeline.shake(t),
                child: Transform.scale(
                  scale: (1 + 0.05 * ringing) * (1 - leave),
                  child: FaceWidget(
                    state: FaceState.happy,
                    shape: _faceAt(t),
                    size: face,
                  ),
                ),
              ),
            ),
            Positioned(
              left: Spacing.s5,
              right: Spacing.s5,
              top: centre.dy + face / 2 + Spacing.s6,
              height: wordSize * 1.1,
              child: Opacity(
                opacity: saysAlarm
                    ? 1
                    : admit.clamp(0, 1) * FalseAlarmTimeline.words(t),
                child: Transform.scale(
                  scale: saysAlarm ? 1 + 0.06 * ringing : 0.8 + 0.2 * admit,
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

/// The red and the pulse rings around the mascot. As the red gives way it
/// opens in a circle from the mascot outwards, and nothing is painted
/// inside that circle: the layout under the intro shows through.
class _RedPainter extends CustomPainter {
  const _RedPainter({
    required this.centre,
    required this.face,
    required this.wipe,
    required this.rings,
    required this.red,
    required this.ring,
  });

  final Offset centre;
  final double face;
  final double wipe;
  final List<double?> rings;
  final Color red;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    if (wipe > 0) {
      final reach = [
        screen.topLeft,
        screen.topRight,
        screen.bottomLeft,
        screen.bottomRight,
      ].map((corner) => (corner - centre).distance).reduce(math.max);
      canvas
        ..save()
        ..clipPath(
          Path.combine(
            PathOperation.difference,
            Path()..addRect(screen),
            Path()..addOval(
              Rect.fromCircle(center: centre, radius: reach * wipe),
            ),
          ),
        );
    }
    canvas.drawRect(screen, Paint()..color = red);

    for (final progress in rings) {
      if (progress == null) continue;
      final out = AppCurves.easeOut.transform(progress);
      canvas.drawCircle(
        centre,
        face * 0.56 * (1 + 0.7 * out),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = ring.withValues(alpha: ring.a * (1 - out)),
      );
    }
    if (wipe > 0) canvas.restore();
  }

  @override
  bool shouldRepaint(_RedPainter old) =>
      wipe != old.wipe ||
      centre != old.centre ||
      face != old.face ||
      red != old.red ||
      ring != old.ring ||
      rings[0] != old.rings[0] ||
      rings[1] != old.rings[1];
}
