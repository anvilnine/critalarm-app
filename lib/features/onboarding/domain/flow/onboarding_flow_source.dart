import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_validator.dart';
import 'package:flutter/foundation.dart';

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

/// Which source a flow came from.
enum OnboardingFlowOrigin { developer, remote, bundled }

/// The priority order of the origins. [chooseOnboardingFlowWithOrigin] and
/// the engine read their sources in this order unless told otherwise.
const List<OnboardingFlowOrigin> defaultOnboardingFlowOrigins = [
  OnboardingFlowOrigin.developer,
  OnboardingFlowOrigin.remote,
  OnboardingFlowOrigin.bundled,
];

/// A flow that passed the validator, and the source that gave it.
@immutable
class ChosenOnboardingFlow {
  const ChosenOnboardingFlow(this.flow, this.origin);

  final OnboardingFlow flow;
  final OnboardingFlowOrigin origin;
}

/// Asks each of [sources] in order and returns the first flow that passes
/// the validator. When none does, [fallback] runs.
OnboardingFlow chooseOnboardingFlow(
  Iterable<OnboardingFlowSource> sources, {
  required Map<String, Set<String>> requires,
  OnboardingFlow fallback = BundledOnboardingFlows.defaultFlow,
}) => chooseOnboardingFlowWithOrigin(
  sources,
  requires: requires,
  fallback: fallback,
).flow;

/// Like [chooseOnboardingFlow], and says which source won. [origins] lines up
/// with [sources] by position. A source past the end of [origins] counts as
/// bundled, and so does the [fallback].
ChosenOnboardingFlow chooseOnboardingFlowWithOrigin(
  Iterable<OnboardingFlowSource> sources, {
  required Map<String, Set<String>> requires,
  List<OnboardingFlowOrigin> origins = defaultOnboardingFlowOrigins,
  OnboardingFlow fallback = BundledOnboardingFlows.defaultFlow,
}) {
  var index = 0;
  for (final source in sources) {
    final origin = index < origins.length
        ? origins[index]
        : OnboardingFlowOrigin.bundled;
    index++;
    final candidate = source.current();
    if (candidate == null) continue;
    final valid = validateOnboardingFlow(candidate, requires: requires);
    if (valid != null) return ChosenOnboardingFlow(valid, origin);
  }
  return ChosenOnboardingFlow(fallback, OnboardingFlowOrigin.bundled);
}
