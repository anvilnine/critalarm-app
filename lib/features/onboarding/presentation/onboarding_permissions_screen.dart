import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_state.dart';
import 'package:critalarm/features/onboarding/presentation/widgets/permission_dialog_preview.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Screen 1 of Onboarding (/onboarding): Permissions.
///
/// Implements Option B (2-step stepper):
/// 1. Notifications permission ask with simulated dialog preview.
/// 2. Critical alerts / silent-mode breakthrough ask with simulated preview.
///
/// Enforces permission grant with no bypass.
class OnboardingPermissionsScreen extends StatelessWidget {
  const OnboardingPermissionsScreen({
    super.key,
    this.initialStep = NotificationPermissionStep.initial,
  });

  final NotificationPermissionStep initialStep;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<NotificationPermissionsCubit>(param1: initialStep),
      child: const _OnboardingPermissionsView(),
    );
  }
}

class _OnboardingPermissionsView extends StatelessWidget {
  const _OnboardingPermissionsView();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return BlocConsumer<
      NotificationPermissionsCubit,
      NotificationPermissionsState
    >(
      listenWhen: (prev, curr) => !prev.canNavigate && curr.canNavigate,
      listener: (context, state) {
        context.read<NotificationPermissionsCubit>().navigationHandled();
        context.go('/onboarding/connect');
      },
      builder: (context, state) {
        final cubit = context.read<NotificationPermissionsCubit>();
        final isStep2 = state.activeSubstep == 1;

        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: colors.canvas,
          body: GhostField(
            shapeCount: 7,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Brand row
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
                                  fontFamilyFallback:
                                      AppTypography.fontDisplayFallbacks,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                  letterSpacing: -0.03 * 22,
                                  color: colors.onCanvas,
                                ),
                              ),
                            ),
                            // Stepper indicator pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(12),
                                 border: Border.all(
                                  color: colors.hairline.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                isStep2 ? 'Step 2 of 2' : 'Step 1 of 2',
                                style: TextStyle(
                                  fontFamily: AppTypography.fontMono,
                                  fontFamilyFallback:
                                      AppTypography.fontMonoFallbacks,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: colors.ink2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Spacing.s5),

                        if (state.isDenied) ...[
                          // Denial recovery path
                          AppEmptyState(
                            faceState: FaceState.worried,
                            title: LocaleKeys
                                .onboarding_permissions_denied_title
                                .tr(),
                            description: LocaleKeys
                                .onboarding_permissions_denied_description
                                .tr(),
                            buttonLabel: null,
                          ),
                        ] else ...[
                          // Visual face & badge
                          Center(
                            child: FaceWidget(
                              state: isStep2
                                  ? FaceState.watching
                                  : FaceState.alarmed,
                              size: 80,
                              isLive: true,
                            ),
                          ),
                          const SizedBox(height: Spacing.s3),
                          Center(
                            child: AppBadge(
                              text: isStep2
                                  ? 'BREAKTHROUGH SILENT MODE'
                                  : LocaleKeys.onboarding_permissions_badge
                                      .tr(),
                              faceState: isStep2
                                  ? FaceState.watching
                                  : FaceState.alarmed,
                            ),
                          ),
                          const SizedBox(height: Spacing.s4),

                          // Hero text
                          Text(
                            isStep2
                                ? LocaleKeys
                                    .onboarding_permissions_step2_title
                                    .tr()
                                : LocaleKeys
                                    .onboarding_permissions_step1_title
                                    .tr(),
                            style: AppTypography.display(
                              colors.onCanvas,
                              fontSize: 32,
                            ),
                          ),
                          const SizedBox(height: Spacing.s2),

                          // Subtitle
                          Text(
                            isStep2
                                ? LocaleKeys
                                    .onboarding_permissions_step2_subtitle
                                    .tr()
                                : LocaleKeys
                                    .onboarding_permissions_step1_subtitle
                                    .tr(),
                            style: AppTypography.lead(
                              colors.onCanvasMuted,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: Spacing.s5),

                          // Simulated native dialog preview
                          PermissionDialogPreview(
                            title: isStep2
                                ? LocaleKeys
                                    .onboarding_permissions_preview_crit_title
                                    .tr()
                                : LocaleKeys
                                    .onboarding_permissions_preview_notif_title
                                    .tr(),
                            message: isStep2
                                ? LocaleKeys
                                    .onboarding_permissions_preview_crit_desc
                                    .tr()
                                : LocaleKeys
                                    .onboarding_permissions_preview_notif_desc
                                    .tr(),
                            allowLabel: LocaleKeys
                                .onboarding_permissions_preview_allow
                                .tr(),
                            denyLabel: LocaleKeys
                                .onboarding_permissions_preview_dont_allow
                                .tr(),
                            isCritical: isStep2,
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              LocaleKeys.onboarding_permissions_preview_hint
                                  .tr(),
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
                  child: Column(
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
                            AppButton(
                              label: 'Try again',
                              variant: AppButtonVariant.paper,
                              isFullWidth: true,
                              onPressed: cubit.requestPermissions,
                            ),
                          ]
                        : [
                            AppButton(
                              label: isStep2
                                  ? LocaleKeys
                                      .onboarding_permissions_step2_button
                                      .tr()
                                  : LocaleKeys
                                      .onboarding_permissions_step1_button
                                      .tr(),
                              size: AppButtonSize.lg,
                              isFullWidth: true,
                              isLoading: state.isRequesting,
                              onPressed: isStep2
                                  ? cubit.requestCriticalAlerts
                                  : cubit.requestNotifications,
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
}
