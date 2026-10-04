import 'package:critalarm/app/di.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Whether [uri] is a replay from Settings: a look at the screens, where
/// nothing is saved.
bool isOnboardingReplayUri(Uri uri) => uri.queryParameters['demo'] == 'true';

bool isOnboardingReplay(BuildContext context) =>
    isOnboardingReplayUri(GoRouterState.of(context).uri);

/// The user is done with the step [stepId]. Opens whatever comes next.
///
/// A screen never names the step after it. The flow engine marks this one
/// completed, picks the next step from the pinned flow, and completes setup
/// and opens Home when none is left.
///
/// On a replay (`?demo=true`) nothing is saved, no step is skipped, and the
/// flag carries on to the next route.
Future<void> finishOnboardingStep(BuildContext context, String stepId) async {
  final isReplay = isOnboardingReplay(context);
  final router = GoRouter.of(context);
  final next = await getIt<OnboardingFlowEngine>().finishStep(
    stepId,
    isReplay: isReplay,
  );
  final route = next.route;
  if (route == null) {
    router.go('/');
  } else {
    router.go(isReplay ? '$route?demo=true' : route);
  }
}
