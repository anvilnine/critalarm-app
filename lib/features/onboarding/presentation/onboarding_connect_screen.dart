import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/domain/connect/connect_privacy_line.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_connect_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_connect_state.dart';
import 'package:critalarm/features/onboarding/presentation/model/onboarding_ambient_profiles.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_navigation.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_shell.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_welcome_screen.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/local_test_alarm_views.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Which of the two setup steps in this file a route shows.
enum OnboardingConnectPart {
  /// Pick Crit Alarm Cloud or your own server. Done once a server answers.
  connect,

  /// Connected, ready to run the local test alarm.
  test,
}

/// Two setup steps, each on its own route: the server connection
/// (/onboarding/connect) and the local test alarm of the first shipped
/// order (/onboarding/test), which Health also opens on its own.
class OnboardingConnectScreen extends StatelessWidget {
  const OnboardingConnectScreen({
    this.part = OnboardingConnectPart.connect,
    super.key,
  });

  final OnboardingConnectPart part;

  @override
  Widget build(BuildContext context) {
    final isTest = part == OnboardingConnectPart.test;
    final isReplay = isOnboardingReplay(context);
    return BlocProvider(
      create: (_) {
        final cubit = getIt<OnboardingConnectCubit>(param1: isTest);
        // A replay of the connect step is a look at the form, so a server
        // that is already saved does not move it on.
        unawaited(
          cubit.loadConnection(
            adoptSavedConnection: isTest || !isReplay,
            isReplay: isReplay,
          ),
        );
        return cubit;
      },
      child: _OnboardingConnectView(isTest: isTest, isReplay: isReplay),
    );
  }
}

class _OnboardingConnectView extends StatefulWidget {
  const _OnboardingConnectView({required this.isTest, required this.isReplay});

  final bool isTest;

  /// Opened from Settings to look at the screens. Nothing is saved, so the
  /// connect buttons move on without connecting.
  final bool isReplay;

  @override
  State<_OnboardingConnectView> createState() => _OnboardingConnectViewState();
}

