import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow.dart';
import 'package:critalarm/features/onboarding/domain/flow/onboarding_flow_validator.dart';
import 'package:flutter/foundation.dart';

/// Why the validator turned a typed step list down.
enum DeveloperStepListProblem {
  /// Nothing was left once unknown ids were dropped.
  empty,

  /// The first step is not `welcome`.
  welcomeNotFirst,

  /// A step comes before one it requires, or the required step is missing.
  orderBroken,
}

/// What came of a step list typed into developer settings.
@immutable
class DeveloperStepListResult {
  const DeveloperStepListResult({
    required this.typed,
    required this.unknown,
    required this.duplicates,
    this.flow,
    this.problem,
    this.problemStep,
    this.missingStep,
  });

  /// Every id in the text, trimmed, in the order typed. Empty items are gone.
  final List<String> typed;

  /// Ids the app does not know. The validator drops them.
  final List<String> unknown;

  /// Ids typed more than once. The validator keeps the first.
  final List<String> duplicates;

  /// The flow the validator accepted, or null when it rejected the list.
  final OnboardingFlow? flow;

  /// Set when [flow] is null.
  final DeveloperStepListProblem? problem;

  /// For [DeveloperStepListProblem.welcomeNotFirst], the step in first place.
  /// For [DeveloperStepListProblem.orderBroken], the step that has to wait.
  final String? problemStep;

  /// For [DeveloperStepListProblem.orderBroken], the step that is not before
  /// [problemStep].
  final String? missingStep;

  bool get isAccepted => flow != null;
}

/// The id of the flow a typed list becomes.
const developerCustomFlowId = 'custom';

/// Splits [text] on commas, drops empty items, and trims every id.
List<String> splitDeveloperStepList(String text) => [
  for (final part in text.split(','))
    if (part.trim().isNotEmpty) part.trim(),
];

/// Reads a typed step list the way the validator will, and says what it did.
///
/// [requires] is the same map the validator gets: every step id the app
/// knows, mapped to the ids that must come before it.
DeveloperStepListResult parseDeveloperStepList(
  String text, {
  required Map<String, Set<String>> requires,
}) {
  final typed = splitDeveloperStepList(text);
  final unknown = <String>[];
  final duplicates = <String>[];
  final kept = <String>[];
  for (final id in typed) {
    if (!requires.containsKey(id)) {
      if (!unknown.contains(id)) unknown.add(id);
    } else if (kept.contains(id)) {
      if (!duplicates.contains(id)) duplicates.add(id);
    } else {
      kept.add(id);
    }
  }

  final flow = validateOnboardingFlow(
    OnboardingFlow(id: developerCustomFlowId, steps: typed),
    requires: requires,
  );
  if (flow != null) {
    return DeveloperStepListResult(
      typed: typed,
      unknown: unknown,
      duplicates: duplicates,
      flow: flow,
    );
  }

  // The validator says no and nothing more, so find the reason in the same
  // order it checks them.
  DeveloperStepListProblem problem;
  String? problemStep;
  String? missingStep;
  if (kept.isEmpty) {
    problem = DeveloperStepListProblem.empty;
  } else if (kept.first != OnboardingStepId.welcome) {
    problem = DeveloperStepListProblem.welcomeNotFirst;
    problemStep = kept.first;
  } else {
    problem = DeveloperStepListProblem.orderBroken;
    final seen = <String>{};
    for (final step in kept) {
      final missing = requires[step]!.where((id) => !seen.contains(id));
      if (missing.isNotEmpty) {
        problemStep = step;
        missingStep = missing.first;
        break;
      }
      seen.add(step);
    }
  }
  return DeveloperStepListResult(
    typed: typed,
    unknown: unknown,
    duplicates: duplicates,
    problem: problem,
    problemStep: problemStep,
    missingStep: missingStep,
  );
}
