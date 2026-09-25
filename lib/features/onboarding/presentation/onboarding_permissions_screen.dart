import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/domain/entities/onboarding_draft.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_state.dart';
import 'package:critalarm/features/onboarding/presentation/model/onboarding_ambient_profiles.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_navigation.dart';
import 'package:critalarm/features/onboarding/presentation/onboarding_shell.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/permission_dialog_preview.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Screen 1 of Onboarding (/onboarding): Permissions.
///
/// A stepper that only shows the steps this phone actually has, and only the
/// ones the user has not already answered. Nothing here blocks: "Not now" or a
/// refused prompt moves straight to the next step, because Apple's own
/// guidance forbids holding the app hostage over one, and AlarmKit never
/// prompts twice. Home's health banner asks again later.
class OnboardingPermissionsScreen extends StatelessWidget {
  const OnboardingPermissionsScreen({
    super.key,
    this.initialStep = NotificationPermissionStep.initial,
    this.replayForDemo = false,
    this.standalone = false,
  });

  final NotificationPermissionStep initialStep;

  /// Opened from the developer menu to look at the screens. Every step shows,
  /// even the ones already granted.
  final bool replayForDemo;

  /// Opened from Health to ask for a permission the user was never asked.
  /// Not part of onboarding: it asks what is left, then closes.
  final bool standalone;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<NotificationPermissionsCubit>(
          param1: initialStep,
          param2: (replayForDemo: replayForDemo, standalone: standalone),
        );
        unawaited(cubit.refresh());
        return cubit;
      },
      child: _OnboardingPermissionsView(standalone: standalone),
    );
  }
}

class _OnboardingPermissionsView extends StatefulWidget {
  const _OnboardingPermissionsView({required this.standalone});

  final bool standalone;

  @override
  State<_OnboardingPermissionsView> createState() =>
      _OnboardingPermissionsViewState();
}

