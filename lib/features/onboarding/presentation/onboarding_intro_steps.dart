part of 'onboarding_welcome_screen.dart';

/// Onboarding step two (/onboarding/how-it-rings): a curl in a terminal makes
/// a phone ring, drawn as the phone in the user's hand.
class OnboardingHowItRingsScreen extends StatelessWidget {
  const OnboardingHowItRingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Only the drawing changes, so the platform is read the same way the
    // permissions screen picks its iOS or Android look.
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    return _IntroLayout(
      hero: isAndroid ? const _AndroidCurlHero() : const _CurlHero(),
      textDelay: const Duration(milliseconds: 900),
      title: LocaleKeys.onboarding_welcome_rings_title.tr(),
      subtitle: LocaleKeys.onboarding_welcome_rings_subtitle.tr(),
      button: LocaleKeys.onboarding_welcome_continue.tr(),
      onPressed: () => goToOnboardingStep(context, OnboardingStep.permissions),
    );
  }
}

/// Onboarding step four (/onboarding/widgets), after the permissions: the
/// home screen widgets, marked as a Pro feature.
class OnboardingWidgetsScreen extends StatelessWidget {
  const OnboardingWidgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _IntroLayout(
      hero: const _WidgetsHero(),
      textDelay: const Duration(milliseconds: 900),
      title: LocaleKeys.onboarding_welcome_widgets_title.tr(),
      badge: AppBadge(
        text: LocaleKeys.onboarding_welcome_widgets_pro.tr(),
        faceState: FaceState.love,
      ),
      subtitle: LocaleKeys.onboarding_welcome_widgets_subtitle.tr(),
      button: LocaleKeys.onboarding_welcome_continue.tr(),
      onPressed: () => goToOnboardingStep(context, OnboardingStep.connect),
    );
  }
}
