part of 'critical_alarm_screen.dart';

extension _LiveContent on _CriticalAlarmViewState {
  /// The one place the look is applied, for both stages. The
  /// acknowledged screen stays on the acknowledged colours after At
  /// my desk closes the incident, so its text keeps the colours
  /// that read on it.
  Widget _liveContent(
    BuildContext context, {
    required CriticalAlarmState state,
    required AlarmStyle style,
    required AlarmStage stage,
  }) {
    return AlarmStyleStage(
      style: style,
      stage: stage,
      severity: state.severityMode,
      child: Builder(
        builder: (context) {
          final colors = context.appColors;
          if (state.isAcknowledged) {
            final owed = _challengeFor(state);
            final challenge = challengeOf(owed?.kind);
            if (owed != null && challenge != null) {
              return ChallengeStep(
                key: ValueKey('challenge-${state.incident?.id}'),
                challenge: challenge,
                incident: _challengeIncident(state),
                wayOut: owed.wayOut,
                onPassed: _finishChallenge,
                onSkip: _finishChallenge,
                onLeave: _leaveChallenge,
              );
            }
            return AcknowledgedScreen(
              state: state,
              colors: colors,
              onAtMyDesk: () => _atMyDesk(state),
            );
          }
          // Back is not an acknowledge. It silences the phone and sets
          // the next ring for the same incident, the same as Stop on the
          // notification does, and only then lets the person out. Back
          // used to be swallowed whole, because leaving without
          // silencing left the phone screaming with no way back.
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              final cubit = context.read<CriticalAlarmCubit>();
              final router = GoRouter.of(context);
              unawaited(cubit.silence().then((_) => router.go('/')));
            },
            child: _RingingScreenReader(
              state: state,
              ackButtonKey: _ackButtonKey,
              announces: !_didAnnounceRinging,
              onAnnounced: () => _didAnnounceRinging = true,
              child: RingingScreen(
                state: state,
                colors: colors,
                ackButtonKey: _ackButtonKey,
                onAcknowledge: () {
                  unawaited(
                    context.read<CriticalAlarmCubit>().acknowledge(),
                  );
                },
                onSilence: () {
                  AppHaptics.selection();
                  unawaited(context.read<CriticalAlarmCubit>().silence());
                },
                // Reading is not acknowledging, so this leaves the
                // alarm ringing and takes the user to the messages
                // on the topic.
                onReadMessage: state.incident == null
                    ? null
                    : () {
                        AppHaptics.selection();
                        // The topic's screen does not show over the
                        // lock screen. Back on a screen that still
                        // rings, it does again.
                        _lockHold.cover();
                        unawaited(
                          context
                              .push('/topics/${state.incident!.topic}')
                              .whenComplete(_lockHold.uncover),
                        );
                      },
                onSelectAlarm: (id) =>
                    context.read<CriticalAlarmCubit>().select(id),
              ),
            ),
          );
        },
      ),
    );
  }
}
