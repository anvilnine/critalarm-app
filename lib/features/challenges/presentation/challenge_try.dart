import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/challenges/domain/challenge_incident.dart';
import 'package:critalarm/features/challenges/domain/challenge_rule.dart';
import 'package:critalarm/features/challenges/presentation/challenge.dart';
import 'package:critalarm/features/challenges/presentation/challenge_step.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The made-up alarm a try runs for. It names no incident, so nothing on
/// it can reach one.
ChallengeIncident sampleChallengeIncident() => ChallengeIncident(
  topic: LocaleKeys.personalize_sample_topic.tr(),
  alertTitle: LocaleKeys.personalize_sample_title.tr(),
);

/// Puts [child] on the acknowledged canvas with its colours, the way the
/// alarm route does for the real step.
class _AckedCanvas extends StatelessWidget {
  const _AckedCanvas({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SeverityScope(
    mode: SeverityMode.ack,
    child: Builder(
      builder: (context) => Material(
        color: context.appColors.canvas,
        child: child,
      ),
    ),
  );
}

/// A challenge as a still picture for the Personalize preview frame: the
/// real step, laid out for [screen] and scaled to the room it is given.
///
/// It is inert. It takes no touch, no focus and no screen reader stop, and
/// it opens no keyboard. The frame around it opens the try.
class ChallengePicture extends StatelessWidget {
  const ChallengePicture({
    required this.challenge,
    required this.screen,
    super.key,
  });

  final Challenge challenge;

  /// The screen the picture is laid out for.
  final MediaQueryData screen;

  static void _nothing() {}

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: ExcludeFocus(
          child: FittedBox(
            clipBehavior: Clip.hardEdge,
            child: SizedBox.fromSize(
              size: screen.size,
              child: MediaQuery(
                data: screen,
                child: HeroMode(
                  enabled: false,
                  child: AmbientScope(
                    child: _AckedCanvas(
                      child: ChallengeStep(
                        challenge: challenge,
                        incident: sampleChallengeIncident(),
                        wayOut: ChallengeWayOut.hold,
                        isPicture: true,
                        onPassed: _nothing,
                        onSkip: _nothing,
                        onLeave: _nothing,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A challenge run once as a try, on the whole screen, for a sample topic.
///
/// It is the real step with the real way out. It knows no incident and no
/// cubit, so passing it, holding the way out and the cross all end the try
/// and close nothing.
class ChallengeTryPage extends StatefulWidget {
  const ChallengeTryPage({required this.challenge, super.key});

  final Challenge challenge;

  static Route<void> route(Challenge challenge) => PageRouteBuilder<void>(
    fullscreenDialog: true,
    pageBuilder: (context, _, _) => ChallengeTryPage(challenge: challenge),
    transitionsBuilder: (context, animation, _, child) =>
        MediaQuery.of(context).disableAnimations
        ? child
        : FadeTransition(opacity: animation, child: child),
  );

  @override
  State<ChallengeTryPage> createState() => _ChallengeTryPageState();
}

class _ChallengeTryPageState extends State<ChallengeTryPage> {
  bool _didPass = false;

  void _leave() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return _AckedCanvas(
      child: _didPass
          ? _Passed(onDone: _leave)
          : ChallengeStep(
              challenge: widget.challenge,
              incident: sampleChallengeIncident(),
              wayOut: MediaQuery.accessibleNavigationOf(context)
                  ? ChallengeWayOut.tap
                  : ChallengeWayOut.hold,
              onPassed: () => setState(() => _didPass = true),
              onSkip: _leave,
              onLeave: _leave,
            ),
    );
  }
}

/// What a passed try ends on: Crit glad, one line, one button.
class _Passed extends StatelessWidget {
  const _Passed({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    // The face keeps its own outline and features on the navy canvas.
    final facePalette = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    return AppScreenScaffold(
      hasTabBar: false,
      barBacking: colors.canvas,
      bottomBar: AppButton(
        label: LocaleKeys.challenges_try_done.tr(),
        variant: AppButtonVariant.paper,
        isFullWidth: true,
        onPressed: onDone,
      ),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaceWidget(
                  state: FaceState.content,
                  size: 160,
                  overrideStrokeColor: facePalette.faceStroke,
                  overrideInkColor: facePalette.faceInk,
                ),
                const SizedBox(height: Spacing.s4),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    LocaleKeys.challenges_try_passed.tr(),
                    textAlign: TextAlign.center,
                    style: AppTypography.title(colors.onCanvas, fontSize: 22),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
