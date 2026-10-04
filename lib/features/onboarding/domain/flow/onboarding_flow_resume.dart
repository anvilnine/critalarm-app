/// The step a real run opens next: the first one in [steps] that is
/// available, not completed and not already true for this user. Null when
/// none is left, which means setup is complete.
Future<String?> firstOpenOnboardingStep(
  List<String> steps, {
  required Set<String> completed,
  required bool Function(String stepId) isAvailable,
  required Future<bool> Function(String stepId) isSatisfied,
}) async {
  for (final step in steps) {
    if (!isAvailable(step)) continue;
    if (completed.contains(step)) continue;
    if (await isSatisfied(step)) continue;
    return step;
  }
  return null;
}

/// The step a replay opens after [finished]: the next available one in the
/// list. A replay is a look at the screens, so no step is skipped for being
/// completed or already true. Null when [finished] was the last one, or is
/// not in the list.
String? nextReplayOnboardingStep(
  List<String> steps, {
  required String finished,
  required bool Function(String stepId) isAvailable,
}) {
  final at = steps.indexOf(finished);
  if (at < 0) return null;
  for (final step in steps.skip(at + 1)) {
    if (isAvailable(step)) return step;
  }
  return null;
}
