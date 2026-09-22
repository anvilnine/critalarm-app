/// Onboarding and the "How to use the app" tour come before every ask: the
/// Pro sheet, the Reminders sheet, the consent sheet and the store review
/// popup. The demo alarm at the end of onboarding used to trigger one.
///
/// Reads through the two callbacks it is given, so it tests without
/// storage. Every ask rule takes the answer as `isSetupDone`.
class SetupGate {
  SetupGate({
    required Future<bool> Function() isOnboardingDone,
    required bool Function() hasSeenTour,
  }) : // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _isOnboardingDone = isOnboardingDone,
       // Same reason as above.
       // ignore: prefer_initializing_formals
       _hasSeenTour = hasSeenTour;

  final Future<bool> Function() _isOnboardingDone;
  final bool Function() _hasSeenTour;

  /// True once onboarding is finished and the tour was seen or skipped.
  Future<bool> isDone() async => await _isOnboardingDone() && _hasSeenTour();
}
