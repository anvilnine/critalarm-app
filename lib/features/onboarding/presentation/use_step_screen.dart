import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/telemetry/onboarding_funnel.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/setup_use_store.dart';
import 'package:critalarm/features/onboarding/domain/setup_use/use_step_rules.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_navigation.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_shell.dart';
import 'package:critalarm/features/onboarding/presentation/setup_text_scale.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/setup_face.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/use_step_widgets.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// One answer on the use step: the glyph drawn on its tile and the two
/// strings it reads.
class _UseOption {
  const _UseOption(this.use, this.glyph, this.title, this.hint);

  final SetupUse use;
  final String glyph;
  final String title;
  final String hint;
}

const _options = <_UseOption>[
  _UseOption(
    SetupUse.servers,
    r'$_', // l10n-ok: glyph
    LocaleKeys.onboarding_use_servers_title,
    LocaleKeys.onboarding_use_servers_hint,
  ),
  _UseOption(
    SetupUse.homelab,
    '[]', // l10n-ok: glyph
    LocaleKeys.onboarding_use_homelab_title,
    LocaleKeys.onboarding_use_homelab_hint,
  ),
  _UseOption(
    SetupUse.jobs,
    '>>', // l10n-ok: glyph
    LocaleKeys.onboarding_use_jobs_title,
    LocaleKeys.onboarding_use_jobs_hint,
  ),
  _UseOption(
    SetupUse.home,
    r'/\', // l10n-ok: glyph
    LocaleKeys.onboarding_use_home_title,
    LocaleKeys.onboarding_use_home_hint,
  ),
  _UseOption(
    SetupUse.other,
    '..', // l10n-ok: glyph
    LocaleKeys.onboarding_use_other_title,
    LocaleKeys.onboarding_use_other_hint,
  ),
];

/// The use step of setup: "What should wake you?".
///
/// Five answers on a white sheet. One tap saves the answer, sends the pick
/// event and moves on, so there is no Continue button. `skip` in the top bar
/// answers "Something else". Back from a later step opens the step again
/// with the saved answer drawn picked, and a tap on any row, that one
/// included, saves it and moves on again.
///
/// A replay saves nothing. It keeps the answer in memory for the rest of the
/// run (`SetupUseReplay`), and sends no event.
class UseStepScreen extends StatefulWidget {
  const UseStepScreen({
    required this.isReplay,
    required this.cameBack,
    super.key,
  });

  /// A look at the screens from Settings: nothing is saved or sent.
  final bool isReplay;

  /// Opened by Back from the first topic.
  final bool cameBack;

  @override
  State<UseStepScreen> createState() => _UseStepScreenState();
}

class _UseStepScreenState extends State<UseStepScreen> {
  SetupUse? _picked;

  /// True from a tap until the step has moved on, so a second tap or a tap
  /// on skip does nothing twice.
  bool _isMovingOn = false;

  @override
  void initState() {
    super.initState();
    _picked = setupUseStartsPicked(
      cameBack: widget.cameBack,
      isReplay: widget.isReplay,
      store: getIt<SetupUseStore>(),
      replay: getIt<SetupUseReplay>(),
    );
  }

  Future<void> _answer(SetupUse use, {bool skipped = false}) async {
    if (_isMovingOn) return;
    setState(() {
      _isMovingOn = true;
      _picked = use;
    });
    try {
      await recordSetupUse(
        use,
        isReplay: widget.isReplay,
        store: getIt<SetupUseStore>(),
        replay: getIt<SetupUseReplay>(),
      );
      unawaited(
        getIt<OnboardingFunnel>().usePicked(
          use: setupUseEventWord(use, skipped: skipped),
          flowId: getIt<OnboardingFlowEngine>().runningFlow().id,
          isReplay: widget.isReplay,
        ),
      );
      if (!mounted) return;
      await finishOnboardingStep(context, OnboardingStepId.use);
    } finally {
      if (mounted) setState(() => _isMovingOn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textScale = setupTextScaleOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final faceSize = useStepFaceSizeFor(textScale: textScale, width: width);
    // The shell's short line about the connect uses the same corner as skip.
    // The rows stay, and one of them is the same answer.
    final cornerIsTaken = OnboardingAmbientScope.hasQuietLineOf(context);
    final canAnswer = !_isMovingOn;

    final footer = Text(
      LocaleKeys.onboarding_use_footer.tr(),
      textAlign: TextAlign.center,
      style: AppTypography.mono(
        colors.onCanvasMuted,
        fontSize: 12,
      ).copyWith(height: 1.4),
    );

    return AppScreenScaffold(
      backgroundColor: Colors.transparent,
      withGhosts: false,
      withFades: false,
      hasTabBar: false,
      topBar: AppTopBar(
        title: setupTopBarTitle(context),
        trailingTapRoom: 4,
        trailing: IgnorePointer(
          ignoring: cornerIsTaken,
          child: ExcludeSemantics(
            excluding: cornerIsTaken,
            child: AnimatedOpacity(
              opacity: cornerIsTaken ? 0 : 1,
              duration: context.motion(AppDurations.base),
              child: UseSkipButton(
                label: LocaleKeys.onboarding_use_skip.tr(),
                onTap: canAnswer
                    ? () => unawaited(_answer(SetupUse.other, skipped: true))
                    : null,
              ),
            ),
          ),
        ),
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.s4,
            Spacing.s4,
            Spacing.s4,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.s1),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: AppFittedTitle(
                            LocaleKeys.onboarding_use_title.tr(),
                            textAlign: TextAlign.start,
                            minFontSize: setupTitleMinFontSize,
                            style: AppTypography.headline(
                              colors.onCanvas,
                              fontSize: useStepTitleSizeFor(width: width),
                            ).copyWith(height: 0.98),
                          ),
                        ),
                      ),
                      if (faceSize > 0) ...[
                        const SizedBox(width: Spacing.s3),
                        Padding(
                          padding: const EdgeInsets.only(bottom: Spacing.s1),
                          child: Hero(
                            tag: SetupFace.heroTag,
                            flightShuttleBuilder: faceFlightShuttleBuilder,
                            child: FaceWidget(
                              state: FaceState.watching,
                              size: faceSize,
                              isLive: true,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.s5),
                UseOptionSheet(
                  children: [
                    for (final option in _options)
                      UseOptionRow(
                        glyph: option.glyph,
                        title: option.title.tr(),
                        hint: option.hint.tr(),
                        isPicked: _picked == option.use,
                        onTap: canAnswer
                            ? () => unawaited(_answer(option.use))
                            : null,
                      ),
                  ],
                ),
                const SizedBox(height: Spacing.s5),
                footer,
              ],
            ),
          ),
        ),
      ],
    );
  }
}
