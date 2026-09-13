import 'dart:ui';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_connection_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_onboarding_completed_usecase.dart';

/// Routes a tapped notification can ask for. Anything else from the platform is
/// ignored, so a stray route name cannot drop the user somewhere odd.
bool isPushDeepLink(String? location) =>
    location != null &&
    (location.startsWith('/incidents/') || location.startsWith('/topics/'));

String initialLocationFor({
  required bool hasServerConnection,
  required bool hasCompletedOnboarding,
  String? deepLink,
}) {
  // A tapped notification wins: the user asked for that screen by name.
  final ready = hasServerConnection || hasCompletedOnboarding;
  if (ready && isPushDeepLink(deepLink)) return deepLink!;
  return !hasServerConnection && !hasCompletedOnboarding ? '/onboarding' : '/';
}

class InitialRouteResolver {
  const InitialRouteResolver(
    this._getConnection,
    this._getOnboardingCompleted, {
    String Function()? platformRoute,
  }) : _platformRoute = platformRoute ?? _defaultPlatformRoute;

  final GetConnectionUsecase _getConnection;
  final GetOnboardingCompletedUsecase _getOnboardingCompleted;
  final String Function() _platformRoute;

  /// [deepLink] is the route a tapped notification asked for. iOS hands it
  /// over on a channel rather than through the platform route name, so it can
  /// be passed in; Android sets the platform route and passes nothing.
  Future<String> call({String? deepLink}) async {
    final connection = await _getConnection(const NoParams());
    final completed = await _getOnboardingCompleted(const NoParams());

    return initialLocationFor(
      hasServerConnection: connection.isSuccess(),
      hasCompletedOnboarding: completed.getOrNull() ?? false,
      deepLink: deepLink ?? _platformRoute(),
    );
  }

  static String _defaultPlatformRoute() =>
      PlatformDispatcher.instance.defaultRouteName;
}
