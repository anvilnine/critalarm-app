import 'package:critalarm/features/prompts/data/repositories/shared_prefs_home_prompt_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('Pro ending storage round-trips', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SharedPrefsHomePromptRepository(
      await SharedPreferences.getInstance(),
    );
    expect(repo.getProEndingSheetShownFor(), isNull);
    await repo.markProEndingSheetShown('2026-10-20');
    expect(repo.getProEndingSheetShownFor(), '2026-10-20');

    await repo.dismissProEndingPill();
    expect(repo.getProEndingPillDismissedAt(), isNotNull);

    await repo.markProEndingLastDaysDismissed('2026-10-20');
    expect(repo.getProEndingLastDaysDismissedFor(), '2026-10-20');

    final at = DateTime(2026, 10, 20, 9);
    await repo.setProKnownExpiry(at);
    expect(repo.getProKnownExpiry(), at);

    await repo.setProPaidAccountId('acc_1');
    expect(repo.getProPaidAccountId(), 'acc_1');
    await repo.setProPaidAccountId(null);
    expect(repo.getProPaidAccountId(), isNull);

    expect(repo.getProEndedSheetDueFor(), isNull);
    await repo.setProEndedSheetDueFor('acc_1');
    expect(repo.getProEndedSheetDueFor(), 'acc_1');
    await repo.setProEndedSheetDueFor(null);
    expect(repo.getProEndedSheetDueFor(), isNull);
  });

  late SharedPrefsHomePromptRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = SharedPrefsHomePromptRepository(
      await SharedPreferences.getInstance(),
    );
  });

  test('starts with nothing stamped', () {
    expect(repository.getFirstSeenAt(), isNull);
    expect(repository.getConsentAskedAt(), isNull);
    expect(repository.getReviewAskedAt(), isNull);
    expect(repository.getReviewAskCount(), 0);
    expect(repository.getLastAcknowledgedAt(), isNull);
  });

  test('markFirstSeen keeps the first stamp', () async {
    SharedPreferences.setMockInitialValues({
      'home_prompt_first_seen_at': DateTime(2026, 9).millisecondsSinceEpoch,
    });
    repository = SharedPrefsHomePromptRepository(
      await SharedPreferences.getInstance(),
    );

    await repository.markFirstSeen();

    expect(repository.getFirstSeenAt(), DateTime(2026, 9));
  });

  test('markFirstSeen stamps an empty store', () async {
    await repository.markFirstSeen();
    expect(repository.getFirstSeenAt(), isNotNull);
  });

  test('markConsentAsked stamps the time', () async {
    await repository.markConsentAsked();
    expect(repository.getConsentAskedAt(), isNotNull);
  });

  test('markReviewAsked stamps the time and counts', () async {
    await repository.markReviewAsked();
    await repository.markReviewAsked();
    expect(repository.getReviewAskedAt(), isNotNull);
    expect(repository.getReviewAskCount(), 2);
  });

  test('markAcknowledged stamps the time', () async {
    await repository.markAcknowledged();
    expect(repository.getLastAcknowledgedAt(), isNotNull);
  });

  test('markReviewAsked keeps the time it is given', () async {
    await repository.markReviewAsked(at: DateTime(2026, 9, 24, 10));
    expect(repository.getReviewAskedAt(), DateTime(2026, 9, 24, 10));
    expect(repository.getReviewAskCount(), 1);
  });

  test('markFeedbackAsked stamps once and reads back', () async {
    expect(repository.getFeedbackAskedAt(), isNull);
    await repository.markFeedbackAsked(at: DateTime(2026, 10, 1, 10));
    expect(repository.getFeedbackAskedAt(), DateTime(2026, 10, 1, 10));
  });

  test('"Remind me later" never counts as a "Not now"', () async {
    await repository.remindProPromptLater();
    await repository.remindProPromptLater();
    expect(repository.getProPromptLaterAt(), isNotNull);
    expect(repository.getProPromptDismissCount(), 0);
    await repository.clearProPromptLater();
    expect(repository.getProPromptLaterAt(), isNull);
  });
}
