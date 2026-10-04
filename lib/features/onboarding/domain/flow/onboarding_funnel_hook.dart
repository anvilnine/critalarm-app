import 'package:critalarm/core/telemetry/onboarding_funnel.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_engine.dart';

/// Hands a step the engine reported to the funnel: an opened step is a view,
/// a finished one is a completion. The funnel itself drops a replay.
Future<void> reportStepToFunnel(
  OnboardingFunnel funnel,
  OnboardingStepEvent event,
) => switch (event.kind) {
  OnboardingStepEventKind.entered => funnel.stepViewed(
    event.stepId,
    event.flowId,
    isReplay: event.isReplay,
  ),
  OnboardingStepEventKind.finished => funnel.stepCompleted(
    event.stepId,
    event.flowId,
    isReplay: event.isReplay,
  ),
};
