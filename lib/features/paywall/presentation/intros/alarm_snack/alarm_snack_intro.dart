import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/presentation/intros/alarm_snack/alarm_snack_timeline.dart';
import 'package:critalarm/features/paywall/presentation/intros/intro_parts.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_cue_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The alarm snack: the screen looks like an alarm with a Snooze button, a
/// finger goes for the button, the button hops out of the way twice, and
/// on the third go the mascot eats it. The ringing stops dead, the mascot
/// grins, and the red opens from where it stands to show the layout.
///
/// A silent picture of an alarm. The app makes none. The score is the only
/// sound: a soft ringing figure with a nudge on each hop, cut dead on the
/// gulp, a beat of nothing, and the arrival from the reveal. The hand feels
/// one light tap for each hop, the gulp and the reveal: single taps well
/// apart, never a buzz. A tap that skips the joke plays the arrival alone.
const PaywallIntro alarmSnackIntro = PaywallIntro(
  seconds: AlarmSnackTimeline.end,
  handover: AlarmSnackTimeline.handover,
  skipTo: AlarmSnackTimeline.reveal,
  tone: PaywallTone.crit,
  cue: PaywallEntranceCue.none,
  score: PaywallCue.scoreAlarmSnack,
  beats: [
    // The button hops away from the finger, twice.
    PaywallIntroBeat.tap(AlarmSnackTimeline.dodgeLeft, HapticPattern.light),
    PaywallIntroBeat.tap(AlarmSnackTimeline.dodgeRight, HapticPattern.light),
    // The mascot swallows the button.
    PaywallIntroBeat.tap(AlarmSnackTimeline.gulp, HapticPattern.medium),
    // The red gives way.
    PaywallIntroBeat.tap(AlarmSnackTimeline.reveal, HapticPattern.light),
  ],
  skipCue: PaywallCue.introArrive,
  quietAfter:
      AlarmSnackTimeline.reveal +
      paywallIntroArrivalSeconds -
      AlarmSnackTimeline.handover,
  tag: _tag,
  builder: _build,
);

String _tag() => LocaleKeys.paywall_intro_alarm_snack_line.tr();

Widget _build(BuildContext context, PaywallIntroScope scope) =>
    AlarmSnackIntro(scope: scope);

/// Draws the alarm snack for the second its scope's clock reads. Where the
/// red has opened it draws nothing.
class AlarmSnackIntro extends StatelessWidget {
  const AlarmSnackIntro({required this.scope, super.key});

  final PaywallIntroScope scope;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final ink = PaywallToneColors.of(context, PaywallTone.crit).ink;
    final size = scope.size;
    final stage = introStageFor(size, scope.padding.top);
    final centre = stage.face.center;
    final button = Size(size.width * 0.44, 56);
    final hop = size.width * 0.2;
    final home = Offset(
      size.width / 2,
      stage.word.bottom + Spacing.s5 + button.height / 2,
    );
    final mouth = centre + Offset(0, stage.face.height * 0.2);
    final word = LocaleKeys.paywall_false_alarm_word.tr();
    final label = LocaleKeys.paywall_intro_snooze_button.tr();
    final line = LocaleKeys.paywall_intro_alarm_snack_line.tr();

    return PaywallClockBuilder(
      clock: scope.clock,
      builder: (context, t, _) {
        if (AlarmSnackTimeline.isOver(t)) return const SizedBox.shrink();
        final ringing = AlarmSnackTimeline.ringing(t);
        final saysAlarm = AlarmSnackTimeline.saysAlarm(t);
        final said = AppCurves.easeBack.transform(AlarmSnackTimeline.line(t));
        final swallowed = AlarmSnackTimeline.swallowed(t);
        final at = Offset.lerp(
          home +
              Offset(
                hop * AlarmSnackTimeline.buttonSide(t),
                -18 * AlarmSnackTimeline.buttonHop(t),
              ),
          mouth,
          Curves.easeIn.transform(swallowed),
        )!;
        final finger = AlarmSnackTimeline.finger(t);
        final fingerAt =
            home + Offset(hop * finger.side, button.height * finger.below);
        final fingerShows = AlarmSnackTimeline.fingerPresence(t);

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: IntroAlarmRedPainter(
                  centre: centre,
                  face: stage.face.width,
                  wipe: Curves.easeInOutCubic.transform(
                    AlarmSnackTimeline.wipe(t),
                  ),
                  rings: [
                    AlarmSnackTimeline.pulse(0, t),
                    AlarmSnackTimeline.pulse(1, t),
                  ],
                  red: colors.critCanvas,
                  ring: ink.withValues(alpha: 0.3),
                ),
              ),
            ),
            IntroWord(
              text: saysAlarm ? word : line,
              box: stage.word,
              style: saysAlarm
                  ? AppTypography.display(ink, fontSize: stage.wordSize)
                  : AppTypography.headline(
                      ink,
                      fontSize: stage.wordSize * 0.5,
                    ),
              opacity: saysAlarm ? 1 : said * AlarmSnackTimeline.words(t),
              scale: saysAlarm ? 1 + 0.06 * ringing : 0.8 + 0.2 * said,
            ),
            IntroCrit(
              box: stage.face,
              scope: scope,
              shape: introFaceShape(AlarmSnackTimeline.face(t)),
              leave: AlarmSnackTimeline.leave(t),
              angle: AlarmSnackTimeline.shake(t),
              scale: 1 + 0.05 * ringing + 0.06 * AlarmSnackTimeline.swell(t),
            ),
            if (swallowed < 1)
              IntroPillButton(
                label: label,
                centre: at,
                size: button,
                scale: AlarmSnackTimeline.buttonScale(t),
                color: ink,
                labelColor: colors.critCanvas,
              ),
            if (fingerShows > 0)
              IntroTouchMark(
                centre: fingerAt,
                color: ink,
                opacity: fingerShows,
              ),
          ],
        );
      },
    );
  }
}
