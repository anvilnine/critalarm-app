import 'package:critalarm/features/prompts/data/repositories/shared_prefs_home_prompt_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
}
