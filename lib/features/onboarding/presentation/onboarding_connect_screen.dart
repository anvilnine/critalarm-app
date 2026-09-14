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

/// Screen 2 of Onboarding (/onboarding/connect): Server Connection & Test Alarm.
///
/// Features:
/// - Server URL and Admin Token inputs with Paste button.
/// - Stubbed QR-scan button with non-blocking feedback.
/// - "Crit Alarm Cloud" hosted sign-in placeholder card.
/// - Validates via GET /v1/info and checks semver compatibility (major == 0).
/// - Stores server URL and admin token upon successful connection.
/// - Transitions to interactive "Ring me now" test state before dropping user
///   on home screen (/ or /home).
class OnboardingConnectScreen extends StatelessWidget {
  const OnboardingConnectScreen({
    this.initialConnected = false,
    super.key,
  });

  final bool initialConnected;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<OnboardingConnectCubit>(
        param1: initialConnected,
      ),
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
          !prev.canNavigateToHome && curr.canNavigateToHome,
      listener: (context, state) {
        context.read<OnboardingConnectCubit>().navigationHandled();
        context.go('/');
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
                        ? _buildRingMeNowState(context, state, cubit)
                        : _buildConnectForm(context, state, cubit),
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            // heightFactor keeps the bar as tall as its child. A plain Center
            // would expand and swallow the body above it.
            child: Align(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.s5,
                    12,
                    Spacing.s5,
                    12,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: state.isConnected
                        ? [
                            AppButton(
                              label: LocaleKeys
                                  .onboarding_connect_dashboard_button
                                  .tr(),
                              size: AppButtonSize.lg,
                              isFullWidth: true,
                              onPressed: cubit.navigateToHome,
                            ),
                            const SizedBox(height: Spacing.s3),
                            AppButton(
                              label: LocaleKeys
                                  .onboarding_connect_change_server_button
                                  .tr(),
                              variant: AppButtonVariant.ghost,
                              size: AppButtonSize.sm,
                              onPressed: cubit.editConnection,
                            ),
                          ]
                        : [
                            AppButton(
                              label: LocaleKeys
                                  .onboarding_connect_connect_button
                                  .tr(),
                              size: AppButtonSize.lg,
                              isFullWidth: true,
                              isLoading: state.isConnecting,
                              onPressed: cubit.connect,
                            ),
                          ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectForm(
    BuildContext context,
    OnboardingConnectState state,
    OnboardingConnectCubit cubit,
  ) {
    final colors = context.appColors;
    final qrNotice = state.qrNotice;
    final errorMsg = state.errorMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Brand header
        Row(
          children: [
            const FaceWidget(
              state: FaceState.calm,
              size: 34,
            ),
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

        // Headline
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            LocaleKeys.onboarding_connect_title.tr(),
            style: AppTypography.display(
              colors.onCanvas,
              fontSize: 34,
            ),
          ),
        ),
        const SizedBox(height: Spacing.s3),

        // Subtitle
        Text(
          LocaleKeys.onboarding_connect_subtitle.tr(),
          style: AppTypography.lead(
            colors.onCanvasMuted,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: Spacing.s6),

        // Server URL input
        AppTextField(
          label: LocaleKeys.onboarding_connect_url_label.tr(),
          controller: _urlController,
          placeholder: 'https://api.critalarm.app',
          helperText: LocaleKeys.onboarding_connect_url_helper.tr(),
          errorText: state.serverUrlError,
          onChanged: cubit.serverUrlChanged,
          onSubmitted: (_) => cubit.connect(),
        ),
        const SizedBox(height: Spacing.s5),

        if (state.requiresAdminToken) ...[
          // Admin Token section with Paste and Scan QR buttons
          Row(
            children: [
              Expanded(
                child: Text(
                  LocaleKeys.onboarding_connect_admin_token_label.tr(),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: AppTypography.small(colors.onCanvas).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Paste button
              AppButton(
                label: LocaleKeys.onboarding_connect_paste_button.tr(),
                size: AppButtonSize.sm,
                variant: AppButtonVariant.paper,
                icon: AppGlyph(
                  GlyphType.copy,
                  size: 13,
                  color: colors.ink,
                ),
                onPressed: _handlePaste,
              ),
              const SizedBox(width: 8),
              // Stubbed Scan QR button
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
          const SizedBox(height: Spacing.s4),
        ],

        // Non-blocking notifications / error toasts
        if (qrNotice != null) ...[
          AppToast(
            key: const ValueKey('qr-notice-toast'),
            faceState: FaceState.watching,
            message: qrNotice,
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

        // Hosted sign-in placeholder card
        AppSheet(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const FaceWidget(state: FaceState.watching, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      LocaleKeys.onboarding_connect_cloud_title.tr(),
                      style: TextStyle(
                        fontFamily: AppTypography.fontDisplay,
                        fontFamilyFallback: AppTypography.fontDisplayFallbacks,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: colors.ink,
                      ),
                    ),
                  ),
                  AppBadge(
                    text: LocaleKeys.onboarding_connect_cloud_badge.tr(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                LocaleKeys.onboarding_connect_cloud_description.tr(),
                style: AppTypography.body(colors.ink2, fontSize: 13),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: LocaleKeys.onboarding_connect_cloud_button.tr(),
                variant: AppButtonVariant.paper,
                isFullWidth: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRingMeNowState(
    BuildContext context,
    OnboardingConnectState state,
    OnboardingConnectCubit cubit,
  ) {
    final colors = context.appColors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Connection status pill badge
        Center(
          child: AppBadge(
            text: LocaleKeys.onboarding_connect_connected_status.tr(
              namedArgs: {'serverUrl': state.serverUrl},
            ),
          ),
        ),
        const SizedBox(height: Spacing.s5),

        // Alarmed face
        const FaceWidget(
          state: FaceState.alarmed,
          size: 96,
          isLive: true,
        ),
        const SizedBox(height: Spacing.s4),

        // Pill badge
        const AppBadge(
          faceState: FaceState.alarmed,
        ),
        const SizedBox(height: Spacing.s4),

        // Headline
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            LocaleKeys.onboarding_connect_ring_title.tr(),
            textAlign: TextAlign.center,
            style: AppTypography.headline(
              colors.onCanvas,
              fontSize: 32,
            ),
          ),
        ),
        const SizedBox(height: Spacing.s3),

        // Body explaining Critical Alerts
        Text(
          LocaleKeys.onboarding_connect_ring_body.tr(),
          textAlign: TextAlign.center,
          style: AppTypography.body(colors.onCanvasMuted),
        ),
        const SizedBox(height: Spacing.s6),

        // "Ring me now" test button
        AppButton(
          label: LocaleKeys.onboarding_connect_ring_button.tr(),
          variant: AppButtonVariant.ink,
          isFullWidth: true,
          isLoading: state.isRinging,
          onPressed: () => cubit.ringTestAlarm(topic: 'prod-db'),
        ),

        // Test alert toast / status feedback when rung
        if (state.isAlarmSuccess || state.isAlarmFailure) ...[
          const SizedBox(height: Spacing.s4),
          AnimatedSwitcher(
            duration: AppDurations.quick,
            child: state.isAlarmSuccess
                ? AppToast(
                    key: const ValueKey('ring-success-toast'),
                    variant: AppToastVariant.crit,
                    message: LocaleKeys.onboarding_connect_ring_toast_sent.tr(),
                    boldText: state.topic,
                    boldTextSuffix: state.incidentId != null
                        ? LocaleKeys
                              .onboarding_connect_ring_toast_ringing_with_id
                              .tr(namedArgs: {'incidentId': state.incidentId!})
                        : LocaleKeys.onboarding_connect_ring_toast_ringing.tr(),
                  )
                : AppToast(
                    key: const ValueKey('ring-error-toast'),
                    faceState: FaceState.worried,
                    message:
                        state.errorMessage ??
                        LocaleKeys.onboarding_connect_ring_toast_failed.tr(),
                  ),
          ),
        ],
      ],
    );
  }
}
