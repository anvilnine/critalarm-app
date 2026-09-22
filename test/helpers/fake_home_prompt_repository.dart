import 'package:critalarm/features/prompts/domain/repositories/home_prompt_repository.dart';

/// One fake for every prompts test. Every stamp is a public field and every
/// write uses [now], so a test can set the clock and read what was written.
/// Call counters exist for tests that check a method fired, not just its
/// result.
class FakeHomePromptRepository implements HomePromptRepository {
  DateTime Function() now = DateTime.now;

  DateTime? accountDismissedAt;
  DateTime? proAskedAt;
  DateTime? proDismissedAt;
  int proDismissCount = 0;
  DateTime? proLaterAt;
  DateTime? lastResolvedAt;
  DateTime? firstSeenAt;
  DateTime? consentAskedAt;
  DateTime? reviewAskedAt;
  int reviewAskCount = 0;
  DateTime? feedbackAskedAt;
  DateTime? lastAcknowledgedAt;

  int dismissAccountCalls = 0;
  int dismissProCalls = 0;
  int markResolvedCalls = 0;

  @override
  DateTime? getAccountPromptDismissedAt() => accountDismissedAt;

  @override
  Future<void> dismissAccountPrompt() async {
    dismissAccountCalls++;
    accountDismissedAt = now();
    await markBannerResolvedOrDismissed();
  }

  @override
  DateTime? getProPromptAskedAt() => proAskedAt;

  @override
  Future<void> markProPromptAsked() async {
    proAskedAt = now();
  }

  @override
  DateTime? getProPromptDismissedAt() => proDismissedAt;

  @override
  int getProPromptDismissCount() => proDismissCount;

  @override
  Future<void> dismissProPrompt() async {
    dismissProCalls++;
    proDismissCount++;
    proDismissedAt = now();
    // Walking away from the sheet is an ask too, so a bare dismiss in a
    // test still starts the quiet period without a separate
    // markProPromptAsked call.
    proAskedAt = proDismissedAt;
    await markBannerResolvedOrDismissed();
  }

  @override
  DateTime? getProPromptLaterAt() => proLaterAt;

  @override
  Future<void> remindProPromptLater() async {
    proLaterAt = now();
  }

  @override
  Future<void> clearProPromptLater() async {
    proLaterAt = null;
  }

  @override
  DateTime? getLastBannerResolvedOrDismissedAt() => lastResolvedAt;

  @override
  Future<void> markBannerResolvedOrDismissed() async {
    markResolvedCalls++;
    lastResolvedAt = now();
  }

  @override
  DateTime? getFirstSeenAt() => firstSeenAt;

  @override
  Future<void> markFirstSeen() async {
    firstSeenAt ??= now();
  }

  @override
  DateTime? getConsentAskedAt() => consentAskedAt;

  @override
  Future<void> markConsentAsked() async {
    consentAskedAt = now();
  }

  @override
  DateTime? getReviewAskedAt() => reviewAskedAt;

  @override
  int getReviewAskCount() => reviewAskCount;

  @override
  Future<void> markReviewAsked({DateTime? at}) async {
    reviewAskedAt = at ?? now();
    reviewAskCount++;
  }

  @override
  DateTime? getFeedbackAskedAt() => feedbackAskedAt;

  @override
  Future<void> markFeedbackAsked({DateTime? at}) async {
    feedbackAskedAt = at ?? now();
  }

  @override
  DateTime? getLastAcknowledgedAt() => lastAcknowledgedAt;

  @override
  Future<void> markAcknowledged() async {
    lastAcknowledgedAt = now();
  }
}
