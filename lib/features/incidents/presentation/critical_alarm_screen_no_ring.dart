part of 'critical_alarm_screen.dart';

/// The note that replaces the ringing screen once the server says the
/// incident was answered on another device, or ended. The phone is already
/// quiet. Stop is the one button, because Stop is what the person came here
/// to press, and it leaves for Home.
class _HandledElsewhereView extends StatelessWidget {
  const _HandledElsewhereView({required this.state});

  final CriticalAlarmState state;

  @override
  Widget build(BuildContext context) {
    // Expired means nobody answered it: the server stopped the alarm when
    // its ring time ran out. Saying another device handled it would be false.
    final isEnded = state.incident?.isExpired ?? false;
    return AppScreenScaffold(
      hasTabBar: false,
      topBar: AppTopBar(
        title: LocaleKeys.critical_alarm_screen_title.tr(),
        leading: AppIconButton(
          glyph: GlyphType.back,
          ariaLabel: LocaleKeys.critical_alarm_back_aria_label.tr(),
          onPressed: () => context.go('/'),
        ),
      ),
      bottomBar: AppButton(
        label: LocaleKeys.incidents_handled_elsewhere_stop_button.tr(),
        isFullWidth: true,
        onPressed: () {
          AppHaptics.capture();
          final cubit = context.read<CriticalAlarmCubit>();
          final router = GoRouter.of(context);
          // A refusal means a new ring armed since the note went up: the
          // screen rings again instead of leaving.
          unawaited(
            cubit.stopHandledElsewhere().then((mayLeave) {
              if (mayLeave) router.go('/');
            }),
          );
        },
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
          sliver: SliverToBoxAdapter(
            child: AppEmptyState(
              title: isEnded
                  ? LocaleKeys.incidents_alarm_ended_title.tr()
                  : LocaleKeys.incidents_handled_elsewhere_title.tr(),
              description: isEnded
                  ? LocaleKeys.incidents_alarm_ended_body.tr()
                  : LocaleKeys.incidents_handled_elsewhere_body.tr(),
              faceState: FaceState.calm,
            ),
          ),
        ),
      ],
    );
  }
}

/// What the screen shows while there is no alarm to ring: loading, a load that
/// failed, a close handed to the native side, or nothing open. Built in the
/// builder's [context], for the same [state] the builder drew from.
Widget _noAlarmContent(BuildContext context, CriticalAlarmState state) {
  final isLoading = state.status == CriticalAlarmStatus.loading;
  // Set only when a native Done opened the screen and the server
  // gave no answer. Without it this screen is what it always was.
  final doneId = isLoading ? null : state.doneIncidentId;
  final isHandedOff = !isLoading && state.isDoneHandedOff;
  final didFail = !isLoading && (state.errorMessage != null || doneId != null);

  final emptyState = AppEmptyState(
    title: isLoading
        ? LocaleKeys.critical_alarm_loading_title.tr()
        : isHandedOff
        ? LocaleKeys.critical_alarm_close_queued_title.tr()
        : didFail
        ? LocaleKeys.critical_alarm_load_failed_title.tr()
        : LocaleKeys.critical_alarm_no_alarm_title.tr(),
    description: isHandedOff
        ? LocaleKeys.critical_alarm_close_queued_body.tr()
        : didFail
        ? LocaleKeys.critical_alarm_load_failed_body.tr()
        : isLoading
        ? ''
        : LocaleKeys.critical_alarm_no_alarm_body.tr(),
    faceState: didFail ? FaceState.worried : FaceState.calm,
    isLive: isLoading,
  );

  return AppScreenScaffold(
    hasTabBar: false,
    topBar: AppTopBar(
      title: LocaleKeys.critical_alarm_screen_title.tr(),
      leading: AppIconButton(
        glyph: GlyphType.back,
        ariaLabel: LocaleKeys.critical_alarm_back_aria_label.tr(),
        onPressed: () => context.go('/'),
      ),
    ),
    // The load failing does not stop the phone ringing, so this screen
    // keeps a way out even when it has no incident to acknowledge.
    bottomBar: isHandedOff
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(
                label: LocaleKeys.critical_alarm_back_to_topics_button.tr(),
                isFullWidth: true,
                onPressed: () {
                  AppHaptics.capture();
                  context.go('/');
                },
              ),
              const SizedBox(height: 8),
              // The phone may still be making sound, and this
              // screen has no incident to acknowledge either.
              AppButton(
                label: LocaleKeys.critical_alarm_silence_button.tr(),
                variant: AppButtonVariant.ghost,
                isFullWidth: true,
                onPressed: () {
                  AppHaptics.capture();
                  unawaited(
                    context.read<CriticalAlarmCubit>().silenceThisPhone(),
                  );
                },
              ),
            ],
          )
        : didFail
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Done on the card would have closed this with no
              // signal. It opened the app instead, so the close is
              // still one tap away, handed back to the same native
              // code.
              if (doneId != null) ...[
                AppButton(
                  label: LocaleKeys.critical_alarm_at_my_desk_button.tr(),
                  variant: AppButtonVariant.ghost,
                  isFullWidth: true,
                  onPressed: () {
                    AppHaptics.capture();
                    unawaited(
                      context.read<CriticalAlarmCubit>().handCloseToNative(),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
              AppButton(
                label: LocaleKeys.critical_alarm_retry_button.tr(),
                isFullWidth: true,
                // A try again from the screen a Done button opened
                // asks for the same incident, so one more failure
                // does not take "At my desk" away. Any other try
                // again is what it always was.
                onPressed: () => unawaited(
                  doneId == null
                      ? context.read<CriticalAlarmCubit>().load()
                      : context.read<CriticalAlarmCubit>().load(
                          incidentId: doneId,
                          cameFromDone: true,
                        ),
                ),
              ),
              const SizedBox(height: 8),
              AppButton(
                label: LocaleKeys.critical_alarm_silence_button.tr(),
                variant: AppButtonVariant.ghost,
                isFullWidth: true,
                onPressed: () {
                  AppHaptics.capture();
                  unawaited(
                    context.read<CriticalAlarmCubit>().silenceThisPhone(),
                  );
                },
              ),
            ],
          )
        : null,
    // On a half-open foldable the note holds still in the start pane
    // or the top half, off the fold, and the buttons go in the other.
    foldStage: AppFold.of(context).isNone
        ? null
        : Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
              child: emptyState,
            ),
          ),
    slivers: [
      if (AppFold.of(context).isNone)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
          sliver: SliverToBoxAdapter(
            child: emptyState,
          ),
        ),
    ],
  );
}
