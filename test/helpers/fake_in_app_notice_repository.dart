import 'package:critalarm/features/in_app_notices/domain/repositories/in_app_notice_repository.dart';

/// One fake for every In-App Notices test. Every stamp is a public field and
/// every write uses [now], so a test can set the clock and read what was
/// written.
/// Call counters exist for tests that check a method fired, not just its
/// result.
class FakeInAppNoticeRepository implements InAppNoticeRepository {
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
  DateTime? getAccountNoticeDismissedAt() => accountDismissedAt;

  @override
  Future<void> dismissAccountNotice() async {
    dismissAccountCalls++;
    accountDismissedAt = now();
    await markNoticeResolvedOrDismissed();
  }

  @override
  DateTime? getProAskedAt() => proAskedAt;

  @override
  Future<void> markProAsked() async {
    proAskedAt = now();
  }

  @override
  DateTime? getProAskDismissedAt() => proDismissedAt;

  @override
  int getProAskDismissCount() => proDismissCount;

  @override
  Future<void> dismissProAsk() async {
    dismissProCalls++;
    proDismissCount++;
    proDismissedAt = now();
    // Walking away from the sheet is an ask too, so a bare dismiss in a
    // test still starts the quiet period without a separate
    // markProAsked call.
    proAskedAt = proDismissedAt;
    await markNoticeResolvedOrDismissed();
  }

  @override
  DateTime? getProAskLaterAt() => proLaterAt;

  @override
  Future<void> remindProAskLater() async {
    proLaterAt = now();
  }

  @override
  Future<void> clearProAskLater() async {
    proLaterAt = null;
  }

  @override
  DateTime? getLastNoticeResolvedOrDismissedAt() => lastResolvedAt;

  @override
  Future<void> markNoticeResolvedOrDismissed() async {
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

  DateTime? afterAckSheetShownAt;

  @override
  DateTime? getAfterAckSheetShownAt() => afterAckSheetShownAt;

  @override
  Future<void> markAfterAckSheetShown() async {
    afterAckSheetShownAt = now();
  }

  String? proEndingSheetFor;
  DateTime? proEndingPillDismissedAt;
  String? proEndingLastDaysFor;
  DateTime? proKnownExpiry;
  String? proPaidAccountId;
  String? proEndedDueFor;

  @override
  String? getProEndingSheetShownFor() => proEndingSheetFor;

  @override
  Future<void> markProEndingSheetShown(String key) async =>
      proEndingSheetFor = key;

  @override
  DateTime? getProEndingNoticeDismissedAt() => proEndingPillDismissedAt;

  @override
  Future<void> dismissProEndingNotice() async =>
      proEndingPillDismissedAt = now();

  @override
  String? getProEndingLastDaysDismissedFor() => proEndingLastDaysFor;

  @override
  Future<void> markProEndingLastDaysDismissed(String key) async =>
      proEndingLastDaysFor = key;

  @override
  DateTime? getProKnownExpiry() => proKnownExpiry;

  @override
  Future<void> setProKnownExpiry(DateTime at) async => proKnownExpiry = at;

  @override
  String? getProPaidAccountId() => proPaidAccountId;

  @override
  Future<void> setProPaidAccountId(String? accountId) async =>
      proPaidAccountId = accountId;

  @override
  String? getProEndedSheetDueFor() => proEndedDueFor;

  @override
  Future<void> setProEndedSheetDueFor(String? accountId) async =>
      proEndedDueFor = accountId;
}
