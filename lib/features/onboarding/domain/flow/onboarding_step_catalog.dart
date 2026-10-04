/// What the flow engine needs to know about the steps, without knowing the
/// screens. The step registry implements it.
abstract interface class OnboardingStepCatalog {
  /// Every step id the app knows, mapped to the ids that must come before it.
  Map<String, Set<String>> get requires;

  /// Whether the step exists on this phone. False for an unknown id and for
  /// a step with no screen.
  bool isAvailable(String stepId);

  /// Whether the step is already true for this user. Local reads only.
  Future<bool> isSatisfied(String stepId);

  /// The route of the step's screen, or null when it has none.
  String? routeOf(String stepId);
}