class _OnboardingPermissionsViewState extends State<_OnboardingPermissionsView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncAmbientStep();
    });
  }

  void _syncAmbientStep() {
    final cubit = context.read<NotificationPermissionsCubit>();
    final ambient = OnboardingAmbientScope.maybeOf(context);
    if (ambient == null) return;
    if (cubit.state.isDenied) {
      ambient.setStep(OnboardingAmbientStep.denied);
    } else if (cubit.state.activeSubstep == 1) {
      ambient.setStep(OnboardingAmbientStep.alarms, AmbientDirection.right);
    } else {
      ambient.setStep(OnboardingAmbientStep.notifications);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from system Settings. Re-read the answer rather than making the user
  /// find a retry button to tell the app what it can look up itself.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    unawaited(context.read<NotificationPermissionsCubit>().refresh());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isApple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    return BlocConsumer<
      NotificationPermissionsCubit,
      NotificationPermissionsState
    >(
      listenWhen: (prev, curr) =>
          (!prev.canNavigate && curr.canNavigate) ||
          prev.activeSubstep != curr.activeSubstep ||
          prev.isDenied != curr.isDenied,
      listener: (context, state) {
        if (state.canNavigate) {
          context.read<NotificationPermissionsCubit>().navigationHandled();
          if (widget.standalone) {
            _close(context);
          } else {
            goToOnboardingStep(context, OnboardingStep.widgets);
          }
          return;
        }
        final ambient = OnboardingAmbientScope.maybeOf(context);
        if (ambient != null) {
          if (state.isDenied) {
            ambient.setStep(OnboardingAmbientStep.denied);
          } else if (state.activeSubstep == 1) {
            ambient.setStep(
              OnboardingAmbientStep.alarms,
              AmbientDirection.right,
            );
          } else {
            ambient.setStep(
              OnboardingAmbientStep.notifications,
              AmbientDirection.left,
            );
          }
        }
      },
      builder: (context, state) {
        final cubit = context.read<NotificationPermissionsCubit>();
        final isStep2 = state.activeSubstep == 1;
        // Step 2 asks for an alarm permission that only iOS 26 has. Elsewhere
        // the screen says what the phone can do instead of promising a ring.
        final alarmless = isStep2 && !state.alarmSupported;
        final requestStep = isStep2
            ? cubit.requestCriticalAlerts
            : cubit.requestNotifications;

        final previewTitle = _previewTitle(isApple, isStep2);
        final previewMessage = _previewMessage(isApple, isStep2);
        final summaryLabel = LocaleKeys
            .onboarding_permissions_preview_allow_summary
            .tr();
        final previewHint = LocaleKeys.onboarding_permissions_preview_hint.tr();

        return AppScreenScaffold(
          // On its own the screen sits over Health, not over the onboarding
          // canvas, so it paints its own background.
          backgroundColor: widget.standalone ? null : Colors.transparent,
          withGhosts: false,
          withFades: false,
          hasTabBar: false,
          topBar: AppTopBar(
            title: LocaleKeys.app_title.tr(),
            leading: widget.standalone
                ? AppIconButton(
                    glyph: GlyphType.close,
                    ariaLabel: LocaleKeys.common_back.tr(),
                    onPressed: () => _close(context),
                  )
                : null,
          ),
          bottomBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: state.isDenied
                ? [
                    AppButton(
                      label: LocaleKeys
                          .onboarding_permissions_denied_open_settings
                          .tr(),
                      size: AppButtonSize.lg,
                      isFullWidth: true,
                      onPressed: cubit.openSettings,
                    ),
                    const SizedBox(height: Spacing.s3),
                    // Never a wall. A user who says no still gets into the
                    // app; the health banner keeps asking afterwards.
                    AppButton(
                      label: LocaleKeys.onboarding_permissions_denied_skip.tr(),
                      variant: AppButtonVariant.paper,
                      isFullWidth: true,
                      isLoading: state.isChecking,
                      onPressed: cubit.continueWithout,
                    ),
                  ]
                : [
                    AppButton(
                      label: _primaryLabel(isStep2, alarmless),
                      size: AppButtonSize.lg,
                      isFullWidth: true,
                      isLoading: state.isRequesting,
                      onPressed: alarmless
                          ? cubit.continueWithout
                          : requestStep,
                    ),
                    // Nothing to skip when the step only explains.
                    if (!alarmless) ...[
                      const SizedBox(height: Spacing.s3),
                      AppButton(
                        label: LocaleKeys.onboarding_permissions_not_now.tr(),
                        variant: AppButtonVariant.paper,
                        isFullWidth: true,
                        onPressed: state.isRequesting ? null : cubit.skipStep,
                      ),
                    ],
                  ],
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.s5,
                Spacing.s4,
                Spacing.s5,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: state.isDenied
                    ? AppEmptyState(
                        faceState: FaceState.worried,
                        title: LocaleKeys.onboarding_permissions_denied_title
                            .tr(),
                        description: LocaleKeys
                            .onboarding_permissions_denied_description
                            .tr(),
                        buttonLabel: null,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Hero(
                              tag: 'onboarding-face',
                              flightShuttleBuilder: faceFlightShuttleBuilder,
                              child: FaceWidget(
                                state: isStep2
                                    ? FaceState.watching
                                    : FaceState.alarmed,
                                size: 80,
                                isLive: true,
                              ),
                            ),
                          ),
                          const SizedBox(height: Spacing.s3),
                          Center(
                            child: AppBadge(
                              text: isStep2
                                  ? LocaleKeys
                                        .onboarding_permissions_badge_step2
                                        .tr()
                                  : LocaleKeys.onboarding_permissions_badge
                                        .tr(),
                              faceState: isStep2
                                  ? FaceState.watching
                                  : FaceState.alarmed,
                            ),
                          ),
                          const SizedBox(height: Spacing.s4),

                          Text(
                            _title(isStep2, alarmless),
                            style: AppTypography.display(
                              colors.onCanvas,
                              fontSize: 32,
                            ),
                          ),
                          const SizedBox(height: Spacing.s2),
                          Text(
                            _subtitle(isStep2, alarmless),
                            style: AppTypography.lead(
                              colors.onCanvasMuted,
                              fontSize: 15,
                            ),
                          ),

                          // No prompt is coming on this phone, so there is
                          // no dialog to preview.
                          if (!alarmless) ...[
                            const SizedBox(height: Spacing.s5),
                            PermissionDialogPreview(
                              title: previewTitle,
                              message: previewMessage,
                              allowLabel: LocaleKeys
                                  .onboarding_permissions_preview_allow
                                  .tr(),
                              denyLabel: LocaleKeys
                                  .onboarding_permissions_preview_dont_allow
                                  .tr(),
                              summaryLabel: isApple && !isStep2
                                  ? summaryLabel
                                  : null,
                              isCritical: isStep2,
                              semanticLabel: '$previewTitle. $previewHint',
                              onTap: state.isRequesting ? null : requestStep,
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                previewHint,
                                style: TextStyle(
                                  fontFamily: AppTypography.fontMono,
                                  fontFamilyFallback:
                                      AppTypography.fontMonoFallbacks,
                                  fontSize: 11,
                                  color: colors.onCanvasMuted,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/settings/permissions');
    }
  }

  String _title(bool isStep2, bool alarmless) {
    if (alarmless) {
      return LocaleKeys.onboarding_permissions_step2_unsupported_title.tr();
    }
    return isStep2
        ? LocaleKeys.onboarding_permissions_step2_title.tr()
        : LocaleKeys.onboarding_permissions_step1_title.tr();
  }

  String _subtitle(bool isStep2, bool alarmless) {
    if (alarmless) {
      return LocaleKeys.onboarding_permissions_step2_unsupported_subtitle.tr();
    }
    return isStep2
        ? LocaleKeys.onboarding_permissions_step2_subtitle.tr()
        : LocaleKeys.onboarding_permissions_step1_subtitle.tr();
  }

  String _primaryLabel(bool isStep2, bool alarmless) {
    if (alarmless) {
      return LocaleKeys.onboarding_permissions_step2_unsupported_button.tr();
    }
    return isStep2
        ? LocaleKeys.onboarding_permissions_step2_button.tr()
        : LocaleKeys.onboarding_permissions_step1_button.tr();
  }

  /// The preview mirrors the prompt this platform will actually show, so
  /// Android never sees Apple's wording for a dialog it will never open.
  String _previewTitle(bool isApple, bool isStep2) {
    if (isStep2) {
      return isApple
          ? LocaleKeys.onboarding_permissions_preview_crit_title.tr()
          : LocaleKeys.onboarding_permissions_preview_crit_title_android.tr();
    }
    return isApple
        ? LocaleKeys.onboarding_permissions_preview_notif_title.tr()
        : LocaleKeys.onboarding_permissions_preview_notif_title_android.tr();
  }

  String _previewMessage(bool isApple, bool isStep2) {
    if (isStep2) {
      return isApple
          ? LocaleKeys.onboarding_permissions_preview_crit_desc.tr()
          : LocaleKeys.onboarding_permissions_preview_crit_desc_android.tr();
    }
    return isApple
        ? LocaleKeys.onboarding_permissions_preview_notif_desc.tr()
        : LocaleKeys.onboarding_permissions_preview_notif_desc_android.tr();
  }
}
