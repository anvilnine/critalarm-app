import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_permissions_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_permissions_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Permissions & Test Alarm screen of the Onboarding flow
/// (/onboarding/permissions).
///
/// Explains Critical Alerts, provides an interactive "Ring me now" button to
/// test firing a priority-5 alarm against the server, displays status
/// feedback, and finishes onboarding by navigating to /home.
class OnboardingPermissionsScreen extends StatelessWidget {
  const OnboardingPermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<OnboardingPermissionsCubit>(),
      child: const _OnboardingPermissionsView(),
    );
  }
}

class _OnboardingPermissionsView extends StatelessWidget {
  const _OnboardingPermissionsView();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return BlocBuilder<OnboardingPermissionsCubit, OnboardingPermissionsState>(
      builder: (context, state) {
        final cubit = context.read<OnboardingPermissionsCubit>();

        return Scaffold(
          backgroundColor: colors.canvas,
          body: GhostField(
            seed: 99,
            shapeCount: 8,
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.s5,
                      vertical: Spacing.s6,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Alarmed face at top
                        const FaceWidget(
                          state: FaceState.alarmed,
                          size: 100,
                          isLive: true,
                        ),
                        const SizedBox(height: Spacing.s5),

                        // Pill badge
                        const AppBadge(
                          faceState: FaceState.alarmed,
                        ),
                        const SizedBox(height: Spacing.s4),

                        // Headline
                        Text(
                          'Never miss a critical page',
                          textAlign: TextAlign.center,
                          style: AppTypography.headline(
                            colors.onCanvas,
                            fontSize: 32,
                          ),
                        ),
                        const SizedBox(height: Spacing.s3),

                        // Body explaining Critical Alerts
                        Text(
                          'Critical Alerts play through your silent switch and '
                          'Do Not Disturb. When your server triggers a '
                          'priority-5 page, Crit Alarm rings continuously '
                          'until you acknowledge it.',
                          textAlign: TextAlign.center,
                          style: AppTypography.body(colors.onCanvasMuted),
                        ),
                        const SizedBox(height: Spacing.s7),

                        // "Ring me now" test button
                        AppButton(
                          label: 'Ring me now',
                          variant: AppButtonVariant.ink,
                          isFullWidth: true,
                          isLoading: state.isRinging,
                          onPressed: () =>
                              cubit.ringTestAlarm(topic: 'prod-db'),
                        ),

                        // Test alert toast / status when rung
                        if (state.isSuccess || state.isFailure) ...[
                          const SizedBox(height: Spacing.s4),
                          AnimatedSwitcher(
                            duration: AppDurations.quick,
                            child: state.isSuccess
                                ? AppToast(
                                    key: const ValueKey('success-toast'),
                                    variant: AppToastVariant.crit,
                                    message: 'Test alarm sent to',
                                    boldText: state.topic,
                                    boldTextSuffix: '• Ringing now',
                                  )
                                : AppToast(
                                    key: const ValueKey('error-toast'),
                                    faceState: FaceState.worried,
                                    message: state.errorMessage ??
                                        'Failed to trigger test alarm',
                                  ),
                          ),
                        ],
                        const SizedBox(height: Spacing.s7),

                        // Primary button "Get started" navigating to /home
                        AppButton(
                          label: 'Get started',
                          size: AppButtonSize.lg,
                          isFullWidth: true,
                          onPressed: () => context.go('/home'),
                        ),
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
