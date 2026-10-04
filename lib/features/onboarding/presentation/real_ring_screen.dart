import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/api/network_failure_message.dart';
import 'package:critalarm/core/push/push_deep_link.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/incidents/domain/setup_test_kind.dart';
import 'package:critalarm/features/onboarding/domain/flow/developer_onboarding.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/real_ring/real_ring_rules.dart';
import 'package:critalarm/features/onboarding/domain/usecases/set_up_later_usecase.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/real_ring_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/real_ring_state.dart';
import 'package:critalarm/features/onboarding/presentation/model/background_connect_copy.dart';
import 'package:critalarm/features/onboarding/presentation/model/onboarding_ambient_profiles.dart';
import 'package:critalarm/features/onboarding/presentation/model/real_ring_copy.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_navigation.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_shell.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/local_test_alarm_views.dart';
import 'package:critalarm/features/topics/presentation/widgets/first_topic_critical_card.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The real ring step: Ring me for real asks the server to send the test
/// alarm, the push carries it here, and the alarm screen takes over.
///
/// The screen draws what [RealRingCubit] decided and nothing else. Every
/// state has a way forward or a way out, and every wait shows the waiting
/// face over one line.
class RealRingScreen extends StatelessWidget {
  const RealRingScreen({super.key});

  /// The query parameter that names the state a replay opens on. Read in a
  /// developer build only.
  static const replayStateParam = 'show';

  static const _countdownName = 'countdown';

  /// Every state a developer build can open a replay on: each phase the
  /// step can rest on, and the countdown of the phone-only test.
  static final List<String> replayStateNames = List.unmodifiable([
    for (final phase in RealRingPhase.values)
      if (phase != RealRingPhase.rang) phase.name,
    _countdownName,
  ]);

  /// The state a developer build shows on a replay, from the query
  /// parameter. Null in a store build and for a name that is not a state.
  static ({RealRingPhase phase, bool isCountingDown})? _shown(Uri uri) {
    if (!buildHasOnboardingDeveloperTools) return null;
    final name = uri.queryParameters[replayStateParam];
    if (name == null || !replayStateNames.contains(name)) return null;
    if (name == _countdownName) {
      return (phase: RealRingPhase.ready, isCountingDown: true);
    }
    return (
      phase: RealRingPhase.values.byName(name),
      isCountingDown: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    final isReplay = isOnboardingReplayUri(uri);
    return BlocProvider(
      create: (_) {
        final cubit = getIt<RealRingCubit>(param1: isReplay);
        final shown = _shown(uri);
        unawaited(
          cubit.load().then((_) {
            if (shown == null || cubit.isClosed) return;
            cubit.showForReplay(
              shown.phase,
              isCountingDown: shown.isCountingDown,
            );
          }),
        );
        return cubit;
      },
      child: _RealRingView(isReplay: isReplay),
    );
  }
}

class _RealRingView extends StatefulWidget {
  const _RealRingView({required this.isReplay});

  final bool isReplay;

