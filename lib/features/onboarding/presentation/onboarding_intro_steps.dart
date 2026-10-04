part of 'onboarding_welcome_screen.dart';

/// The how-it-rings step (/onboarding/how-it-rings): a curl in a terminal makes
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
      title: LocaleKeys.onboarding_welcome_rings_title.tr(),
      subtitle: LocaleKeys.onboarding_welcome_rings_subtitle.tr(),
      button: LocaleKeys.onboarding_welcome_continue.tr(),
      onPressed: () => unawaited(
        finishOnboardingStep(context, OnboardingStepId.howItRings),
      ),
    );
  }
}

/// The widgets step (/onboarding/widgets): the home screen widgets, marked as
/// a Hosted feature. It is optional. A flow lists it where it wants it, and
/// the button finishes it like any other step, whatever comes next.
class OnboardingWidgetsScreen extends StatelessWidget {
  const OnboardingWidgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _IntroLayout(
      hero: const _WidgetsHero(),
      title: LocaleKeys.onboarding_welcome_widgets_title.tr(),
      badge: AppBadge(
        text: LocaleKeys.onboarding_welcome_widgets_pro.tr(),
        faceState: FaceState.love,
      ),
      subtitle: LocaleKeys.onboarding_welcome_widgets_subtitle.tr(),
      button: LocaleKeys.onboarding_welcome_continue.tr(),
      onPressed: () => unawaited(
        finishOnboardingStep(context, OnboardingStepId.widgets),
      ),
    );
  }
}
