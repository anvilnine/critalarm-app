import 'dart:ui';
import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/core/push/push_deep_link.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_onboarding_completed_usecase.dart';

/// Routes a tapped notification or widget can ask for. Anything else from the
/// platform is ignored, so a stray route name cannot drop the user somewhere
/// odd. Home is on the list for the open count widget, and the paywall for a
/// locked widget.
bool isPushDeepLink(String? location) =>
    location != null &&
    (location == PushDeepLink.homeLocation ||
        location == PushDeepLink.paywallLocation ||
        location == paywallPath ||
        location.startsWith('/incidents/') ||
        location.startsWith('/topics/'));

/// Where the app opens.
///
/// Only [hasCompletedOnboarding] decides whether onboarding is over. A saved
/// server connection used to count as finished, which meant force-quitting
/// after the connect step silently skipped the alarm test for good.
/// [resumeRoute] is the onboarding screen to open instead, worked out by the
/// flow engine.
String initialLocationFor({
  required bool hasCompletedOnboarding,
  String resumeRoute = '/onboarding/welcome',
  String? deepLink,
}) {
  // A tapped notification wins: the user asked for that screen by name.
  if (hasCompletedOnboarding && isPushDeepLink(deepLink)) {
    return PushDeepLink.tagged(deepLink!);
  }
  return hasCompletedOnboarding ? '/' : resumeRoute;
}

class InitialRouteResolver {
  const InitialRouteResolver(
    this._getOnboardingCompleted,
    this._flow, {
    String Function()? platformRoute,
  }) : _platformRoute = platformRoute ?? _defaultPlatformRoute;

  final GetOnboardingCompletedUsecase _getOnboardingCompleted;
  final OnboardingFlowEngine _flow;
  final String Function() _platformRoute;

  /// [deepLink] is the route a tapped notification asked for. iOS hands it
  /// over on a channel rather than through the platform route name, so it can
  /// be passed in; Android sets the platform route and passes nothing.
  Future<String> call({String? deepLink}) async {
    var completed =
        (await _getOnboardingCompleted(const NoParams())).getOrNull() ?? false;
    String? resumeRoute;
    if (!completed) {
      // The engine completes setup itself when no step is left to show.
      final resume = await _flow.resume();
      completed = resume.isHome;
      resumeRoute = resume.route;
    }

    return initialLocationFor(
      hasCompletedOnboarding: completed,
      resumeRoute: resumeRoute ?? '/onboarding/welcome',
      deepLink: deepLink ?? _platformRoute(),
    );
  }

  static String _defaultPlatformRoute() =>
      PlatformDispatcher.instance.defaultRouteName;
}
