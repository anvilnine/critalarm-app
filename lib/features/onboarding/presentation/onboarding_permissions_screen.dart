import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/notification_permissions_state.dart';
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;

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
                    padding: EdgeInsets.fromLTRB(
                      Spacing.s5,
                      Spacing.s6,
                      Spacing.s5,
                      16 + bottomInset,
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
                                'Crit Alarm',
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
                            title: 'Notifications disabled',
                            description:
                                "Critical alerts won't wake the screen, and "
                                'notifications will be silent or missing.',
                            buttonLabel: 'Open Settings',
                            onButtonPressed: cubit.openSettings,
                          ),
                          const SizedBox(height: Spacing.s5),

                          // Action to continue anyway with permissions denied
                          AppButton(
                            label: 'Continue anyway',
                            variant: AppButtonVariant.ghost,
                            isFullWidth: true,
                            onPressed: () {
                              cubit.continueAnyway();
                              context.go('/onboarding/connect');
                            },
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
                          const Center(
                            child: AppBadge(
                              text: 'Rings through silent & DND',
                              faceState: FaceState.alarmed,
                            ),
                          ),
                          const SizedBox(height: Spacing.s4),

                          // Hero text
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Your server pages you.\nEven at 3am.',
                              style: AppTypography.display(
                                colors.onCanvas,
                                fontSize: 36,
                              ),
                            ),
                          ),
                          const SizedBox(height: Spacing.s3),

                          // Explains what Crit Alarm does
                          Text(
                            'Crit Alarm wakes your screen and rings '
                            'continuously until acknowledged, bypassing your '
                            'silent switch and Do Not Disturb when critical '
                            'incidents occur.',
                            style: AppTypography.lead(
                              colors.onCanvasMuted,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: Spacing.s5),

                          // Explains Android 13+ and Android 14+ permissions
                          const AppSheet(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppSectionHeader('REQUIRED PERMISSIONS'),
                                SizedBox(height: 4),
                                AppFeatureBullet(
                                  text:
                                      'Android 13+ POST_NOTIFICATIONS: '
                                      'alerts you immediately when a '
                                      'service goes down.',
                                  glyph: GlyphType.bell,
                                ),
                                SizedBox(height: 12),
                                AppFeatureBullet(
                                  text:
                                      'Android 14+ USE_FULL_SCREEN_INTENT: '
                                      'wakes the display for urgent '
                                      'priority-5 emergencies.',
                                  glyph: GlyphType.arrow,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: Spacing.s6),

                          // Request button
                          AppButton(
                            label: 'Enable notifications',
                            size: AppButtonSize.lg,
                            isFullWidth: true,
                            isLoading: state.isRequesting,
                            onPressed: cubit.requestPermissions,
                          ),
                          const SizedBox(height: Spacing.s3),

                          // Skip / continue anyway button
                          AppButton(
                            label: 'Continue without permissions',
                            variant: AppButtonVariant.ghost,
                            isFullWidth: true,
                            onPressed: () => context.go('/onboarding/connect'),
                          ),
                        ],
                      ],
                    ),
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
