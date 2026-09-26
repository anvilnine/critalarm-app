/// The one gate for everything that competes for the user's attention after
/// install. The order is:
///
/// 1. Onboarding, including the create-your-first-topic screens after the
///    demo alarm. No Feature Guide, notice, ask or Local Reminder.
/// 2. The Topics Feature Guide, the first time the user reaches Topics. It is
///    always the first guide (`FeatureGuideCubit.requestIfNew`).
/// 3. After it is seen or skipped: every other screen's guide on its first
///    visit, the In-App Notices, the asks (the Pro sheet, the Local reminders
///    sheet, the consent sheet, the store review popup) and every planned
///    Local Reminder.
///
/// Setup is done once onboarding is finished and the Topics guide was seen
/// or skipped. While any guide is up, setup counts as not done, so nothing
/// shows over it and nothing is planned. What was held back comes after it.
///
/// Reads through the callbacks it is given, so it tests without storage.
/// Every ask rule takes the answer as `isSetupDone`.
class SetupGate {
  SetupGate({
    required Future<bool> Function() isOnboardingDone,
    required bool Function() hasSeenFeatureGuide,
    bool Function()? isFeatureGuideActive,
  }) : // The fields are private and the parameters are public, so they
       // cannot be initializing formals.
       // ignore: prefer_initializing_formals
       _isOnboardingDone = isOnboardingDone,
       // Same reason as above.
       // ignore: prefer_initializing_formals
       _hasSeenFeatureGuide = hasSeenFeatureGuide,
       _isFeatureGuideActive = isFeatureGuideActive ?? _never;

  final Future<bool> Function() _isOnboardingDone;
  final bool Function() _hasSeenFeatureGuide;
  final bool Function() _isFeatureGuideActive;

  static bool _never() => false;

  /// True once onboarding is finished and the first guide was seen or
  /// skipped, and no guide is on screen or about to be.
  Future<bool> isDone() async =>
      !_isFeatureGuideActive() &&
      _hasSeenFeatureGuide() &&
      await _isOnboardingDone();
}
