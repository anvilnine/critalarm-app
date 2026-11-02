part of 'critical_alarm_screen.dart';

extension _AcknowledgedExits on AcknowledgedScreen {
  /// The pinned buttons of the acknowledged screen.
  Widget _bottomBar(
    BuildContext context, {
    required AckedExits exits,
    required SetupTestKind setupTest,
    required AlarmAcknowledgedLook look,
    required bool isClosed,
    required bool pinsHint,
  }) {
    final isDemo = exits != AckedExits.incident;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: isDemo
          ? _demoExits(context, exits: exits, setupTest: setupTest)
          : _incidentExits(
              context,
              look: look,
              isClosed: isClosed,
              pinsHint: pinsHint,
            ),
    );
  }

  List<Widget> _demoExits(
    BuildContext context, {
    required AckedExits exits,
    required SetupTestKind setupTest,
  }) {
    final incident = state.incident;
    return [
      ...switch (exits) {
        // Setup goes on. The flow says what comes next, and ends
        // setup itself when nothing does.
        AckedExits.continueSetup => [
          _ContinueSetupButton(
            setupTest: setupTest,
            incidentId: incident?.id ?? '',
          ),
        ],
        // The user's own tool rang the phone: setup is proved. One
        // button, which ends that one incident and goes Home.
        AckedExits.firstToolAlarm => [
          _FinishFirstToolButton(incidentId: incident?.id ?? ''),
        ],
        // Onboarding is done, so the only thing left is the way out.
        AckedExits.retest => [
          AppButton(
            label: LocaleKeys.onboarding_connect_celebration_finish.tr(),
            variant: AppButtonVariant.cream,
            size: AppButtonSize.lg,
            isFullWidth: true,
            onPressed: () {
              AppHaptics.capture();
              context.go('/');
            },
          ),
        ],
        AckedExits.legacyFinish => [
          AppButton(
            label: LocaleKeys.onboarding_connect_celebration_finish.tr(),
            variant: AppButtonVariant.cream,
            size: AppButtonSize.lg,
            isFullWidth: true,
            onPressed: () async {
              AppHaptics.capture();
              await getIt<CompleteOnboardingUsecase>()(
                const NoParams(),
              );
              if (context.mounted) {
                context.go('/');
              }
            },
          ),
        ],
        AckedExits.legacyCreateTopicOrFinish || AckedExits.incident => [
          // The first topic is the next step. Cream, because cobalt
          // on the navy acknowledged canvas would disappear.
          AppButton(
            label: LocaleKeys.onboarding_connect_create_first_topic_button.tr(),
            variant: AppButtonVariant.cream,
            size: AppButtonSize.lg,
            isFullWidth: true,
            onPressed: () async {
              AppHaptics.capture();
              await getIt<CompleteOnboardingUsecase>()(
                const NoParams(),
              );
              if (context.mounted) {
                context.go('/topics/new');
              }
            },
          ),
          const SizedBox(height: Spacing.s3),
          // Ghost reads on the navy canvas and ranks below Create.
          AppButton(
            label: LocaleKeys.onboarding_connect_celebration_finish.tr(),
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.lg,
            isFullWidth: true,
            onPressed: () async {
              AppHaptics.capture();
              await getIt<CompleteOnboardingUsecase>()(
                const NoParams(),
              );
              if (context.mounted) {
                context.go('/');
              }
            },
          ),
        ],
      },
      // 12px from the scaffold makes 24 above the home indicator.
      const SizedBox(height: 12),
    ];
  }

  List<Widget> _incidentExits(
    BuildContext context, {
    required AlarmAcknowledgedLook look,
    required bool isClosed,
    required bool pinsHint,
  }) {
    return [
      // At most two buttons. Back to topics is the way out and is
      // always the paper one at the bottom. Above it, while the
      // desk timer runs, sits At my desk. The way to the topic is
      // the pill under the title, in both states and only there.
      if (!isClosed) ...[
        if (pinsHint) ...[
          _sub(look, TextAlign.center, _deskTimerHint(context)),
          const SizedBox(height: Spacing.s3),
        ],
        AppButton(
          label: LocaleKeys.critical_alarm_at_my_desk_button.tr(),
          variant: AppButtonVariant.ghost,
          isFullWidth: true,
          onPressed: () {
            AppHaptics.capture();
            final onAtMyDesk = this.onAtMyDesk;
            if (onAtMyDesk != null) {
              onAtMyDesk();
              return;
            }
            unawaited(
              context.read<CriticalAlarmCubit>().closeIncident(),
            );
          },
        ),
        const SizedBox(height: Spacing.s2),
      ],
      AppButton(
        label: LocaleKeys.critical_alarm_back_to_topics_button.tr(),
        variant: AppButtonVariant.paper,
        isFullWidth: true,
        onPressed: () {
          AppHaptics.capture();
          context.go('/');
        },
      ),
    ];
  }
}

