import 'package:critalarm/features/in_app_notices/domain/cancel_question/cancel_question_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The store's expiry, as the instant RevenueCat gives it.
  final endsAt = DateTime.parse('2026-10-20T09:15:02Z');

  test('is due when nothing was asked yet', () {
    expect(
      CancelQuestionRule.isDue(endsAtInstant: endsAt, askedFor: null),
      isTrue,
    );
  });

  test('the key is the UTC date of the instant', () {
    expect(CancelQuestionRule.keyFor(endsAt), '2026-10-20');
  });

  test('is asked once per end date', () {
    final key = CancelQuestionRule.keyFor(endsAt);
    expect(
      CancelQuestionRule.isDue(endsAtInstant: endsAt, askedFor: key),
      isFalse,
    );
    // The same UTC day at another time, and a second of drift, is the same key.
    expect(
      CancelQuestionRule.isDue(
        endsAtInstant: DateTime.parse('2026-10-20T23:59:59Z'),
        askedFor: key,
      ),
      isFalse,
    );
    expect(
      CancelQuestionRule.isDue(
        endsAtInstant: endsAt.add(const Duration(seconds: 1)),
        askedFor: key,
      ),
      isFalse,
    );
  });

  test('the same expiry read in two time zones is one key', () {
    final manila = DateTime.parse('2026-10-20T17:15:02+08:00');
    final newYork = DateTime.parse('2026-10-20T05:15:02-04:00');
    expect(manila.isAtSameMomentAs(newYork), isTrue);
    expect(
      CancelQuestionRule.keyFor(manila),
      CancelQuestionRule.keyFor(newYork),
    );
    // Even an instant that falls on another calendar day where the phone is.
    expect(
      CancelQuestionRule.keyFor(DateTime.parse('2026-10-21T01:30:00+09:00')),
      '2026-10-20',
    );
  });

  test('is asked again after a new cancel, which has a new end date', () {
    final old = CancelQuestionRule.keyFor(endsAt);
    expect(
      CancelQuestionRule.isDue(
        endsAtInstant: DateTime.parse('2026-11-20T09:15:02Z'),
        askedFor: old,
      ),
      isTrue,
    );
  });

  test('is not due while a billing issue is on record', () {
    expect(
      CancelQuestionRule.isDue(
        endsAtInstant: endsAt,
        askedFor: null,
        hasBillingIssue: true,
      ),
      isFalse,
    );
  });

  test('three retries at most', () {
    expect(CancelQuestionRule.maxRetries, 3);
  });
}