  @override
  State<_RealRingView> createState() => _RealRingViewState();
}

class _RealRingViewState extends State<_RealRingView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back to the app is when an alarm that rang on the lock screen
  /// may have been missed, so the phone is asked again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    unawaited(context.read<RealRingCubit>().appResumed());
  }

  bool _stepFinished = false;

  /// A replay moves on from the button without sending anything.
  void _finishStep() {
    if (_stepFinished) return;
    _stepFinished = true;
    unawaited(finishOnboardingStep(context, OnboardingStepId.realRing));
  }

  /// Set this up later. Leaves setup for Home through the one exit every
  /// such button uses.
  Future<void> _setUpLater() async {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      // Opened on its own, on top of another screen: back to it.
      router.pop();
      return;
    }
    await getIt<SetUpLaterUsecase>()(isReplay: widget.isReplay);
    router.go('/');
  }

  /// Opens the alarm screen in place of this one, unless the app has
  /// already gone there by itself (a tapped notification does that).
  void _openAlarm(String incidentId) {
    final router = GoRouter.of(context);
    final here = GoRouterState.of(context).uri.path;
    if (router.routerDelegate.currentConfiguration.uri.path != here) return;
    // A step forward in setup, not a detour, so it replaces this screen.
    router.go(PushDeepLink.incidentLocation(incidentId));
  }

  void _onChanged(BuildContext context, RealRingState state) {
    final cubit = context.read<RealRingCubit>();
    if (state.local.canLaunch) {
      cubit.phoneOnlyTestLaunched();
      _openAlarm(phoneOnlyTestIncidentId);
      return;
    }
    final incidentId = state.incidentId;
    if (state.phase == RealRingPhase.rang && incidentId != null) {
      _openAlarm(incidentId);
      return;
    }
    OnboardingAmbientScope.maybeOf(context)?.setStep(
      state.local.isCountingDown
          ? OnboardingAmbientStep.countdown
          : OnboardingAmbientStep.connected,
      state.local.isCountingDown ? AmbientDirection.push : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RealRingCubit, RealRingState>(
      listenWhen: (prev, curr) =>
          prev.local.status != curr.local.status && curr.local.isFailure,
      listener: (context, state) => unawaited(
        explainLocalTestAlarmFailure(context, state.local.alarm ?? state.alarm),
      ),
      child: BlocConsumer<RealRingCubit, RealRingState>(
        listenWhen: (prev, curr) =>
            prev.phase != curr.phase ||
            prev.local.canLaunch != curr.local.canLaunch ||
            prev.local.isCountingDown != curr.local.isCountingDown,
        listener: _onChanged,
        builder: (context, state) {
          final cubit = context.read<RealRingCubit>();
          return AppScreenScaffold(
            backgroundColor: Colors.transparent,
            withGhosts: false,
            withFades: false,
            hasTabBar: false,
            topBar: AppTopBar(
              title: LocaleKeys.app_title.tr(),
              // Setup moves forward only. Opened on top of another screen,
              // Back returns there.
              leading: context.canPop()
                  ? AppIconButton(
                      glyph: GlyphType.back,
                      ariaLabel: LocaleKeys.common_back.tr(),
                      onPressed: context.pop,
                    )
                  : null,
            ),
            bottomBar: _bottomBar(context, state, cubit),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  Spacing.s5,
                  Spacing.s4,
                  Spacing.s5,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  // One motion job: the body fades from one state to the
                  // next. It is instant with animations switched off.
                  child: AnimatedSwitcher(
                    duration: context.motion(AppDurations.base),
                    switchInCurve: AppCurves.easeOut,
                    switchOutCurve: AppCurves.easeOut,
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topCenter,
                      children: [...previous, ?current],
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(_bodyKey(state)),
                      child: _body(context, state, cubit),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// What the body is showing, so the switcher fades only between states and
  /// never on a countdown tick or a switch flip.
  String _bodyKey(RealRingState state) => state.local.isCountingDown
      ? 'countdown'
      : state.isWaiting || state.phase == RealRingPhase.rang
      ? 'wait'
      : state.phase.name;

  Widget _body(BuildContext context, RealRingState state, RealRingCubit cubit) {
    if (state.local.isCountingDown) return _countdown(context, state);
    return switch (state.phase) {
      RealRingPhase.checking => _wait(
        LocaleKeys.onboarding_real_ring_checking.tr(),
      ),
      RealRingPhase.sending => _wait(
        LocaleKeys.onboarding_real_ring_sending.tr(),
      ),
      RealRingPhase.waiting => _wait(
        LocaleKeys.onboarding_real_ring_waiting.tr(),
      ),
      RealRingPhase.rang => _wait(LocaleKeys.onboarding_real_ring_rang.tr()),
      RealRingPhase.ready => _ready(context, state),
      RealRingPhase.criticalOff => _criticalOff(context, state, cubit),
      RealRingPhase.noServer => _noServer(context, state, cubit),
      RealRingPhase.noTopic => _problem(
        context,
        cubit,
        line: LocaleKeys.onboarding_real_ring_no_topic.tr(),
      ),
      RealRingPhase.timedOut => _timedOut(context, state, cubit),
      RealRingPhase.failed => _problem(
        context,
        cubit,
        line: realRingFailureLine(state.failure ?? RealRingFailure.unknown),
      ),
    };
  }

  /// A wait: the face, waiting, over the one line that says what for.
  Widget _wait(String message) => Padding(
    padding: const EdgeInsets.only(top: Spacing.s8),
    child: Center(
      child: AppWaitingFace(message: message, heroTag: 'onboarding-face'),
    ),
  );

  Widget _face(FaceState face) => Hero(
    tag: 'onboarding-face',
    flightShuttleBuilder: faceFlightShuttleBuilder,
    child: FaceWidget(state: face, size: 88, isLive: true),
  );

  Widget _heading(BuildContext context, RealRingState state) {
    final colors = context.appColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          LocaleKeys.onboarding_real_ring_title.tr(),
          textAlign: TextAlign.center,
          style: AppTypography.headline(colors.onCanvas, fontSize: 30),
        ),
        const SizedBox(height: Spacing.s2),
        // The words about silent mode come from RingClaim, so an iPhone
        // older than iOS 26 is never told it rings through it.
        Text(
          realRingSubtitle(state.claim),
          textAlign: TextAlign.center,
          style: AppTypography.body(colors.onCanvasMuted),
        ),
      ],
    );
  }

  Widget _ready(BuildContext context, RealRingState state) {
    final copy = realRingCopyFor(state.platform);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _face(FaceState.watching),
        const SizedBox(height: Spacing.s4),
        _heading(context, state),
        const SizedBox(height: Spacing.s5),
        AppSheet(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSectionHeader(
                LocaleKeys.onboarding_real_ring_steps_header.tr(),
              ),
              const SizedBox(height: 8),
              for (final (index, step) in copy.steps.indexed) ...[
                if (index > 0) const SizedBox(height: 12),
                AppStepBullet(number: index + 1, text: step),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// One line that says what is wrong, under a worried face.
  Widget _reason(BuildContext context, String line) {
    final colors = context.appColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _face(FaceState.worried),
        const SizedBox(height: Spacing.s4),
        Semantics(
          liveRegion: true,
          child: Text(
            line,
            textAlign: TextAlign.center,
            style: AppTypography.headline(colors.onCanvas, fontSize: 22),
          ),
        ),
      ],
    );
  }

  Widget _problem(
    BuildContext context,
    RealRingCubit cubit, {
    required String line,
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _reason(context, line),
      const SizedBox(height: Spacing.s5),
      _PhoneOnlyFallback(onPressed: cubit.startPhoneOnlyTest),
    ],
  );

  Widget _noServer(
    BuildContext context,
    RealRingState state,
    RealRingCubit cubit,
  ) {
    // A connect still on its way is a wait, with its own line. Anything
    // else is a server that is not there.
    final connect = state.connect;
    final top = connect.isPending
        ? AppWaitingFace(
            message: backgroundConnectLine(connect) ?? '',
            heroTag: 'onboarding-face',
          )
        : _reason(
            context,
            connect.isFailed
                ? backgroundConnectLine(connect) ??
                      LocaleKeys.onboarding_real_ring_no_server.tr()
                : LocaleKeys.onboarding_real_ring_no_server.tr(),
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        top,
        const SizedBox(height: Spacing.s5),
        _PhoneOnlyFallback(onPressed: cubit.startPhoneOnlyTest),
      ],
    );
  }

  Widget _criticalOff(
    BuildContext context,
    RealRingState state,
    RealRingCubit cubit,
  ) {
    final failure = state.criticalFailure;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _reason(context, LocaleKeys.onboarding_real_ring_critical_off.tr()),
        const SizedBox(height: Spacing.s5),
        // The switch reports the user's tap and nothing else changes it.
        FirstTopicCriticalCard(
          claim: state.claim,
          isCritical: state.topic?.critical ?? false,
          onChanged: state.isSwitchingCritical
              ? null
              : (isOn) => unawaited(cubit.setCritical(isOn: isOn)),
        ),
        if (failure != null) ...[
          const SizedBox(height: Spacing.s3),
          AppToast(
            faceState: FaceState.worried,
            message: failureMessage(failure),
          ),
        ],
        const SizedBox(height: Spacing.s5),
        _PhoneOnlyFallback(onPressed: cubit.startPhoneOnlyTest),
      ],
    );
  }

  Widget _timedOut(
    BuildContext context,
    RealRingState state,
    RealRingCubit cubit,
  ) {
    final copy = realRingCopyFor(state.platform);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _reason(context, LocaleKeys.onboarding_real_ring_timed_out.tr()),
        const SizedBox(height: Spacing.s5),
        AppSheet(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSectionHeader(
                LocaleKeys.onboarding_real_ring_check_header.tr(),
              ),
              const SizedBox(height: 8),
              for (final (index, check) in copy.checks.indexed) ...[
                if (index > 0) const SizedBox(height: 12),
                AppStepBullet(number: index + 1, text: check),
              ],
            ],
          ),
        ),
        const SizedBox(height: Spacing.s4),
        _PhoneOnlyFallback(onPressed: cubit.startPhoneOnlyTest),
      ],
    );
  }

  Widget _countdown(BuildContext context, RealRingState state) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _face(FaceState.alarmed),
      const SizedBox(height: Spacing.s4),
      Text(
        LocaleKeys.onboarding_real_ring_fallback_button.tr(),
        textAlign: TextAlign.center,
        style: AppTypography.headline(
          context.appColors.onCanvas,
          fontSize: 30,
        ),
      ),
      const SizedBox(height: Spacing.s2),
      Text(
        LocaleKeys.onboarding_real_ring_fallback_line.tr(),
        textAlign: TextAlign.center,
        style: AppTypography.body(context.appColors.onCanvasMuted),
      ),
      const SizedBox(height: Spacing.s5),
      LocalTestCountdownCard(seconds: state.local.countdownSeconds),
    ],
  );

  Widget _bottomBar(
    BuildContext context,
    RealRingState state,
    RealRingCubit cubit,
  ) {
    if (state.local.isCountingDown) {
      return AppButton(
        label: LocaleKeys.onboarding_connect_hook_cancel.tr(),
        variant: AppButtonVariant.ghost,
        isFullWidth: true,
        onPressed: cubit.cancelPhoneOnlyTest,
      );
    }

    final later = _SetUpLaterButton(onPressed: _setUpLater);
    final Widget? primary = switch (state.phase) {
      RealRingPhase.ready => AppButton(
        label: LocaleKeys.onboarding_real_ring_button.tr(),
        size: AppButtonSize.lg,
        isFullWidth: true,
        onPressed: widget.isReplay
            ? _finishStep
            : () => unawaited(cubit.ringForReal()),
      ),
      RealRingPhase.timedOut || RealRingPhase.failed => AppButton(
        label: LocaleKeys.onboarding_real_ring_try_again.tr(),
        size: AppButtonSize.lg,
        isFullWidth: true,
        onPressed: widget.isReplay
            ? _finishStep
            : () => unawaited(cubit.ringForReal()),
      ),
      // A server that is not there is fixed on the connect step. A connect
      // still on its way needs nothing from the user.
      RealRingPhase.noServer when !state.connect.isPending => AppButton(
        label: state.connect.isFailed
            ? LocaleKeys.onboarding_connect_background_failed_button.tr()
            : LocaleKeys.onboarding_real_ring_no_server_button.tr(),
        size: AppButtonSize.lg,
        isFullWidth: true,
        onPressed: widget.isReplay
            ? _finishStep
            : () => context.go(OnboardingEntryPoint.connectServer),
      ),
      _ => null,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (primary != null) ...[primary, const SizedBox(height: Spacing.s3)],
        later,
      ],
    );
  }
}

/// The fallback: a test of this phone only, said in so many words. It runs
/// only when the user taps it.
class _PhoneOnlyFallback extends StatelessWidget {
  const _PhoneOnlyFallback({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            LocaleKeys.onboarding_real_ring_fallback_line.tr(),
            style: AppTypography.body(colors.ink2, fontSize: 14),
          ),
          const SizedBox(height: Spacing.s3),
          AppButton(
            label: LocaleKeys.onboarding_real_ring_fallback_button.tr(),
            variant: AppButtonVariant.paper,
            isFullWidth: true,
            onPressed: () => unawaited(onPressed()),
          ),
        ],
      ),
    );
  }
}

/// The way out that every state keeps.
///
/// A solid button, not bare text: at the largest text size the body scrolls
/// under the pinned bar, and words over words would be unreadable.
class _SetUpLaterButton extends StatelessWidget {
  const _SetUpLaterButton({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: LocaleKeys.onboarding_connect_skip_for_now.tr(),
      variant: AppButtonVariant.paper,
      isFullWidth: true,
      onPressed: () => unawaited(onPressed()),
    );
  }
}