/// Continue, on the acknowledged screen of a setup test.
///
/// It finishes the real ring step and lets the flow decide what comes next.
/// It never completes setup itself: the flow engine does, when no step is
/// left.
class _ContinueSetupButton extends StatefulWidget {
  const _ContinueSetupButton({
    required this.setupTest,
    required this.incidentId,
  });

  final SetupTestKind setupTest;

  /// The test this button was drawn for.
  final String incidentId;

  @override
  State<_ContinueSetupButton> createState() => _ContinueSetupButtonState();
}

class _ContinueSetupButtonState extends State<_ContinueSetupButton> {
  bool _isBusy = false;

  Future<void> _continue() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    AppHaptics.capture();
    final cubit = context.read<CriticalAlarmCubit>();
    // The server-sent test is a real incident. Acknowledged and left open,
    // its desk timer would ring the phone again later as a real alarm, so
    // every test of this run is closed. The cubit does that only for the
    // test this button was drawn for, and says whether that test is still
    // what the screen shows afterwards.
    final mayContinue = widget.setupTest == SetupTestKind.serverSent
        ? await cubit.closeSetupTests(widget.incidentId)
        : cubit.state.incident?.id == widget.incidentId;
    if (!mounted) return;
    // A real alarm took the screen over. Setup waits; the alarm does not.
    if (mayContinue) {
      await finishOnboardingStep(context, OnboardingStepId.realRing);
    }
    if (mounted) setState(() => _isBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: LocaleKeys.onboarding_welcome_continue.tr(),
      variant: AppButtonVariant.cream,
      size: AppButtonSize.lg,
      isFullWidth: true,
      isLoading: _isBusy,
      onPressed: _continue,
    );
  }
}

/// The one button on the acknowledged screen of the alarm the user's own
/// tool set off from the last setup step.
///
/// Setup is already complete by then: the hook-up step finished it before
/// it handed over to the alarm. So this ends that one incident, which would
/// otherwise ring again from its desk timer, and goes Home.
class _FinishFirstToolButton extends StatefulWidget {
  const _FinishFirstToolButton({required this.incidentId});

  /// The alarm this button was drawn for.
  final String incidentId;

  @override
  State<_FinishFirstToolButton> createState() => _FinishFirstToolButtonState();
}

class _FinishFirstToolButtonState extends State<_FinishFirstToolButton> {
  bool _isBusy = false;

  Future<void> _finish() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    AppHaptics.capture();
    final router = GoRouter.of(context);
    final cubit = context.read<CriticalAlarmCubit>();
    try {
      final mayLeave = await cubit.finishFirstToolAlarm(widget.incidentId);
      // Another alarm took the screen over, or this stopped being the
      // first tool alarm. The screen stays and shows what it now is.
      if (mayLeave) router.go('/');
    } finally {
      // Whatever happened, the one button is never left spinning.
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: LocaleKeys.onboarding_connect_celebration_finish.tr(),
      variant: AppButtonVariant.cream,
      size: AppButtonSize.lg,
      isFullWidth: true,
      isLoading: _isBusy,
      onPressed: _finish,
    );
  }
}
