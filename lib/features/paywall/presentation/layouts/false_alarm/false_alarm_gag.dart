import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/false_alarm/false_alarm_timeline.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
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

/// The joke, edge to edge behind the offer: the screen in the alarm red,
/// the mascot large and ringing, one big word. Then the admission, and the
/// stage tone taking the screen back from where the mascot stands.
///
/// A silent picture of an alarm. It draws the second [clock] reads and
/// nothing once the joke is over, so a still screen never shows it. A tap
/// on it calls [onSkip].
class FalseAlarmGag extends StatelessWidget {
  const FalseAlarmGag({
    required this.clock,
    required this.word,
    required this.admission,
    required this.onSkip,
    super.key,
  });

  final PaywallClock clock;

  /// The one word that reads as an alarm.
  final String word;

  /// What the mascot admits.
  final String admission;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final ink = PaywallToneColors.of(context, PaywallTone.crit).ink;
    final rest = PaywallToneColors.of(context, PaywallTone.canvas).background;
    final top = MediaQuery.viewPaddingOf(context).top;

    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final face = math.min(size.width * 0.52, size.height * 0.26);
          final centre = Offset(
            size.width / 2,
            top + (size.height - top) * 0.34,
          );
          final wordSize = math.min(size.width * 0.21, 84).toDouble();

          return PaywallClockBuilder(
            clock: clock,
            builder: (context, t, _) {
              if (FalseAlarmTimeline.isOver(t)) return const SizedBox.shrink();
              final ringing = FalseAlarmTimeline.ringing(t);
              final presence = FalseAlarmTimeline.presence(t);
              final leave = Curves.easeIn.transform(1 - presence);
              final saysAlarm = FalseAlarmTimeline.saysAlarm(t);
              final admit = AppCurves.easeBack.transform(
                FalseAlarmTimeline.admission(t),
              );

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSkip,
                child: Stack(
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
                          rest: rest,
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
                        opacity: saysAlarm ? 1 : (admit.clamp(0, 1) * presence),
                        child: Transform.scale(
                          scale: saysAlarm
                              ? 1 + 0.06 * ringing
                              : 0.8 + 0.2 * admit,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              saysAlarm ? word : admission,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: saysAlarm
                                  ? AppTypography.display(
                                      ink,
                                      fontSize: wordSize,
                                    )
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// The red, the pulse rings around the mascot, and the stage tone opening
/// from the mascot outwards.
class _RedPainter extends CustomPainter {
  const _RedPainter({
    required this.centre,
    required this.face,
    required this.wipe,
    required this.rings,
    required this.red,
    required this.rest,
    required this.ring,
  });

  final Offset centre;
  final double face;
  final double wipe;
  final List<double?> rings;
  final Color red;
  final Color rest;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = red);

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

    if (wipe <= 0) return;
    final reach = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((corner) => (corner - centre).distance).reduce(math.max);
    canvas.drawCircle(centre, reach * wipe, Paint()..color = rest);
  }

  @override
  bool shouldRepaint(_RedPainter old) =>
      wipe != old.wipe ||
      centre != old.centre ||
      face != old.face ||
      red != old.red ||
      rest != old.rest ||
      ring != old.ring ||
      rings[0] != old.rings[0] ||
      rings[1] != old.rings[1];
}
