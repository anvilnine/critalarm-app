import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_state.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Screen 1 of Onboarding (/onboarding): Permissions.
///
/// Explains Crit Alarm capabilities (3am pages through silent switch & DND),
/// details required Android 13+ POST_NOTIFICATIONS and Android 14+
/// USE_FULL_SCREEN_INTENT permissions, requests them, and handles the denial
/// path cleanly with [AppEmptyState].
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
        final postNotificationsText = LocaleKeys
            .onboarding_permissions_post_notifications
            .tr();
        final fullScreenIntentText = LocaleKeys
            .onboarding_permissions_full_screen_intent
            .tr();
        final requiredHeader = LocaleKeys.onboarding_permissions_required_header
            .tr();
        final continueWithoutText = LocaleKeys
            .onboarding_permissions_continue_without_button
            .tr();

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
                          ],
                        ),
                        const SizedBox(height: Spacing.s5),

                        if (state.isDenied) ...[
                          // Denial path: clearly states what won't work
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
                          // Center alarmed face and pill badge
                          const Center(
                            child: FaceWidget(
                              state: FaceState.alarmed,
                              size: 84,
                              isLive: true,
                            ),
                          ),
                          const SizedBox(height: Spacing.s4),
                          Center(
                            child: AppBadge(
                              text: LocaleKeys.onboarding_permissions_badge
                                  .tr(),
                              faceState: FaceState.alarmed,
                            ),
                          ),
                          const SizedBox(height: Spacing.s4),

                          // Hero text
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              LocaleKeys.onboarding_permissions_title.tr(),
                              style: AppTypography.display(
                                colors.onCanvas,
                                fontSize: 36,
                              ),
                            ),
                          ),
                          const SizedBox(height: Spacing.s3),

                          // Explains what Crit Alarm does
                          Text(
                            LocaleKeys.onboarding_permissions_subtitle.tr(),
                            style: AppTypography.lead(
                              colors.onCanvasMuted,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: Spacing.s5),

                          // Explains Android 13+ and Android 14+ permissions
                          AppSheet(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppSectionHeader(requiredHeader),
                                const SizedBox(height: 4),
                                AppFeatureBullet(
                                  text: postNotificationsText,
                                  glyph: GlyphType.bell,
                                ),
                                const SizedBox(height: 12),
                                AppFeatureBullet(
                                  text: fullScreenIntentText,
                                  glyph: GlyphType.arrow,
                                ),
                              ],
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
                    children: state.isDenied
                        ? [
                            AppButton(
                              label: LocaleKeys
                                  .onboarding_permissions_denied_open_settings
                                  .tr(),
                              isFullWidth: true,
                              onPressed: cubit.openSettings,
                            ),
                            const SizedBox(height: Spacing.s3),
                            AppButton(
                              label: LocaleKeys
                                  .onboarding_permissions_denied_continue
                                  .tr(),
                              variant: AppButtonVariant.ghost,
                              isFullWidth: true,
                              onPressed: () {
                                cubit.continueAnyway();
                                context.go('/onboarding/connect');
                              },
                            ),
                          ]
                        : [
                            AppButton(
                              label: LocaleKeys
                                  .onboarding_permissions_enable_button
                                  .tr(),
                              size: AppButtonSize.lg,
                              isFullWidth: true,
                              isLoading: state.isRequesting,
                              onPressed: cubit.requestPermissions,
                            ),
                            const SizedBox(height: Spacing.s3),
                            AppButton(
                              label: continueWithoutText,
                              variant: AppButtonVariant.ghost,
                              isFullWidth: true,
                              onPressed: () =>
                                  context.go('/onboarding/connect'),
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
