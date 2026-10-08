import 'package:critalarm/app/di.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';
import 'package:critalarm/features/topics/domain/first_topic_handoff.dart';
import 'package:critalarm/features/topics/domain/setup_finish_glow.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Whether [uri] is a replay from Settings: a look at the screens, where
/// nothing is saved.
bool isOnboardingReplayUri(Uri uri) => uri.queryParameters['demo'] == 'true';

bool isOnboardingReplay(BuildContext context) =>
    isOnboardingReplayUri(GoRouterState.of(context).uri);

/// Whether [uri] was opened by Back: the user has been on this step before
/// and came back to it. The step then shows what they chose instead of
/// moving on by itself.
bool isOnboardingCameBackUri(Uri uri) => uri.queryParameters['back'] == 'true';

bool isOnboardingCameBack(BuildContext context) =>
    isOnboardingCameBackUri(GoRouterState.of(context).uri);

/// Where Back opens the step at [route]. The replay flag carries on.
String onboardingBackLocation(String route, {required bool isReplay}) => Uri(
  path: route,
  queryParameters: {'back': 'true', if (isReplay) 'demo': 'true'},
).toString();

/// Moves the step on screen out of the way, towards the start for a step
/// forward and towards the end for Back. Completes once it is gone, and at
/// once when the phone asks for reduced motion.
///
/// The setup shell on screen hands its own over with
/// [attachOnboardingStepLeave], so a step change started from anywhere, a
/// sheet above the router included, moves the old step out before the new
/// one comes in.
typedef OnboardingStepLeave = Future<void> Function({required bool isBack});

OnboardingStepLeave? _leaveStep;

void attachOnboardingStepLeave(OnboardingStepLeave leave) => _leaveStep = leave;

void detachOnboardingStepLeave(OnboardingStepLeave leave) {
  if (_leaveStep == leave) _leaveStep = null;
}

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
///
/// [skippedItself] is for a step that moved on with nothing for the user to
/// do. Back never opens such a step.
Future<void> finishOnboardingStep(
  BuildContext context,
  String stepId, {
  bool skippedItself = false,
}) => finishOnboardingStepOn(
  GoRouter.of(context),
  stepId,
  isReplay: isOnboardingReplay(context),
  skippedItself: skippedItself,
);

/// [finishOnboardingStep] for a caller with no screen under it, such as the
/// connect sheet, which opens above the router.
Future<void> finishOnboardingStepOn(
  GoRouter router,
  String stepId, {
  required bool isReplay,
  bool skippedItself = false,
}) async {
  Uri location() => router.routerDelegate.currentConfiguration.uri;
  final locationBefore = location();
  final next = await finishOnboardingStepInEngine(
    stepId,
    isReplay: isReplay,
    skippedItself: skippedItself,
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
      final next = move.location!;
      // Only a move to another setup step has a step to slide out for.
      if (next.startsWith('/onboarding')) {
        await _leaveStep?.call(isBack: false);
      }
      router.go(next);
  }
}

/// Finishes [stepId] in the flow engine and navigates nowhere.
///
/// When that was the last step of a real run, setup is over and Home opens
/// next. Home is told which topic setup made, so it can point at it once
/// (`setupFinishSignal`). The signal is held in memory only. A replay, a
/// screen opened after setup, and a run that made no topic raise nothing.
Future<OnboardingDestination> finishOnboardingStepInEngine(
  String stepId, {
  required bool isReplay,
  bool skippedItself = false,
}) async {
  // Read before the engine answers: completing setup forgets the name.
  final firstTopicName = getIt.isRegistered<FirstTopicHandoff>()
      ? getIt<FirstTopicHandoff>().savedTopicName
      : null;
  final next = await getIt<OnboardingFlowEngine>().finishStep(
    stepId,
    isReplay: isReplay,
    skippedItself: skippedItself,
  );
  final glowTopic = setupGlowTopicFor(
    endedSetup: next.isHome,
    isReplay: isReplay,
    firstTopicName: firstTopicName,
  );
  if (glowTopic != null) setupFinishSignal.raise(glowTopic);
  return next;
}

/// Back from the step [stepId]: opens the step the flow engine says Back
/// goes to. Returns false, and moves nowhere, when Back is not offered
/// there or the user has already gone somewhere else.
///
/// On a replay nothing is saved.
Future<bool> goBackInOnboarding(
  GoRouter router,
  String stepId, {
  required bool isReplay,
}) async {
  Uri location() => router.routerDelegate.currentConfiguration.uri;
  final locationBefore = location();
  final back = await getIt<OnboardingFlowEngine>().goBack(
    stepId,
    isReplay: isReplay,
  );
  final route = back?.route;
  if (route == null || locationBefore != location()) return false;
  await _leaveStep?.call(isBack: true);
  router.go(onboardingBackLocation(route, isReplay: isReplay));
  return true;
}
