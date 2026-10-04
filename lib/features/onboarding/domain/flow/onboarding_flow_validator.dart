import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';

/// Checks a flow from any source. Returns the flow to run, or null when the
/// whole flow is rejected and the next source should be asked.
///
/// [requires] maps every step id the app knows to the ids that must come
/// before it.
///
/// - An id the app does not know is dropped.
/// - A second copy of an id is dropped, so the first position wins.
/// - Nothing left, `welcome` not first, or a step listed before one it
///   requires (or without it): rejected.
OnboardingFlow? validateOnboardingFlow(
  OnboardingFlow candidate, {
  required Map<String, Set<String>> requires,
}) {
  final steps = <String>[];
  for (final step in candidate.steps) {
    if (!requires.containsKey(step)) continue;
    if (steps.contains(step)) continue;
    steps.add(step);
  }
  if (steps.isEmpty) return null;
  if (steps.first != OnboardingStepId.welcome) return null;

  final seen = <String>{};
  for (final step in steps) {
    if (!seen.containsAll(requires[step]!)) return null;
    seen.add(step);
  }
  return OnboardingFlow(id: candidate.id, steps: List.unmodifiable(steps));
}
