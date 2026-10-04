import 'package:critalarm/app/di.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Whether [uri] is a replay from Settings: a look at the screens, where
/// nothing is saved.
bool isOnboardingReplayUri(Uri uri) => uri.queryParameters['demo'] == 'true';

bool isOnboardingReplay(BuildContext context) =>
    isOnboardingReplayUri(GoRouterState.of(context).uri);

/// What the router does once a step is finished.
enum OnboardingMoveKind {
  /// Nothing. The user left the step while the engine was working.
  stay,

  /// Close the screen, back to whatever opened it.
  pop,

  /// Open [OnboardingMove.location], replacing the screen.
  go,
}

@immutable
class OnboardingMove {
  const OnboardingMove.stay() : kind = OnboardingMoveKind.stay, location = null;
  const OnboardingMove.pop() : kind = OnboardingMoveKind.pop, location = null;
  const OnboardingMove.go(String this.location) : kind = OnboardingMoveKind.go;

  final OnboardingMoveKind kind;
  final String? location;

  @override
  bool operator ==(Object other) =>
      other is OnboardingMove &&
      kind == other.kind &&
      location == other.location;

  @override
  int get hashCode => Object.hash(kind, location);

  @override
  String toString() => 'OnboardingMove(${kind.name}, $location)';
}

/// Turns the engine's answer into a move.
///
/// [locationBefore] is where the router stood when the step was finished and
/// [locationNow] where it stands once the engine has answered. If they
/// differ the user has already gone somewhere else, and pulling them to the
/// next step would be a surprise.
OnboardingMove onboardingMoveFor(
  OnboardingDestination destination, {
  required bool isReplay,
  required bool canPop,
  required Uri locationBefore,
  required Uri locationNow,
}) {
  if (locationBefore != locationNow) return const OnboardingMove.stay();
  if (destination.isBack) {
    return canPop ? const OnboardingMove.pop() : const OnboardingMove.go('/');
  }
  final route = destination.route;
  if (route == null) return const OnboardingMove.go('/');
  return OnboardingMove.go(isReplay ? '$route?demo=true' : route);
}

/// The user is done with the step [stepId]. Opens whatever comes next.
///
/// A screen never names the step after it. The flow engine marks this one
/// completed, picks the next step from the pinned flow, and completes setup
/// and opens Home when none is left.
///
/// On a replay (`?demo=true`) nothing is saved, no step is skipped, and the
/// flag carries on to the next route.
///
/// When setup is already complete the screen was opened on its own, from
/// Settings or a card on Home, and it closes back to there.
Future<void> finishOnboardingStep(BuildContext context, String stepId) async {
  final isReplay = isOnboardingReplay(context);
  final router = GoRouter.of(context);
  Uri location() => router.routerDelegate.currentConfiguration.uri;
  final locationBefore = location();
  final next = await getIt<OnboardingFlowEngine>().finishStep(
    stepId,
    isReplay: isReplay,
  );
  final move = onboardingMoveFor(
    next,
    isReplay: isReplay,
    canPop: router.canPop(),
    locationBefore: locationBefore,
    locationNow: location(),
  );
  switch (move.kind) {
    case OnboardingMoveKind.stay:
      break;
    case OnboardingMoveKind.pop:
      router.pop();
    case OnboardingMoveKind.go:
      router.go(move.location!);
  }
}
