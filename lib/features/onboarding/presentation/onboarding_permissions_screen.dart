import 'dart:async';

import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_state.dart';
import 'package:critalarm/features/onboarding/presentation/model/onboarding_ambient_profiles.dart';
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
/// ones the user has not already answered. Nothing here blocks: a refused
/// permission is explained and onboarding carries on, because Apple's own
/// guidance forbids holding the app hostage over one, and AlarmKit never
/// prompts twice.
class OnboardingPermissionsScreen extends StatelessWidget {
  const OnboardingPermissionsScreen({
    super.key,
    this.initialStep = NotificationPermissionStep.initial,
    this.replayForDemo = false,
  });

  final NotificationPermissionStep initialStep;

  /// Opened from the developer menu to look at the screens. Every step shows,
  /// even the ones already granted.
  final bool replayForDemo;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<NotificationPermissionsCubit>(
          param1: initialStep,
          param2: replayForDemo,
        );
        unawaited(cubit.refresh());
        return cubit;
      },
      child: const _OnboardingPermissionsView(),
    );
  }
}

class _OnboardingPermissionsView extends StatefulWidget {
  const _OnboardingPermissionsView();

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
          context.go('/onboarding/connect');
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
        // On Android step 2 asks to lift battery optimisation instead.
        final battery = isStep2 && state.isBatteryStep;
        final alarmless = isStep2 && !state.alarmSupported && !battery;
        final requestStep = battery
            ? cubit.requestBatteryExemption
            : (isStep2
                  ? cubit.requestCriticalAlerts
                  : cubit.requestNotifications);

        final previewTitle = battery
            ? LocaleKeys.onboarding_permissions_preview_battery_title.tr()
            : _previewTitle(isApple, isStep2);
        final previewMessage = battery
            ? LocaleKeys.onboarding_permissions_preview_battery_desc.tr()
            : _previewMessage(isApple, isStep2);
        final summaryLabel = LocaleKeys
            .onboarding_permissions_preview_allow_summary
            .tr();
        final previewHint = LocaleKeys.onboarding_permissions_preview_hint.tr();

        // What the pinned bar takes off the bottom of the viewport: its own
        // buttons, the 12 the scaffold puts under them, and the home
        // indicator. Denied shows lg + Spacing.s3 + md, the rest just lg.
        final barButtons = state.isDenied || battery ? 60.0 + 12 + 48 : 60.0;
        final bottomBarHeight =
            barButtons + 12 + MediaQuery.paddingOf(context).bottom;

        return AppScreenScaffold(
          backgroundColor: Colors.transparent,
          withGhosts: false,
          withFades: false,
          hasTabBar: false,
          topBar: AppTopBar(
            title: LocaleKeys.app_title.tr(),
            trailing: _StepPill(
              current: isStep2 ? 2 : 1,
              total: state.totalSteps,
            ),
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
                      label: _primaryLabel(state, isStep2, alarmless),
                      size: AppButtonSize.lg,
                      isFullWidth: true,
                      isLoading: state.isRequesting,
                      onPressed: alarmless
                          ? cubit.continueWithout
                          : requestStep,
                    ),
                    // Never a wall here either. The health banner keeps
                    // asking about battery after onboarding.
                    if (battery) ...[
                      const SizedBox(height: Spacing.s3),
                      AppButton(
                        label: LocaleKeys
                            .onboarding_permissions_step2_battery_skip
                            .tr(),
                        variant: AppButtonVariant.paper,
                        isFullWidth: true,
                        isLoading: state.isChecking,
                        onPressed: cubit.continueWithout,
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
                child: Padding(
                  // The pinned bar floats over the list, so the content leaves
                  // room for it rather than running underneath.
                  padding: EdgeInsets.only(bottom: bottomBarHeight),
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
                                text: battery
                                    ? LocaleKeys
                                          .onboarding_permissions_badge_battery
                                          .tr()
                                    : isStep2
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
                              _title(state, isStep2, alarmless),
                              style: AppTypography.display(
                                colors.onCanvas,
                                fontSize: 32,
                              ),
                            ),
                            const SizedBox(height: Spacing.s2),
                            Text(
                              _subtitle(state, isStep2, alarmless),
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
            ),
          ],
        );
      },
    );
  }

  String _title(
    NotificationPermissionsState state,
    bool isStep2,
    bool alarmless,
  ) {
    if (isStep2 && state.isBatteryStep) {
      return LocaleKeys.onboarding_permissions_step2_battery_title.tr();
    }
    if (alarmless) {
      return LocaleKeys.onboarding_permissions_step2_unsupported_title.tr();
    }
    return isStep2
        ? LocaleKeys.onboarding_permissions_step2_title.tr()
        : LocaleKeys.onboarding_permissions_step1_title.tr();
  }

  String _subtitle(
    NotificationPermissionsState state,
    bool isStep2,
    bool alarmless,
  ) {
    if (isStep2 && state.isBatteryStep) {
      return LocaleKeys.onboarding_permissions_step2_battery_subtitle.tr();
    }
    if (alarmless) {
      return LocaleKeys.onboarding_permissions_step2_unsupported_subtitle.tr();
    }
    return isStep2
        ? LocaleKeys.onboarding_permissions_step2_subtitle.tr()
        : LocaleKeys.onboarding_permissions_step1_subtitle.tr();
  }

  String _primaryLabel(
    NotificationPermissionsState state,
    bool isStep2,
    bool alarmless,
  ) {
    if (isStep2 && state.isBatteryStep) {
      return LocaleKeys.onboarding_permissions_step2_battery_button.tr();
    }
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

/// "Step 1 of 2" marker that sits at the right of the top bar. On a phone with
/// no alarm permission to ask for there is only one step, and it says so.
class _StepPill extends StatelessWidget {
  const _StepPill({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.hairline.withValues(alpha: 0.5)),
      ),
      child: Text(
        LocaleKeys.onboarding_permissions_step_pill.tr(
          namedArgs: {'current': '$current', 'total': '$total'},
        ),
        style: TextStyle(
          fontFamily: AppTypography.fontMono,
          fontFamilyFallback: AppTypography.fontMonoFallbacks,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: colors.ink2,
        ),
      ),
    );
  }
}
