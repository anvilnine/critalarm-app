import 'package:critalarm/features/in_app_notices/domain/pro_ending_rule.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_inputs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final endsAt = DateTime(2026, 10, 20, 9);

  PlanStatus plan({bool active = true, bool renew = false, DateTime? at}) =>
      PlanStatus(
        isActive: active,
        isYearly: false,
        willRenew: renew,
        expiresAt: at ?? endsAt,
      );

  group('isCancelled', () {
    final now = DateTime(2026, 10);
    test('active, not renewing, ends later', () {
      expect(ProEndingRule.isCancelled(plan(), now), isTrue);
    });
    test('renewing is not cancelled', () {
      expect(ProEndingRule.isCancelled(plan(renew: true), now), isFalse);
    });
    test('a billing issue that still renews is not cancelled', () {
      final issue = PlanStatus(
        isActive: true,
        isYearly: false,
        willRenew: true,
        expiresAt: endsAt,
        billingIssueAt: now,
      );
      expect(ProEndingRule.isCancelled(issue, now), isFalse);
    });
    test('already ended is not cancelled', () {
      expect(ProEndingRule.isCancelled(plan(), endsAt), isFalse);
    });
    test('inactive is not cancelled', () {
      expect(ProEndingRule.isCancelled(plan(active: false), now), isFalse);
    });
  });

  group('shouldShowPill', () {
    bool show(
      DateTime now, {
      bool sheetShown = true,
      DateTime? dismissedAt,
      bool lastDaysDismissed = false,
    }) => ProEndingRule.shouldShowPill(
      now: now,
      endsAt: endsAt,
      sheetShown: sheetShown,
      pillDismissedAt: dismissedAt,
      lastDaysDismissed: lastDaysDismissed,
    );

    test('not before the sheet was shown', () {
      expect(show(DateTime(2026, 10), sheetShown: false), isFalse);
    });
    test('shows when never closed', () {
      expect(show(DateTime(2026, 10)), isTrue);
    });
    test('hidden for 5 days after a close', () {
      final closed = DateTime(2026, 10);
      expect(show(DateTime(2026, 10, 5, 23), dismissedAt: closed), isFalse);
      expect(show(DateTime(2026, 10, 6), dismissedAt: closed), isTrue);
    });
    test('the last 2 days bring it back inside the 5 days', () {
      final closed = DateTime(2026, 10, 17);
      expect(show(DateTime(2026, 10, 18, 9), dismissedAt: closed), isTrue);
    });
    test('closed in the last 2 days stays gone', () {
      expect(
        show(DateTime(2026, 10, 19), lastDaysDismissed: true),
        isFalse,
      );
    });
    test('never once Pro has ended', () {
      expect(show(endsAt), isFalse);
    });
  });
}