class _OnboardingConnectViewState extends State<_OnboardingConnectView>
    with WidgetsBindingObserver {
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;

  /// The face every setup step shares, so it flies between them and stays
  /// put from the form to the check to the answer.
  static const _faceHeroTag = 'onboarding-face';
  static const double _faceSize = 80;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final cubit = context.read<OnboardingConnectCubit>();
    _urlController = TextEditingController(text: cubit.state.serverUrl);
    _tokenController = TextEditingController(text: cubit.state.adminToken);
    unawaited(_checkConnectivity());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncAmbientStep();
    });
  }

  void _syncAmbientStep() {
    final cubit = context.read<OnboardingConnectCubit>();
    final ambient = OnboardingAmbientScope.maybeOf(context);
    if (ambient == null) return;
    if (!widget.isTest) {
      ambient.setStep(OnboardingAmbientStep.connect);
    } else if (cubit.state.isCountingDown) {
      ambient.setStep(OnboardingAmbientStep.countdown);
    } else {
      ambient.setStep(OnboardingAmbientStep.connected);
    }
  }

  /// Coming back to the app is the usual moment someone has just turned wifi
  /// back on, so look again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    unawaited(_checkConnectivity());
  }

  Timer? _connectivityRetryTimer;

  /// Asks Crit Alarm Cloud for its `/v1/info`. The one answer says whether
  /// the phone is online and which privacy line is true. Never blocks
  /// anything.
  Future<void> _checkConnectivity() async {
    _connectivityRetryTimer?.cancel();
    // The test step shows neither the offline card nor the line.
    if (widget.isTest) return;
    final cubit = context.read<OnboardingConnectCubit>();
    await cubit.probeCloud();
    if (!mounted) return;
    if (cubit.state.cloudOnline == false) {
      _connectivityRetryTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) unawaited(_checkConnectivity());
      });
    }
  }

  @override
  void dispose() {
    _connectivityRetryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  bool _connectStepFinished = false;

  void _finishConnectStep() {
    if (_connectStepFinished) return;
    _connectStepFinished = true;
    unawaited(finishOnboardingStep(context, OnboardingStepId.connect));
  }

  /// Continue with Crit Alarm Cloud. The connect is handed over to run
  /// behind the user and the step is done at once, online or not.
  ///
  /// Opened on its own after setup, from Home or Server settings, there is
  /// no next step: the screen waits with the user and closes when the
  /// connect lands, so whatever opened it reads the new connection.
  Future<void> _continueWithCloud() async {
    final opensOnItsOwn = context.canPop();
    await context.read<OnboardingConnectCubit>().connectToCloud(
      waitForResult: opensOnItsOwn,
    );
    if (mounted && !opensOnItsOwn) _finishConnectStep();
  }

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      _tokenController.text = text;
      if (mounted) {
        context.read<OnboardingConnectCubit>().pasteToken(text);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OnboardingConnectCubit, OnboardingConnectState>(
      listenWhen: (prev, curr) =>
          prev.testAlarmStatus != curr.testAlarmStatus && curr.isAlarmFailure,
      listener: (context, state) =>
          unawaited(explainLocalTestAlarmFailure(context, state.alarm)),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return BlocConsumer<OnboardingConnectCubit, OnboardingConnectState>(
      listenWhen: (prev, curr) =>
          (!prev.canNavigateToHome && curr.canNavigateToHome) ||
          (!prev.canLaunchDemoAlarm && curr.canLaunchDemoAlarm) ||
          prev.isConnected != curr.isConnected ||
          prev.isCountingDown != curr.isCountingDown,
      listener: (context, state) {
        final cubit = context.read<OnboardingConnectCubit>();
        if (state.canNavigateToHome) {
          cubit.navigationHandled();
          context.go('/');
          return;
        } else if (state.canLaunchDemoAlarm && widget.isTest) {
          cubit.demoAlarmHandled();
          // The demo alarm is a step forward in onboarding, not a detour, so
          // it replaces this screen. Pushing left it swipe-back-able into a
          // test the user has already run.
          context.go('/incidents/inc_demo');
          return;
        }
        if (!widget.isTest) {
          // A server answered, so this step is done. The flow says what
          // comes next; this screen no longer turns into the test. A server
          // the user typed by hand first shows that it worked, and waits
          // for Continue.
          if (state.isConnected && state.confirmation == null) {
            _finishConnectStep();
          }
          return;
        }
        final ambient = OnboardingAmbientScope.maybeOf(context);
        if (ambient != null) {
          if (state.isCountingDown) {
            ambient.setStep(
              OnboardingAmbientStep.countdown,
              AmbientDirection.push,
            );
          } else {
            ambient.setStep(OnboardingAmbientStep.connected);
          }
        }
      },
      builder: (context, state) {
        final cubit = context.read<OnboardingConnectCubit>();

        // connectToCloud writes the cloud URL into state. Without this the
        // field still showed whatever the user had typed, and the next tap
        // silently connected somewhere else.
        if (_urlController.text != state.serverUrl) {
          _urlController.text = state.serverUrl;
        }
        if (_tokenController.text != state.adminToken) {
          _tokenController.text = state.adminToken;
        }

        final isTest = widget.isTest;
        final bottomAligned = !isTest && !state.isSelfHosting;

        // What the pinned bar takes off the bottom of the viewport: its own
        // buttons, the 12 the scaffold puts under them, and the home
        // indicator. AppButton is lg 60, md 48, sm 36.
        final barButtons = switch (state) {
          _ when isTest && state.isCountingDown => 48.0,
          // lg + Spacing.s3 + sm, on both the connected bar and the
          // self-hosted form's Connect + "use the cloud instead" pair.
          _ when isTest || state.isSelfHosting => 60.0 + 12 + 36,
          // The cloud bar is the self-host toggle plus the text button.
          _ => 36.0 + 4 + 36,
        };
        final bottomBarHeight =
            barButtons + 12 + MediaQuery.paddingOf(context).bottom;

        return AppScreenScaffold(
          physics: bottomAligned ? const NeverScrollableScrollPhysics() : null,
          backgroundColor: Colors.transparent,
          withGhosts: false,
          withFades: false,
          hasTabBar: false,
          resizeForKeyboard: true,
          topBar: AppTopBar(
            title: LocaleKeys.app_title.tr(),
            // Onboarding moves forward only. Opened from Settings the screen
            // sits on top of it, and Back returns there.
            leading: context.canPop()
                ? AppIconButton(
                    glyph: GlyphType.back,
                    ariaLabel: LocaleKeys.common_back.tr(),
                    onPressed: context.pop,
                  )
                : null,
          ),
          bottomBar: isTest
              ? _buildHookBottomBar(context, state, cubit)
              : _buildConnectBottomBar(context, state, cubit),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.s5,
                Spacing.s4,
                Spacing.s5,
                0,
              ),
              // The scaffold leaves room for the pinned bar under the list,
              // but SliverFillRemaining measures itself against the whole
              // viewport and ignores anything that comes after it, so the
              // bottom aligned state carries that room on its own child.
              //
              // The cloud card fills the viewport so it can sit at the bottom,
              // within thumb reach, and still scroll once the content outgrows
              // it. The other two states run top down as usual.
              sliver: bottomAligned
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: bottomBarHeight + 12),
                        child: _buildConnectOptions(context, state, cubit),
                      ),
                    )
                  : SliverToBoxAdapter(
                      child: isTest
                          ? _buildHookTestState(context, state, cubit)
                          : _buildConnectOptions(context, state, cubit),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConnectOptions(
    BuildContext context,
    OnboardingConnectState state,
    OnboardingConnectCubit cubit,
  ) {
    final colors = context.appColors;
    final errorMsg = state.errorMessage;

    final confirmation = state.confirmation;
    if (confirmation != null) {
      return _buildSelfHostConfirmation(context, confirmation);
    }
    if (state.isSelfHosting && state.isConnecting) {
      // The address is being checked. The face waits with the user and one
      // line says what is going on.
      return Center(
        child: AppWaitingFace(
          message: LocaleKeys.onboarding_connect_self_host_connecting.tr(
            namedArgs: {'host': cubit.typedHost},
          ),
          faceSize: _faceSize,
          heroTag: _faceHeroTag,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.isSelfHosting)
          // The form is a task screen like the steps after it: the face
          // waits for an address, over the one title.
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Hero(
                  tag: _faceHeroTag,
                  flightShuttleBuilder: faceFlightShuttleBuilder,
                  child: FaceWidget(
                    state: FaceState.thinking,
                    size: _faceSize,
                    isLive: true,
                  ),
                ),
                const SizedBox(height: Spacing.s4),
                Text(
                  LocaleKeys.onboarding_connect_self_host_title.tr(),
                  textAlign: TextAlign.center,
                  style: AppTypography.headline(colors.onCanvas, fontSize: 30),
                ),
              ],
            ),
          )
        else
          // The two buttons below say the rest.
          Text(
            LocaleKeys.onboarding_connect_title.tr(),
            style: AppTypography.display(colors.onCanvas, fontSize: 32),
          ),

        // Everything above sits at the top; the card drops to the bottom,
        // with the face centered in the middle area.
        if (!state.isSelfHosting) ...[
          const SizedBox(height: Spacing.s4),
          const Expanded(
            child: OnboardingAnimationLoop(
              loop: [
                WelcomeVariant.pipeline,
                WelcomeVariant.parade,
                WelcomeVariant.orbit,
              ],
            ),
          ),
          const SizedBox(height: Spacing.s4),
        ] else
          const SizedBox(height: Spacing.s5),

        // Says why a tap is about to fail, without stopping the user taking
        // it. Onboarding never blocks on the network.
        if (state.cloudOnline == false) ...[
          AppToast(
            key: const ValueKey('connect-offline-toast'),
            faceState: FaceState.concerned,
            message: LocaleKeys.onboarding_connect_offline_notice.tr(),
          ),
          const SizedBox(height: Spacing.s4),
        ],

        if (errorMsg != null) ...[
          AppToast(
            key: const ValueKey('connect-error-toast'),
            faceState: FaceState.worried,
            message: errorMsg,
          ),
          const SizedBox(height: Spacing.s4),
        ],

        if (!state.isSelfHosting) ...[
          // Default: Crit Alarm Cloud primary card
          AppSheet(
            color: colors.surface.withValues(alpha: 0.88),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        LocaleKeys.onboarding_connect_cloud_title.tr(),
                        style: TextStyle(
                          fontFamily: AppTypography.fontDisplay,
                          fontFamilyFallback:
                              AppTypography.fontDisplayFallbacks,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: colors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AppBadge(
                      text: LocaleKeys.onboarding_connect_cloud_badge.tr(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  LocaleKeys.onboarding_connect_cloud_description.tr(),
                  style: AppTypography.body(colors.ink2, fontSize: 14),
                ),
                const SizedBox(height: 16),
                if (state.isConnecting)
                  // Only when the screen was opened on its own: it waits
                  // here, with the face and one line, until the connect
                  // lands.
                  Center(
                    child: AppWaitingFace(
                      message: state.cloudWaitLine ?? '',
                      faceSize: 56,
                    ),
                  )
                else
                  AppButton(
                    label: LocaleKeys.onboarding_connect_cloud_button.tr(),
                    size: AppButtonSize.lg,
                    isFullWidth: true,
                    onPressed: widget.isReplay
                        ? _finishConnectStep
                        : _continueWithCloud,
                  ),
                // What the push relay sees, in the words the Cloud's own
                // answer supports, as the small print of the choice it
                // belongs to. Its room is kept, so the card does not jump
                // when the answer arrives.
                _PrivacyLine(line: state.cloudPrivacyLine),
              ],
            ),
          ),
        ] else ...[
          // Advanced self-hosted form
          AppTextField(
            label: LocaleKeys.onboarding_connect_url_label.tr(),
            controller: _urlController,
            placeholder: 'https://api.critalarm.app',
            errorText: state.serverUrlError,
            // A long address wraps onto a second line rather than scrolling
            // out of sight, so the user can check what they typed.
            growToFit: true,
            onChanged: cubit.serverUrlChanged,
            onSubmitted: (_) =>
                widget.isReplay ? _finishConnectStep() : cubit.connect(),
          ),
          const SizedBox(height: Spacing.s4),

          Row(
            children: [
              Expanded(
                child: Text(
                  LocaleKeys.onboarding_connect_admin_token_label.tr(),
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.small(colors.onCanvas).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              AppButton(
                label: LocaleKeys.onboarding_connect_paste_button.tr(),
                size: AppButtonSize.sm,
                variant: AppButtonVariant.paper,
                icon: AppGlyph(GlyphType.copy, size: 13, color: colors.ink),
                onPressed: _handlePaste,
              ),
            ],
          ),
          const SizedBox(height: 6),
          AppTextField(
            controller: _tokenController,
            placeholder: LocaleKeys.onboarding_connect_admin_token_placeholder
                .tr(),
            helperText: LocaleKeys.onboarding_connect_admin_token_helper.tr(),
            errorText: state.adminTokenError,
            growToFit: true,
            onChanged: cubit.adminTokenChanged,
            onSubmitted: (_) =>
                widget.isReplay ? _finishConnectStep() : cubit.connect(),
          ),
        ],
      ],
    );
  }

  /// The user's own server answered: its host, the privacy line its answer
  /// supports, and nothing else. Continue is in the pinned bar.
  Widget _buildSelfHostConfirmation(
    BuildContext context,
    ConnectConfirmation confirmation,
  ) {
    final colors = context.appColors;
    final line = confirmation.privacyLine;
    final connected = LocaleKeys.onboarding_connect_self_host_connected_title
        .tr();
    return Column(
      children: [
        const Hero(
          tag: _faceHeroTag,
          flightShuttleBuilder: faceFlightShuttleBuilder,
          child: FaceWidget(
            state: FaceState.success,
            size: _faceSize,
            isLive: true,
          ),
        ),
        const SizedBox(height: Spacing.s4),
        Semantics(
          liveRegion: true,
          // Read as one: "Connected, alerts.example.com".
          label: '$connected, ${confirmation.host}',
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  connected,
                  textAlign: TextAlign.center,
                  style: AppTypography.headline(colors.onCanvas, fontSize: 30),
                ),
                const SizedBox(height: Spacing.s2),
                // A host is a machine string, so it is set in mono.
                Text(
                  confirmation.host,
                  textAlign: TextAlign.center,
                  style: AppTypography.mono(colors.onCanvas, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
        if (line != null) ...[
          const SizedBox(height: Spacing.s4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Text(
              line.translationKey.tr(),
              textAlign: TextAlign.center,
              style: AppTypography.body(colors.onCanvasMuted, fontSize: 15),
            ),
          ),
        ],
      ],
    );
  }

  /// Pinned actions for the not-yet-connected states.
  Widget _buildConnectBottomBar(
    BuildContext context,
    OnboardingConnectState state,
    OnboardingConnectCubit cubit,
  ) {
    final colors = context.appColors;
    if (state.confirmation != null) {
      return AppButton(
        label: LocaleKeys.onboarding_connect_self_host_continue.tr(),
        size: AppButtonSize.lg,
        isFullWidth: true,
        onPressed: _finishConnectStep,
      );
    }
    // No server has answered yet, so offer the way out. Without it a user who
    // is offline or has the address wrong has no forward exit and no back.
    final skipButton = TextButton(
      onPressed: () => unawaited(
        cubit.navigateToHome(isReplay: widget.isReplay),
      ),
      style: TextButton.styleFrom(
        minimumSize: const Size(double.infinity, 36),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        LocaleKeys.onboarding_connect_skip_for_now.tr(),
        style: TextStyle(
          fontFamily: AppTypography.fontBody,
          fontFamilyFallback: AppTypography.fontBodyFallbacks,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: colors.onCanvas,
        ),
      ),
    );

    if (!state.isSelfHosting) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.s5),
            child: AppButton(
              label: LocaleKeys.onboarding_connect_self_host_toggle.tr(),
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.sm,
              isFullWidth: true,
              onPressed: cubit.toggleSelfHosting,
            ),
          ),
          const SizedBox(height: Spacing.s1),
          skipButton,
        ],
      );
    }

    // While the address is being checked the face and its line carry the
    // wait, so the bar only keeps the way out.
    if (state.isConnecting) return skipButton;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppButton(
          label: LocaleKeys.onboarding_connect_connect_button.tr(),
          size: AppButtonSize.lg,
          isFullWidth: true,
          onPressed: widget.isReplay ? _finishConnectStep : cubit.connect,
        ),
        const SizedBox(height: Spacing.s3),
        AppButton(
          label: LocaleKeys.onboarding_connect_self_host_hide.tr(),
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.sm,
          isFullWidth: true,
          onPressed: cubit.toggleSelfHosting,
        ),
      ],
    );
  }

  Widget _buildHookTestState(
    BuildContext context,
    OnboardingConnectState state,
    OnboardingConnectCubit cubit,
  ) {
    final colors = context.appColors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: AppBadge(
            text: LocaleKeys.onboarding_connect_connected_status.tr(
              namedArgs: {'serverUrl': state.serverUrl},
            ),
          ),
        ),
        const SizedBox(height: Spacing.s5),

        Hero(
          tag: _faceHeroTag,
          flightShuttleBuilder: faceFlightShuttleBuilder,
          child: FaceWidget(
            state: state.isCountingDown ? FaceState.alarmed : FaceState.cheeky,
            size: _faceSize,
            isLive: true,
          ),
        ),
        const SizedBox(height: Spacing.s4),

        Text(
          LocaleKeys.onboarding_connect_hook_title.tr(),
          textAlign: TextAlign.center,
          style: AppTypography.headline(colors.onCanvas, fontSize: 30),
        ),
        const SizedBox(height: Spacing.s2),
        // An iPhone older than iOS 26 has no AlarmKit, so the test must not
        // ask it to ring through silent mode.
        Text(
          RingClaim.forPhone(state.alarm) == RingClaim.timeSensitive
              ? LocaleKeys.onboarding_connect_hook_subtitle_time_sensitive.tr()
              : LocaleKeys.onboarding_connect_hook_subtitle.tr(),
          textAlign: TextAlign.center,
          style: AppTypography.body(colors.onCanvasMuted),
        ),
        const SizedBox(height: Spacing.s5),

        if (state.isCountingDown) ...[
          LocalTestCountdownCard(
            seconds: state.countdownSeconds,
            line: LocaleKeys.onboarding_connect_hook_countdown.tr(),
            semanticLabel: LocaleKeys.onboarding_connect_hook_countdown_aria.tr(
              namedArgs: {'seconds': '${state.countdownSeconds}'},
            ),
          ),
        ] else ...[
          // 3-Step Challenge Box
          AppSheet(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppStepBullet(
                  number: 1,
                  text:
                      RingClaim.forPhone(state.alarm) == RingClaim.timeSensitive
                      ? LocaleKeys.onboarding_connect_hook_step1_time_sensitive
                            .tr()
                      : LocaleKeys.onboarding_connect_hook_step1.tr(),
                ),
                const SizedBox(height: 12),
                AppStepBullet(
                  number: 2,
                  text: LocaleKeys.onboarding_connect_hook_step2.tr(),
                ),
                const SizedBox(height: 12),
                AppStepBullet(
                  number: 3,
                  text: LocaleKeys.onboarding_connect_hook_step3.tr(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHookBottomBar(
    BuildContext context,
    OnboardingConnectState state,
    OnboardingConnectCubit cubit,
  ) {
    if (state.isCountingDown) {
      return AppButton(
        label: LocaleKeys.onboarding_connect_hook_cancel.tr(),
        variant: AppButtonVariant.ghost,
        isFullWidth: true,
        onPressed: cubit.cancelCountdown,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppButton(
          label: LocaleKeys.onboarding_connect_hook_button.tr(),
          size: AppButtonSize.lg,
          isFullWidth: true,
          isLoading: state.isCountingDown,
          onPressed: cubit.startLocalTestAlarm,
        ),
        const SizedBox(height: Spacing.s3),
        AppButton(
          label: LocaleKeys.onboarding_connect_dashboard_button.tr(),
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.sm,
          isFullWidth: true,
          onPressed: () => unawaited(
            cubit.navigateToHome(isReplay: widget.isReplay),
          ),
        ),
        // 12px from the scaffold makes 24 above the home indicator.
        const SizedBox(height: 12),
      ],
    );
  }
}

/// The privacy line inside the Crit Alarm Cloud card, under its button.
///
/// Its room is kept while [line] is null, so the card holds its height and
/// the line fades in where it will sit. Two lines of the small print fit the
/// usual variant. A longer one grows the card.
class _PrivacyLine extends StatelessWidget {
  const _PrivacyLine({required this.line});

  final ConnectPrivacyLine? line;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final current = line;
    final style = AppTypography.small(colors.ink3, fontSize: 12);
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.s3),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.textScalerOf(context).scale(12) * 1.5 * 2,
        ),
        child: AnimatedSwitcher(
          duration: context.motion(AppDurations.base),
          switchInCurve: AppCurves.easeOut,
          switchOutCurve: AppCurves.easeOut,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topLeft,
            children: [...previous, ?current],
          ),
          child: current == null
              ? const SizedBox(
                  key: ValueKey('connect-privacy-none'),
                  width: double.infinity,
                )
              : Text(
                  current.translationKey.tr(),
                  key: ValueKey(current),
                  style: style,
                ),
        ),
      ),
    );
  }
}
