import 'package:critalarm/app/di.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_welcome_cubit.dart';
import 'package:critalarm/features/onboarding/presentation/cubits/onboarding_welcome_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// First screen of the Onboarding flow (/onboarding).
///
/// Welcomes the user, displays brand and hero messaging, allows configuring
/// the server endpoint URL (defaulting to https://api.critalarm.app), and
/// transitions to the permissions step.
class OnboardingWelcomeScreen extends StatelessWidget {
  const OnboardingWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<OnboardingWelcomeCubit>(),
      child: const _OnboardingWelcomeView(),
    );
  }
}

class _OnboardingWelcomeView extends StatefulWidget {
  const _OnboardingWelcomeView();

  @override
  State<_OnboardingWelcomeView> createState() => _OnboardingWelcomeViewState();
}

class _OnboardingWelcomeViewState extends State<_OnboardingWelcomeView> {
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    final initialUrl =
        context.read<OnboardingWelcomeCubit>().state.serverUrl;
    _urlController = TextEditingController(text: initialUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return BlocConsumer<OnboardingWelcomeCubit, OnboardingWelcomeState>(
      listenWhen: (prev, curr) => !prev.canNavigate && curr.canNavigate,
      listener: (context, state) {
        context.read<OnboardingWelcomeCubit>().navigationHandled();
        context.go('/onboarding/permissions');
      },
      builder: (context, state) {
        final cubit = context.read<OnboardingWelcomeCubit>();

        return Scaffold(
          backgroundColor: colors.canvas,
          body: GhostField(
            shapeCount: 7,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with Crit Alarm brand and calm face
                        Row(
                          children: [
                            const FaceWidget(
                              state: FaceState.calm,
                              size: 34,
                            ),
                            const SizedBox(width: Spacing.s3),
                            Text(
                              'Crit Alarm',
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
                          ],
                        ),
                        const SizedBox(height: Spacing.s7),

                        // Hero text
                        Text(
                          'Your server pages you.\nEven at 3am.',
                          style: AppTypography.display(
                            colors.onCanvas,
                            fontSize: 40,
                          ),
                        ),
                        const SizedBox(height: Spacing.s4),

                        // Subtitle
                        Text(
                          'One HTTP endpoint per topic. Point your scripts, '
                          'cron, or monitoring tools at Crit Alarm.',
                          style: AppTypography.lead(
                            colors.onCanvasMuted,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: Spacing.s7),

                        // Server URL input with helper text
                        AppTextField(
                          label: 'SERVER URL',
                          controller: _urlController,
                          placeholder: 'https://api.critalarm.app',
                          helperText:
                              'Defaults to https://api.critalarm.app. '
                              'Change this if you run your own instance.',
                          errorText: state.errorMessage,
                          onChanged: cubit.serverUrlChanged,
                          onSubmitted: (_) => cubit.validateAndContinue(),
                        ),
                        const SizedBox(height: Spacing.s7),

                        // Primary button "Continue"
                        AppButton(
                          label: 'Continue',
                          size: AppButtonSize.lg,
                          isFullWidth: true,
                          isLoading: state.isValidating,
                          onPressed: cubit.validateAndContinue,
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
