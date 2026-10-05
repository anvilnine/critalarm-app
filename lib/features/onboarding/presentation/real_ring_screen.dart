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
import 'package:critalarm/features/onboarding/presentation/widgets/curl_terminal.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/local_test_alarm_views.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/setup_problem_card.dart';
import 'package:critalarm/features/topics/domain/curl_line.dart';
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
  static const _sendCountdownName = 'send_countdown';

  /// Every state a developer build can open a replay on: each phase the
  /// step can rest on, and the countdown of the phone-only test.
  static final List<String> replayStateNames = List.unmodifiable([
    for (final phase in RealRingPhase.values)
      if (phase != RealRingPhase.rang) phase.name,
    _sendCountdownName,
    _countdownName,
  ]);

  /// The state a developer build shows on a replay, from the query
  /// parameter. Null in a store build and for a name that is not a state.
  static ({RealRingPhase phase, bool isCountingDown, bool isSendCountingDown})?
  _shown(Uri uri) {
    if (!buildHasOnboardingDeveloperTools) return null;
    final name = uri.queryParameters[replayStateParam];
    if (name == null || !replayStateNames.contains(name)) return null;
    if (name == _countdownName || name == _sendCountdownName) {
      return (
        phase: RealRingPhase.ready,
        isCountingDown: name == _countdownName,
        isSendCountingDown: name == _sendCountdownName,
      );
    }
    return (
      phase: RealRingPhase.values.byName(name),
      isCountingDown: false,
      isSendCountingDown: false,
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
              isSendCountingDown: shown.isSendCountingDown,
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
  ///
  /// Leaving it while the wait before the send runs is the user locking
  /// the phone, which is what the wait is for. `hidden` and `paused` are a
  /// real leave. `inactive` is not: a pulled-down shade or the app switcher
  /// is not the phone being put away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final cubit = context.read<RealRingCubit>();
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(cubit.appResumed());
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        cubit.appLeftFront();
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
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
    final isCounting = state.local.isCountingDown || state.isSendCountingDown;
    OnboardingAmbientScope.maybeOf(context)?.setStep(
      isCounting
          ? OnboardingAmbientStep.countdown
          : OnboardingAmbientStep.connected,
      isCounting ? AmbientDirection.push : null,
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
            prev.local.isCountingDown != curr.local.isCountingDown ||
            prev.isSendCountingDown != curr.isSendCountingDown,
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
      : state.isSendCountingDown
      ? 'send-countdown'
      : state.isWaiting || state.phase == RealRingPhase.rang
      ? 'wait'
      : state.phase.name;

  Widget _body(BuildContext context, RealRingState state, RealRingCubit cubit) {
    if (state.local.isCountingDown) return _countdown(context, state);
    if (state.isSendCountingDown) return _sendCountdown(context, state);
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
      // The wait is over: the phone is ringing, and the face says so.
      RealRingPhase.rang => _wait(
        LocaleKeys.onboarding_real_ring_rang.tr(),
        face: FaceState.alarmed,
      ),
      RealRingPhase.ready => _ready(context, state),
      RealRingPhase.criticalOff => _criticalOff(context, state, cubit),
      RealRingPhase.noServer => _noServer(context, state, cubit),
      // Missing, not broken.
      RealRingPhase.noTopic => _problem(
        cubit,
        face: FaceState.sad,
        reason: realRingNoTopicReason(),
      ),
      RealRingPhase.timedOut => _timedOut(context, state, cubit),
      RealRingPhase.failed => _problem(
        cubit,
        face: FaceState.worried,
        reason: realRingFailureLine(state.failure ?? RealRingFailure.unknown),
        actionLabel: LocaleKeys.onboarding_real_ring_try_again.tr(),
        onAction: _tryAgain(cubit),
      ),
    };
  }

  /// A wait: the face over the one line that says what for. It sits where
  /// the face of every other state does, so nothing jumps between them.
  Widget _wait(String message, {FaceState face = FaceState.watching}) => Center(
    child: AppWaitingFace(
      message: message,
      faceState: face,
      faceSize: _faceSize,
      heroTag: _faceHeroTag,
    ),
  );

  /// The face every setup step shares.
  static const _faceHeroTag = 'onboarding-face';
  static const double _faceSize = 80;

  Widget _face(FaceState face) => Hero(
    tag: _faceHeroTag,
    flightShuttleBuilder: faceFlightShuttleBuilder,
    child: FaceWidget(state: face, size: _faceSize, isLive: true),
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
    final copy = realRingCopyFor(
      state.platform,
      waitSeconds: context.read<RealRingCubit>().sendDelay.inSeconds,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // "Watch this."
        _face(FaceState.cheeky),
        const SizedBox(height: Spacing.s4),
        _heading(context, state),
        const SizedBox(height: Spacing.s5),
        AppSheet(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The numbers say "do these in order".
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

  /// What is wrong, in a short title and at most one plain line, under a
  /// face that fits it.
  Widget _reason(
    BuildContext context,
    RealRingReason reason, {
    required FaceState face,
  }) {
    final colors = context.appColors;
    final line = reason.line;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _face(face),
        const SizedBox(height: Spacing.s4),
        Semantics(
          liveRegion: true,
          container: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                reason.title,
                textAlign: TextAlign.center,
                style: AppTypography.headline(colors.onCanvas, fontSize: 22),
              ),
              if (line != null) ...[
                const SizedBox(height: Spacing.s2),
                Text(
                  line,
                  textAlign: TextAlign.center,
                  style: AppTypography.body(colors.onCanvasMuted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Try again, or the next step on a replay, which sends nothing.
  VoidCallback _tryAgain(RealRingCubit cubit) =>
      widget.isReplay ? _finishStep : () => unawaited(cubit.ringForReal());

  /// A problem: the face, then one card with what is wrong, the thing to
  /// do about it, and the test of this phone only as the quiet way on.
  Widget _problem(
    RealRingCubit cubit, {
    required FaceState face,
    required RealRingReason reason,
    String? actionLabel,
    VoidCallback? onAction,
    Widget? detail,
  }) => SetupProblemCard(
    face: face,
    title: reason.title,
    line: reason.line,
    detail: detail,
    actionLabel: actionLabel,
    onAction: onAction,
    footer: _PhoneOnlyFallback(onPressed: cubit.startPhoneOnlyTest),
  );

  Widget _noServer(
    BuildContext context,
    RealRingState state,
    RealRingCubit cubit,
  ) {
    // A connect still on its way is a wait, with its own line. A connect
    // that gave up is a failure with its reason. Anything else is a server
    // that is simply not there yet.
    final connect = state.connect;
    final fallback = _PhoneOnlyFallback(onPressed: cubit.startPhoneOnlyTest);
    if (connect.isPending) {
      return SetupProblemCard(
        face: FaceState.watching,
        line: backgroundConnectLine(connect) ?? '',
        footer: fallback,
      );
    }
    // A server that is not there is fixed on the connect step.
    final toConnect = widget.isReplay
        ? _finishStep
        : () => context.go(OnboardingEntryPoint.connectServer);
    final failedLine = connect.isFailed ? backgroundConnectLine(connect) : null;
    if (failedLine != null) {
      return _problem(
        cubit,
        face: FaceState.worried,
        // The connect gave up, so no alarm was ever asked for.
        reason: (
          title: LocaleKeys.onboarding_real_ring_connect_failed.tr(),
          line: failedLine,
        ),
        actionLabel: LocaleKeys.onboarding_connect_background_failed_button
            .tr(),
        onAction: toConnect,
      );
    }
    return _problem(
      cubit,
      face: FaceState.sad,
      reason: realRingNoServerReason(),
      actionLabel: LocaleKeys.onboarding_real_ring_no_server_button.tr(),
      onAction: toConnect,
    );
  }

  Widget _criticalOff(
    BuildContext context,
    RealRingState state,
    RealRingCubit cubit,
  ) {
    final failure = state.criticalFailure;
    final isOn = state.topic?.critical ?? false;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // "It will not ring like that", and fierce once the user flips it.
        _reason(
          context,
          (
            title: LocaleKeys.onboarding_real_ring_critical_off.tr(),
            line: null,
          ),
          face: isOn ? FaceState.determined : FaceState.skeptical,
        ),
        const SizedBox(height: Spacing.s5),
        // The switch reports the user's tap and nothing else changes it.
        FirstTopicCriticalCard(
          claim: state.claim,
          isCritical: isOn,
          plan: state.plan,
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
        AppSheet(
          child: _PhoneOnlyFallback(onPressed: cubit.startPhoneOnlyTest),
        ),
      ],
    );
  }

  Widget _timedOut(
    BuildContext context,
    RealRingState state,
    RealRingCubit cubit,
  ) {
    final copy = realRingCopyFor(state.platform);
    // Sent, and nothing happened.
    return _problem(
      cubit,
      face: FaceState.confused,
      reason: (
        title: LocaleKeys.onboarding_real_ring_timed_out.tr(),
        line: null,
      ),
      detail: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSectionHeader(
            LocaleKeys.onboarding_real_ring_check_header.tr(),
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          ),
          for (final (index, check) in copy.checks.indexed) ...[
            if (index > 0) const SizedBox(height: 12),
            AppStepBullet(number: index + 1, text: check),
          ],
        ],
      ),
      actionLabel: LocaleKeys.onboarding_real_ring_try_again.tr(),
      onAction: _tryAgain(cubit),
    );
  }

  /// The wait between the tap and the call to the server: the seconds
  /// left, what to do with them, and a terminal typing the command a tool
  /// would send. One line under it says who sends this one.
  Widget _sendCountdown(BuildContext context, RealRingState state) {
    final colors = context.appColors;
    final seconds = state.sendSecondsLeft ?? 0;
    final topic = state.topic?.name ?? '';
    final args = {'seconds': '$seconds'};
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A breath before the yell.
        Center(
          child: _face(
            seconds <= 1 ? FaceState.alarmed : FaceState.breatheIn,
          ),
        ),
        const SizedBox(height: Spacing.s4),
        Semantics(
          container: true,
          liveRegion: true,
          label: LocaleKeys.onboarding_real_ring_send_countdown_aria.tr(
            namedArgs: args,
          ),
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                LocaleKeys.onboarding_real_ring_send_countdown_title.tr(
                  namedArgs: args,
                ),
                textAlign: TextAlign.center,
                style: AppTypography.headline(colors.onCanvas, fontSize: 30),
              ),
              const SizedBox(height: Spacing.s2),
              Text(
                LocaleKeys.onboarding_real_ring_send_countdown_line.tr(),
                textAlign: TextAlign.center,
                style: AppTypography.body(colors.onCanvasMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.s5),
        // The user's own server and topic. No token is shown or held here.
        TypedCurlTerminal(
          command: CurlLine.forTerminal(
            serverUrl: state.serverUrl ?? RealRingCubit.exampleServerUrl,
            topic: topic,
            message: LocaleKeys.onboarding_real_ring_send_message.tr(),
          ),
          semanticLabel: LocaleKeys.onboarding_real_ring_send_terminal_aria.tr(
            namedArgs: {'topic': topic},
          ),
        ),
        const SizedBox(height: Spacing.s3),
        Text(
          LocaleKeys.onboarding_real_ring_send_countdown_note.tr(),
          textAlign: TextAlign.center,
          style: AppTypography.small(colors.onCanvasMuted),
        ),
      ],
    );
  }

  Widget _countdown(BuildContext context, RealRingState state) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // A breath before the yell.
      _face(
        state.local.countdownSeconds <= 1
            ? FaceState.alarmed
            : FaceState.breatheIn,
      ),
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
      LocalTestCountdownCard(
        seconds: state.local.countdownSeconds,
        line: LocaleKeys.onboarding_real_ring_countdown_line.tr(),
        semanticLabel: LocaleKeys.onboarding_real_ring_countdown_aria.tr(
          namedArgs: {'seconds': '${state.local.countdownSeconds}'},
        ),
      ),
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
        // Solid, like the way out: the body scrolls under the bar at the
        // largest text size.
        variant: AppButtonVariant.paper,
        isFullWidth: true,
        onPressed: cubit.cancelPhoneOnlyTest,
      );
    }

    if (state.isSendCountingDown) {
      return AppButton(
        label: LocaleKeys.onboarding_real_ring_send_cancel.tr(),
        variant: AppButtonVariant.paper,
        isFullWidth: true,
        // A look at the screen has no wait to cancel: it moves on.
        onPressed: widget.isReplay ? _finishStep : cubit.cancelSend,
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
      // A problem has its action in its own card. The way out stays here.
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
///
/// A button with its honest label under it, so it looks like a button and
/// not like a settings row. It sits on a card: under a problem as the quiet
/// second way on, and on its own where Critical delivery is off.
class _PhoneOnlyFallback extends StatelessWidget {
  const _PhoneOnlyFallback({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppButton(
          label: LocaleKeys.onboarding_real_ring_fallback_button.tr(),
          variant: AppButtonVariant.ghost,
          // It sits on a card, so it takes the card's ink.
          foregroundColor: colors.ink,
          isFullWidth: true,
          onPressed: () => unawaited(onPressed()),
        ),
        const SizedBox(height: Spacing.s2),
        Text(
          LocaleKeys.onboarding_real_ring_fallback_line.tr(),
          textAlign: TextAlign.center,
          style: AppTypography.small(colors.ink2),
        ),
      ],
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
