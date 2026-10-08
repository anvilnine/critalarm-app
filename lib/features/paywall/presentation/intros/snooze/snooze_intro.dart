import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/intros/intro_parts.dart';
import 'package:critalarm/features/paywall/presentation/intros/snooze/snooze_timeline.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The snooze snack: a finger goes for a Snooze button, the button hops
/// out of the way twice, and on the third go the mascot eats it. Then the
/// screen drops away off the layout.
const PaywallIntro snoozeIntro = PaywallIntro(
  seconds: SnoozeTimeline.end,
  handover: SnoozeTimeline.handover,
  skipTo: SnoozeTimeline.reveal,
  tone: PaywallTone.surface,
  cue: PaywallEntranceCue.none,
  beats: [
    // The button hops away from the finger, twice.
    PaywallIntroBeat(SnoozeTimeline.dodgeLeft, PaywallCue.introBounce),
    PaywallIntroBeat(SnoozeTimeline.dodgeRight, PaywallCue.introBounce),
    // The mascot swallows the button.
    PaywallIntroBeat(SnoozeTimeline.gulp, PaywallCue.pop),
    // It went down well: a gulp and a hiccup as the screen drops away.
    PaywallIntroBeat(SnoozeTimeline.reveal, PaywallCue.introGulp),
  ],
  tag: _tag,
  builder: _build,
);

String _tag() => LocaleKeys.paywall_intro_snooze_line.tr();

Widget _build(BuildContext context, PaywallIntroScope scope) =>
    SnoozeIntro(scope: scope);

/// Draws the snooze snack for the second its scope's clock reads. Where
/// the screen has dropped away it draws nothing.
class SnoozeIntro extends StatelessWidget {
  const SnoozeIntro({required this.scope, super.key});

  final PaywallIntroScope scope;

  @override
  Widget build(BuildContext context) {
    final tone = PaywallToneColors.of(context, PaywallTone.surface);
    final size = scope.size;
    final stage = introStageFor(size, scope.padding.top);
    final button = Size(size.width * 0.44, 56);
    final hop = size.width * 0.25;
    final home = stage.word.center;
    final mouth = stage.face.center + Offset(0, stage.face.height * 0.2);
    final label = LocaleKeys.paywall_intro_snooze_button.tr();
    final line = LocaleKeys.paywall_intro_snooze_line.tr();

    return PaywallClockBuilder(
      clock: scope.clock,
      builder: (context, t, _) {
        if (SnoozeTimeline.isOver(t)) return const SizedBox.shrink();
        final fall = SnoozeTimeline.wipe(t);
        final swallowed = SnoozeTimeline.swallowed(t);
        final at = Offset.lerp(
          home +
              Offset(
                hop * SnoozeTimeline.buttonSide(t),
                -18 * SnoozeTimeline.buttonHop(t),
              ),
          mouth,
          Curves.easeIn.transform(swallowed),
        )!;
        final finger = SnoozeTimeline.finger(t);
        final fingerAt =
            home + Offset(hop * finger.side, button.height * finger.below);
        final fingerShows = SnoozeTimeline.fingerPresence(t);
        final said = AppCurves.easeBack.transform(SnoozeTimeline.line(t));

        return Stack(
          children: [
            // The screen, from its falling top edge down.
            Positioned(
              left: 0,
              right: 0,
              top: size.height * fall,
              bottom: 0,
              child: ColoredBox(color: tone.background),
            ),
            IntroCrit(
              box: stage.face,
              scope: scope,
              shape: introFaceShape(SnoozeTimeline.face(t)),
              leave: SnoozeTimeline.leave(t),
              scale: 1 + 0.06 * SnoozeTimeline.swell(t),
            ),
            if (swallowed < 1)
              Positioned(
                left: at.dx - button.width / 2,
                top: at.dy - button.height / 2,
                width: button.width,
                height: button.height,
                child: Transform.scale(
                  scale: 1 - swallowed,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: tone.ink,
                      shape: const StadiumBorder(),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        maxLines: 1,
                        textScaler: TextScaler.noScaling,
                        style: AppTypography.title(tone.background),
                      ),
                    ),
                  ),
                ),
              ),
            IntroWord(
              text: line,
              box: stage.word,
              style: AppTypography.headline(
                tone.ink,
                fontSize: stage.wordSize * 0.5,
              ),
              opacity: said * SnoozeTimeline.words(t),
              scale: 0.8 + 0.2 * said,
            ),
            // The finger: a touch mark, as a screen recording shows one.
            if (fingerShows > 0)
              Positioned(
                left: fingerAt.dx - 24,
                top: fingerAt.dy - 24,
                width: 48,
                height: 48,
                child: Opacity(
                  opacity: fingerShows,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tone.ink.withValues(alpha: 0.18),
                      border: Border.all(
                        color: tone.ink.withValues(alpha: 0.5),
                        width: 2,
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
