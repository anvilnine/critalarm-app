abstract class HomePromptRepository {
  DateTime? getAccountPromptDismissedAt();
  Future<void> dismissAccountPrompt();

  DateTime? getProPromptDismissedAt();
  Future<void> dismissProPrompt();

  DateTime? getLastBannerResolvedOrDismissedAt();
  Future<void> markBannerResolvedOrDismissed();
}
