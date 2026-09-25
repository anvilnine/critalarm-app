import 'dart:ui';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/entities/onboarding_draft.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_onboarding_completed_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/onboarding_draft_usecases.dart';

/// Routes a tapped notification or widget can ask for. Anything else from the
/// platform is ignored, so a stray route name cannot drop the user somewhere
/// odd. Home is on the list for the open count widget.
bool isPushDeepLink(String? location) =>
    location != null &&
    (location == '/' ||
        location.startsWith('/incidents/') ||
        location.startsWith('/topics/'));

/// Where the app opens.
///
/// Only [hasCompletedOnboarding] decides whether onboarding is over. A saved
/// server connection used to count as finished, which meant force-quitting
/// after the connect step silently skipped the alarm test for good.
/// [step] says which onboarding screen to resume at instead.
String initialLocationFor({
  required bool hasCompletedOnboarding,
  OnboardingStep step = OnboardingStep.welcome,
  String? deepLink,
}) {
  // A tapped notification wins: the user asked for that screen by name.
  if (hasCompletedOnboarding && isPushDeepLink(deepLink)) return deepLink!;
  return hasCompletedOnboarding ? '/' : step.route;
}

class InitialRouteResolver {
  const InitialRouteResolver(
    this._getOnboardingCompleted,
    this._readDraft, {
    String Function()? platformRoute,
  }) : _platformRoute = platformRoute ?? _defaultPlatformRoute;

  final GetOnboardingCompletedUsecase _getOnboardingCompleted;
  final ReadOnboardingDraftUsecase _readDraft;
  final String Function() _platformRoute;

  /// [deepLink] is the route a tapped notification asked for. iOS hands it
  /// over on a channel rather than through the platform route name, so it can
  /// be passed in; Android sets the platform route and passes nothing.
  Future<String> call({String? deepLink}) async {
    final completed = await _getOnboardingCompleted(const NoParams());
    final draft = await _readDraft(const NoParams());

    return initialLocationFor(
      hasCompletedOnboarding: completed.getOrNull() ?? false,
      step: draft.getOrNull()?.step ?? OnboardingStep.welcome,
      deepLink: deepLink ?? _platformRoute(),
    );
  }

  static String _defaultPlatformRoute() =>
      PlatformDispatcher.instance.defaultRouteName;
}
