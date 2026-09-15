import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_connect_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_connect_state.dart';
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

class _OnboardingConnectViewState extends State<_OnboardingConnectView> {
  late final TextEditingController _urlController;
  late final TextEditingController _tokenController;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<OnboardingConnectCubit>();
    _urlController = TextEditingController(text: cubit.state.serverUrl);
    _tokenController = TextEditingController(text: cubit.state.adminToken);
  }

  @override
  void dispose() {
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
    final colors = context.appColors;

    return BlocConsumer<OnboardingConnectCubit, OnboardingConnectState>(
      listenWhen: (prev, curr) =>
          (!prev.canNavigateToHome && curr.canNavigateToHome) ||
          (!prev.canLaunchDemoAlarm && curr.canLaunchDemoAlarm),
      listener: (context, state) {
        final cubit = context.read<OnboardingConnectCubit>();
        if (state.canNavigateToHome) {
          cubit.navigationHandled();
          context.go('/');
        } else if (state.canLaunchDemoAlarm) {
          cubit.demoAlarmHandled();
          unawaited(context.push('/incidents/inc_demo'));
        }
      },
      builder: (context, state) {
        final cubit = context.read<OnboardingConnectCubit>();

        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: colors.canvas,
          body: GhostField(
            seed: 88,
            shapeCount: 8,
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.s5,
                      Spacing.s6,
                      Spacing.s5,
                      16,
                    ),
                    child: state.isConnected
                        ? _buildHookTestState(context, state, cubit)
                        : _buildConnectOptions(context, state, cubit),
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Align(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.s5,
                    12,
                    Spacing.s5,
                    16,
                  ),
                  child: state.isConnected
                      ? _buildHookBottomBar(context, state, cubit)
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
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
        // Brand header
        Row(
          children: [
            const FaceWidget(state: FaceState.calm, size: 34),
            const SizedBox(width: Spacing.s3),
            Expanded(
              child: Text(
                LocaleKeys.app_title.tr(),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: AppTypography.fontDisplay,
                  fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.03 * 22,
                  color: colors.onCanvas,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.s6),

        Text(
          LocaleKeys.onboarding_connect_title.tr(),
          style: AppTypography.display(colors.onCanvas, fontSize: 32),
        ),
        const SizedBox(height: Spacing.s2),
        Text(
          LocaleKeys.onboarding_connect_subtitle.tr(),
          style: AppTypography.lead(colors.onCanvasMuted, fontSize: 15),
        ),
        const SizedBox(height: Spacing.s6),

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const FaceWidget(state: FaceState.calm, size: 32),
                    const SizedBox(width: 10),
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
                    const AppBadge(text: 'OFFICIAL'),
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
          const SizedBox(height: Spacing.s5),
          Center(
            child: AppButton(
              label: LocaleKeys.onboarding_connect_self_host_toggle.tr(),
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.sm,
              onPressed: cubit.toggleSelfHosting,
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
            errorText: state.adminTokenError,
            onChanged: cubit.adminTokenChanged,
            onSubmitted: (_) => cubit.connect(),
          ),
          const SizedBox(height: Spacing.s5),

          AppButton(
            label: LocaleKeys.onboarding_connect_connect_button.tr(),
            size: AppButtonSize.lg,
            isFullWidth: true,
            isLoading: state.isConnecting,
            onPressed: cubit.connect,
          ),
          const SizedBox(height: Spacing.s3),
          Center(
            child: AppButton(
              label: LocaleKeys.onboarding_connect_self_host_hide.tr(),
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.sm,
              onPressed: cubit.toggleSelfHosting,
            ),
          ),
        ],
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

        FaceWidget(
          state: state.isCountingDown
              ? FaceState.alarmed
              : FaceState.watching,
          size: 88,
          isLive: true,
        ),
        const SizedBox(height: Spacing.s4),

        Text(
          LocaleKeys.onboarding_connect_hook_title.tr(),
          textAlign: TextAlign.center,
          style: AppTypography.headline(colors.onCanvas, fontSize: 30),
        ),
        const SizedBox(height: Spacing.s2),
        Text(
          LocaleKeys.onboarding_connect_hook_subtitle.tr(),
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
                const AppSectionHeader('HOW THE TEST WORKS'),
                const SizedBox(height: 8),
                AppFeatureBullet(
                  text: LocaleKeys.onboarding_connect_hook_step1.tr(),
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
          onPressed: cubit.startLocal30sAlarm,
        ),
        const SizedBox(height: Spacing.s3),
        AppButton(
          label: LocaleKeys.onboarding_connect_dashboard_button.tr(),
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.sm,
          onPressed: cubit.navigateToHome,
        ),
      ],
    );
  }
}
