import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/challenges/domain/challenge_incident.dart';
import 'package:critalarm/features/challenges/domain/challenge_rule.dart';
import 'package:critalarm/features/challenges/presentation/challenge.dart';
import 'package:critalarm/features/challenges/presentation/challenge_step.dart';
import 'package:critalarm/features/incidents/domain/alarm_style/alarm_style_gate.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_style_scope.dart';
import 'package:critalarm/features/incidents/presentation/alarm_style/alarm_styles.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The made-up alarm a try runs for. It names no incident, so nothing on
/// it can reach one.
ChallengeIncident sampleChallengeIncident() => ChallengeIncident(
  topic: LocaleKeys.personalize_sample_topic.tr(),
  alertTitle: LocaleKeys.personalize_sample_title.tr(),
);

/// The look the alarm route draws for a topic with no look of its own:
/// the phone's saved one while the plan that unlocks it is held, else the
/// standard one. The standard one too when the answer cannot be had.
AlarmStyle savedChallengeLook() {
  try {
    return alarmStyleOf(getIt<AlarmStyleGate>().styleFor(null));
  } on Object catch (_) {
    return alarmStyleOf(null);
  }
}

/// Puts [child] on the acknowledged canvas with its colours, the way the
/// alarm route does for the real step: in [style], through the one place
/// a look is applied.
class _AckedCanvas extends StatelessWidget {
  const _AckedCanvas({required this.child, this.style});

  final Widget child;

  /// The look to draw in. Null draws the standard one.
  final AlarmStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = context.appColors;
    final brightness = Theme.of(context).brightness;
    // A look that cannot be drawn is the standard one, as on the alarm
    // route.
    final look = drawableAlarmStyle(
      style ?? alarmStyleOf(null),
      base: base,
      severity: SeverityMode.ack,
      brightness: brightness,
    );
    return AlarmStyleStage(
      style: look,
      stage: AlarmStage.acknowledged,
      severity: SeverityMode.ack,
      child: Builder(
        builder: (context) => Material(
          color: context.appColors.canvas,
          child: child,
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
///
/// It is drawn in the look the alarm would be: the phone's saved look
/// ([savedChallengeLook]) unless [style] names another. The look is read
/// once, when the try opens, and held, as the alarm route holds it for an
/// incident.
class ChallengeTryPage extends StatefulWidget {
  const ChallengeTryPage({required this.challenge, this.style, super.key});

  final Challenge challenge;

  /// The look to draw the try in. Null draws the phone's saved one.
  final AlarmStyle? style;

  static Route<void> route(Challenge challenge, {AlarmStyle? style}) =>
      PageRouteBuilder<void>(
        fullscreenDialog: true,
        pageBuilder: (context, _, _) =>
            ChallengeTryPage(challenge: challenge, style: style),
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
  late final AlarmStyle _look = widget.style ?? savedChallengeLook();

  void _leave() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return _AckedCanvas(
      style: _look,
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
    // The face keeps its own outline and features on the look's canvas,
    // from the palette the acknowledged screen takes them from.
    final facePalette = AlarmStyleScope.of(
      context,
    ).facePaletteFor(Theme.of(context).brightness);
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
