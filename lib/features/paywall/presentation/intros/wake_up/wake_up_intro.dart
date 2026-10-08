import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/intros/intro_parts.dart';
import 'package:critalarm/features/paywall/presentation/intros/wake_up/wake_up_timeline.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The rude awakening: it is night, the mascot is asleep, a small message
/// drops on its head and it wakes with a start. Then the night rolls up
/// off the layout like a blind.
///
/// Nothing rings and nothing is sent. The message is a drawn chip.
const PaywallIntro wakeUpIntro = PaywallIntro(
  seconds: WakeUpTimeline.end,
  handover: WakeUpTimeline.handover,
  skipTo: WakeUpTimeline.reveal,
  tone: PaywallTone.panel,
  cue: PaywallEntranceCue.none,
  beats: [
    // The message lands on the sleeping mascot.
    PaywallIntroBeat(WakeUpTimeline.bonk, PaywallCue.introKnock),
    // The night rolls up.
    PaywallIntroBeat(WakeUpTimeline.reveal, PaywallCue.kidding),
  ],
  tag: _tag,
  builder: _build,
);

String _tag() => LocaleKeys.paywall_intro_wake_up_line.tr();

Widget _build(BuildContext context, PaywallIntroScope scope) =>
    WakeUpIntro(scope: scope);

/// Where the stars are, as parts of the screen, and how large.
const List<(double, double, double)> _stars = [
  (0.12, 0.13, 2.5),
  (0.3, 0.07, 1.5),
  (0.82, 0.1, 2),
  (0.9, 0.3, 1.5),
  (0.08, 0.42, 2),
  (0.2, 0.66, 1.5),
  (0.86, 0.6, 2.5),
  (0.62, 0.78, 1.5),
  (0.36, 0.88, 2),
];

/// Draws the rude awakening for the second its scope's clock reads. Where
/// the night has rolled up it draws nothing.
class WakeUpIntro extends StatelessWidget {
  const WakeUpIntro({required this.scope, super.key});

  final PaywallIntroScope scope;

  @override
  Widget build(BuildContext context) {
    final tone = PaywallToneColors.of(context, PaywallTone.panel);
    final size = scope.size;
    final stage = introStageFor(size, scope.padding.top);
    final edge = stage.face.width;
    const chip = Size(92, 38);
    final ping = LocaleKeys.paywall_intro_wake_up_ping.tr();
    final line = LocaleKeys.paywall_intro_wake_up_line.tr();

    return PaywallClockBuilder(
      clock: scope.clock,
      builder: (context, t, _) {
        if (WakeUpTimeline.isOver(t)) return const SizedBox.shrink();
        final rolled = Curves.easeInOutCubic.transform(WakeUpTimeline.wipe(t));
        final night = size.height * (1 - rolled);
        final bounce = WakeUpTimeline.bounce(t);
        final head = stage.face.topCenter + Offset(0, edge * 0.06);
        final chipAt = bounce > 0
            ? head +
                  Offset(
                    edge * 0.5 * bounce,
                    -edge * 0.34 * Curves.easeOut.transform(bounce),
                  )
            : Offset(
                head.dx,
                -chip.height + (head.dy + chip.height) * WakeUpTimeline.fall(t),
              );
        final said = AppCurves.easeBack.transform(WakeUpTimeline.line(t));

        return Stack(
          children: [
            // The night, down to its rising bottom edge, and its stars.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: night,
              child: ClipRect(
                child: CustomPaint(
                  painter: _NightPainter(
                    screen: size,
                    night: tone.background,
                    star: tone.ink.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
            IntroCrit(
              box: stage.face,
              scope: scope,
              shape: introFaceShape(WakeUpTimeline.face(t)),
              leave: WakeUpTimeline.leave(t),
              scale: 1 + 0.02 * WakeUpTimeline.breath(t),
              angle: WakeUpTimeline.rock(t),
              offset: Offset(0, -edge * 0.12 * WakeUpTimeline.jolt(t)),
            ),
            if (t >= WakeUpTimeline.drop && bounce < 1)
              Positioned(
                left: chipAt.dx - chip.width / 2,
                top: chipAt.dy - chip.height,
                width: chip.width,
                height: chip.height,
                child: Opacity(
                  opacity: 1 - bounce,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: tone.ink,
                      shape: const StadiumBorder(),
                    ),
                    child: Center(
                      child: Text(
                        ping,
                        maxLines: 1,
                        textScaler: TextScaler.noScaling,
                        style: AppTypography.monoBold(
                          tone.background,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            IntroWord(
              text: line,
              box: stage.word,
              style: AppTypography.display(tone.ink, fontSize: stage.wordSize),
              opacity: said * WakeUpTimeline.words(t),
              scale: 0.8 + 0.2 * said,
            ),
          ],
        );
      },
    );
  }
}

/// The night sky over the whole screen. Its box is cut short from below
/// as it rolls up, so the stars stay where they are.
class _NightPainter extends CustomPainter {
  const _NightPainter({
    required this.screen,
    required this.night,
    required this.star,
  });

  final Size screen;
  final Color night;
  final Color star;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = night);
    final paint = Paint()..color = star;
    for (final (x, y, radius) in _stars) {
      canvas.drawCircle(
        Offset(screen.width * x, screen.height * y),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_NightPainter old) =>
      screen != old.screen || night != old.night || star != old.star;
}
