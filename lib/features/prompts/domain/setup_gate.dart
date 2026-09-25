/// Onboarding and the "How to use the app" guides come before every ask: the
/// Pro sheet, the Reminders sheet, the consent sheet, the store review popup,
/// and every planned reminder. The demo alarm at the end of onboarding used
/// to trigger one.
///
/// Setup is done once onboarding is finished and the first guide (Topics,
/// shown straight after onboarding) was seen or skipped. Every other screen
/// has its own guide the first time it opens; while any guide is up, setup
/// counts as not done, so nothing shows over it and nothing is planned. The
/// asks show after it instead.
///
/// Reads through the callbacks it is given, so it tests without storage.
/// Every ask rule takes the answer as `isSetupDone`.
class SetupGate {
  SetupGate({
    required Future<bool> Function() isOnboardingDone,
    required bool Function() hasSeenTour,
    bool Function()? isTourActive,
  }) : // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _isOnboardingDone = isOnboardingDone,
       // Same reason as above.
       // ignore: prefer_initializing_formals
       _hasSeenTour = hasSeenTour,
       _isTourActive = isTourActive ?? _never;

  final Future<bool> Function() _isOnboardingDone;
  final bool Function() _hasSeenTour;
  final bool Function() _isTourActive;

  static bool _never() => false;

  /// True once onboarding is finished and the first guide was seen or
  /// skipped, and no guide is on screen or about to be.
  Future<bool> isDone() async =>
      !_isTourActive() && _hasSeenTour() && await _isOnboardingDone();
}
