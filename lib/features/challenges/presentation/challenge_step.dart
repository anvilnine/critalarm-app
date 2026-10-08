import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/challenges/domain/challenge_incident.dart';
import 'package:critalarm/features/challenges/domain/challenge_rule.dart';
import 'package:critalarm/features/challenges/presentation/challenge.dart';
import 'package:critalarm/features/challenges/presentation/hold_to_skip_button.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// A challenge on the screen: the prompt, the task, and the two ways off
/// it that never depend on the task.
///
/// - [onPassed]: the task was done.
/// - [onSkip]: the way out was used, by a ten second hold or, with a screen
///   reader, a plain double tap. It is pinned over the keyboard from the
///   first frame.
/// - [onLeave]: the cross, and the system back. Back to where the person
///   came from, with nothing decided.
///
/// The step closes nothing and knows no incident. Its owner decides what
/// passing and skipping mean: on the alarm screen both close the incident
/// through the same call "At my desk" always made, and in a try neither
/// closes anything.
///
/// It draws on the canvas it is given, with the colours of the scope it is
/// under, so it looks the same on the alarm screen and in the preview.
class ChallengeStep extends StatelessWidget {
  const ChallengeStep({
    required this.challenge,
    required this.incident,
    required this.wayOut,
    required this.onPassed,
    required this.onSkip,
    required this.onLeave,
    this.isPicture = false,
    this.heldFor,
    super.key,
  });

  final Challenge challenge;
  final ChallengeIncident incident;
  final ChallengeWayOut wayOut;
  final VoidCallback onPassed;
  final VoidCallback onSkip;
  final VoidCallback onLeave;

  /// A still picture for the Personalize preview: no focus, no keyboard.
  final bool isPicture;

  /// Draws the way out this far into a hold. Only a capture sets it.
  final Duration? heldFor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onLeave();
      },
      child: AppScreenScaffold(
        hasTabBar: false,
        resizeForKeyboard: true,
        barBacking: colors.canvas,
        // The task is read before the two ways off it.
        contentSortKey: const OrdinalSortKey(0),
        topBar: AppTopBar(
          title: '',
          trailing: Semantics(
            sortKey: const OrdinalSortKey(4),
            child: AppDismissCross(
              onPressed: onLeave,
              label: LocaleKeys.challenges_leave.tr(),
              color: colors.onCanvas,
            ),
          ),
        ),
        bottomBar: Semantics(
          sortKey: const OrdinalSortKey(3),
          child: HoldToSkipButton(
            wayOut: wayOut,
            onSkip: onSkip,
            heldFor: heldFor,
          ),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, Spacing.s2, 20, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    sortKey: const OrdinalSortKey(0),
                    child: Text(
                      challenge.promptKey.tr(),
                      textAlign: TextAlign.center,
                      style: AppTypography.title(colors.onCanvas, fontSize: 22),
                    ),
                  ),
                  const SizedBox(height: Spacing.s4),
                  challenge.build(
                    context,
                    ChallengeRun(
                      incident: incident,
                      onPassed: onPassed,
                      isPicture: isPicture,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
