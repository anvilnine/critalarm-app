import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_validator.dart';

/// One place a flow can come from.
// ignore: one_member_abstracts
abstract interface class OnboardingFlowSource {
  /// The flow this source has in hand right now, or null when it has none.
  ///
  /// Never waits. A source that fetches its value answers null until the
  /// value has arrived.
  OnboardingFlow? current();
}

/// The names the two overriding sources are registered under in the
/// composition root, so each can be swapped in without touching the lookup.
const developerOnboardingFlowSource = 'onboardingFlowSource.developer';
const remoteOnboardingFlowSource = 'onboardingFlowSource.remote';

/// A source with nothing to say. Holds a slot in the lookup order until the
/// real source is registered in its place.
class EmptyOnboardingFlowSource implements OnboardingFlowSource {
  const EmptyOnboardingFlowSource();

  @override
  OnboardingFlow? current() => null;
}

/// The default flow that ships inside the app.
class BundledOnboardingFlowSource implements OnboardingFlowSource {
  const BundledOnboardingFlowSource();

  @override
  OnboardingFlow? current() => BundledOnboardingFlows.defaultFlow;
}

/// Asks each of [sources] in order and returns the first flow that passes
/// the validator. When none does, [fallback] runs.
OnboardingFlow chooseOnboardingFlow(
  Iterable<OnboardingFlowSource> sources, {
  required Map<String, Set<String>> requires,
  OnboardingFlow fallback = BundledOnboardingFlows.defaultFlow,
}) {
  for (final source in sources) {
    final candidate = source.current();
    if (candidate == null) continue;
    final valid = validateOnboardingFlow(candidate, requires: requires);
    if (valid != null) return valid;
  }
  return fallback;
}
