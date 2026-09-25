import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/core/alarm/ring_claim.dart';
import 'package:critalarm/core/api/network_failure_message.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_connect_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_connect_state.dart';
import 'package:critalarm/features/onboarding/presentation/model/onboarding_ambient_profiles.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_shell.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_welcome_screen.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Screen 2 of Onboarding (/onboarding/connect): Server Connection & Local Test Alarm.
class OnboardingConnectScreen extends StatelessWidget {
  const OnboardingConnectScreen({
    this.initialConnected = false,
    super.key,
  });

  final bool initialConnected;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<OnboardingConnectCubit>(param1: initialConnected);
        unawaited(cubit.loadConnection());
        return cubit;
      },
      child: const _OnboardingConnectView(),
    );
  }
}

class _OnboardingConnectView extends StatefulWidget {
  const _OnboardingConnectView();

  @override
  State<_OnboardingConnectView> createState() => _OnboardingConnectViewState();
}

class _OnboardingConnectViewState extends State<_OnboardingConnectView>
    with WidgetsBindingObserver {
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;

  /// Null until the first check answers. Never blocks anything: it is a line
  /// of text saying why the next tap may fail.
  bool? _online;

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
    if (cubit.state.isCountingDown) {
      ambient.setStep(OnboardingAmbientStep.countdown);
    } else if (cubit.state.isConnected) {
      ambient.setStep(OnboardingAmbientStep.connected);
    } else {
      ambient.setStep(OnboardingAmbientStep.connect);
    }
  }

  /// Coming back to the app is the usual moment someone has just turned wifi
  /// back on, so look again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    unawaited(_checkConnectivity());
  }

  Future<void> _checkConnectivity() async {
    final online = await hasInternet();
    if (mounted) setState(() => _online = online);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
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
        } else if (state.canLaunchDemoAlarm) {
          cubit.demoAlarmHandled();
          // The demo alarm is a step forward in onboarding, not a detour, so
          // it replaces this screen. Pushing left it swipe-back-able into a
          // test the user has already run.
          context.go('/incidents/inc_demo');
          return;
        }
        final ambient = OnboardingAmbientScope.maybeOf(context);
        if (ambient != null) {
          if (state.isCountingDown) {
            ambient.setStep(
              OnboardingAmbientStep.countdown,
              AmbientDirection.push,
            );
          } else if (state.isConnected) {
            ambient.setStep(
              OnboardingAmbientStep.connected,
              AmbientDirection.push,
            );
          } else {
            ambient.setStep(OnboardingAmbientStep.connect);
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

        final bottomAligned = !state.isConnected && !state.isSelfHosting;

        // What the pinned bar takes off the bottom of the viewport: its own
        // buttons, the 12 the scaffold puts under them, and the home
        // indicator. AppButton is lg 60, md 48, sm 36.
        final barButtons = switch (state) {
          _ when state.isConnected && state.isCountingDown => 48.0,
          // lg + Spacing.s3 + sm, on both the connected bar and the
          // self-hosted form's Connect + "use the cloud instead" pair.
          _ when state.isConnected || state.isSelfHosting => 60.0 + 12 + 36,
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
          bottomBar: state.isConnected
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
                      child: state.isConnected
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
    final qrNotice = state.qrNotice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.onboarding_connect_title.tr(),
          style: AppTypography.display(colors.onCanvas, fontSize: 32),
        ),
        const SizedBox(height: Spacing.s2),
        Text(
          LocaleKeys.onboarding_connect_subtitle.tr(),
          style: AppTypography.lead(colors.onCanvasMuted, fontSize: 15),
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
          const SizedBox(height: Spacing.s6),

        // Says why a tap is about to fail, without stopping the user taking
        // it. Onboarding never blocks on the network.
        if (_online == false) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: colors.highCanvas,
              borderRadius: Radii.lgAll,
              border: Border.all(color: colors.highStroke),
            ),
            child: Text(
              LocaleKeys.onboarding_connect_offline_notice.tr(),
              style: AppTypography.small(colors.onCanvas),
            ),
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

        if (qrNotice != null) ...[
          AppToast(
            key: const ValueKey('qr-notice-toast'),
            faceState: FaceState.watching,
            message: qrNotice,
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
                AppButton(
                  label: LocaleKeys.onboarding_connect_cloud_button.tr(),
                  size: AppButtonSize.lg,
                  isFullWidth: true,
                  isLoading: state.isConnecting,
                  onPressed: cubit.connectToCloud,
                ),
              ],
            ),
          ),
        ] else ...[
          // Advanced self-hosted form
          AppTextField(
            label: LocaleKeys.onboarding_connect_url_label.tr(),
            controller: _urlController,
            placeholder: 'https://api.critalarm.app',
            helperText: LocaleKeys.onboarding_connect_url_helper.tr(),
            errorText: state.serverUrlError,
            // A long address wraps onto a second line rather than scrolling
            // out of sight, so the user can check what they typed.
            growToFit: true,
            onChanged: cubit.serverUrlChanged,
            onSubmitted: (_) => cubit.connect(),
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
              const SizedBox(width: 8),
              Semantics(
                label: LocaleKeys.onboarding_connect_scan_qr_semantic_label
                    .tr(),
                button: true,
                child: GestureDetector(
                  onTap: cubit.scanQrTapped,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.surface,
                      border: Border.all(color: colors.onCanvas, width: 2),
                      boxShadow: AppShadows.lightSm,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 18,
                      color: colors.ink,
                    ),
                  ),
                ),
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
            onSubmitted: (_) => cubit.connect(),
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
    // No server has answered yet, so offer the way out. Without it a user who
    // is offline or has the address wrong has no forward exit and no back.
    final skipButton = TextButton(
      onPressed: cubit.navigateToHome,
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
          AppButton(
            label: LocaleKeys.onboarding_connect_self_host_toggle.tr(),
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.sm,
            isFullWidth: true,
            onPressed: cubit.toggleSelfHosting,
          ),
          const SizedBox(height: Spacing.s1),
          skipButton,
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppButton(
          label: LocaleKeys.onboarding_connect_connect_button.tr(),
          size: AppButtonSize.lg,
          isFullWidth: true,
          isLoading: state.isConnecting,
          onPressed: cubit.connect,
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
          tag: 'onboarding-face',
          flightShuttleBuilder: faceFlightShuttleBuilder,
          child: FaceWidget(
            state: state.isCountingDown
                ? FaceState.alarmed
                : FaceState.watching,
            size: 88,
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
          // Live Countdown Display
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.onCanvas, width: 2),
              boxShadow: AppShadows.lightLg,
            ),
            child: Column(
              children: [
                Text(
                  '${state.countdownSeconds}s',
                  style: TextStyle(
                    fontFamily: AppTypography.fontDisplay,
                    fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                    fontWeight: FontWeight.w800,
                    fontSize: 54,
                    letterSpacing: -2,
                    color: colors.crit,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  LocaleKeys.onboarding_connect_hook_countdown.tr(
                    namedArgs: {'seconds': '${state.countdownSeconds}'},
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTypography.fontBody,
                    fontFamilyFallback: AppTypography.fontBodyFallbacks,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: colors.ink,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // 3-Step Challenge Box
          AppSheet(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSectionHeader(
                  LocaleKeys.onboarding_connect_hook_steps_header.tr(),
                ),
                const SizedBox(height: 8),
                AppFeatureBullet(
                  text:
                      RingClaim.forPhone(state.alarm) ==
                          RingClaim.timeSensitive
                      ? LocaleKeys.onboarding_connect_hook_step1_time_sensitive
                            .tr()
                      : LocaleKeys.onboarding_connect_hook_step1.tr(),
                  glyph: GlyphType.bell,
                ),
                const SizedBox(height: 12),
                AppFeatureBullet(
                  text: LocaleKeys.onboarding_connect_hook_step2.tr(),
                  glyph: GlyphType.arrow,
                ),
                const SizedBox(height: 12),
                AppFeatureBullet(
                  text: LocaleKeys.onboarding_connect_hook_step3.tr(),
                  glyph: GlyphType.clock,
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
          onPressed: cubit.navigateToHome,
        ),
      ],
    );
  }
}
