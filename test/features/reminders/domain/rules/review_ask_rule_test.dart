import 'package:critalarm/features/reminders/domain/reminder_args.dart';
import 'package:critalarm/features/reminders/domain/reminder_ids.dart';
import 'package:critalarm/features/reminders/domain/reminder_inputs.dart';
import 'package:critalarm/features/reminders/domain/rules/review_ask_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ack = DateTime(2026, 9, 20, 23);

  ReminderInputs inputs({
    DateTime? now,
    DateTime? installedAt,
    DateTime? reviewAskedAt,
    int reviewAskCount = 0,
    DateTime? lastAck,
    bool isIos = false,
    String appStoreId = '',
    DateTime? lastTestFailedAt,
    List<ReminderIncident> incidents = const [],
    DateTime? feedbackAskedAt,
  }) => ReminderInputs(
    now: now ?? DateTime(2026, 9, 21, 12),
    installedAt: installedAt ?? DateTime(2026, 9, 1, 9),
    consentAskedAt: DateTime(2026, 9, 2),
    reviewAskedAt: reviewAskedAt,
    reviewAskCount: reviewAskCount,
    lastAcknowledgedAt: lastAck ?? ack,
    isIos: isIos,
    appStoreId: appStoreId,
    lastTestFailedAt: lastTestFailedAt,
    incidents: incidents,
    feedbackAskedAt: feedbackAskedAt,
  );

  test('plans 10:00 four days after the last ack', () {
    final c = ReviewAskRule.candidate(inputs())!;
    expect(c.id, ReminderIds.reviewAsk);
    expect(c.fireAt, DateTime(2026, 9, 24, 10));
    expect(c.args[ReminderArgs.pool], '0');
  });

  test('says no when HomeAskRules would not ask for a review then', () {
    // Installed after the ack, so under 3 days old at the fire time.
    expect(
      ReviewAskRule.candidate(inputs(installedAt: DateTime(2026, 9, 22))),
      isNull,
    );
    // Three asks used.
    expect(ReviewAskRule.candidate(inputs(reviewAskCount: 3)), isNull);
    // Asked 85 days ago, inside the 120 day wait.
    expect(
      ReviewAskRule.candidate(
        inputs(reviewAskedAt: DateTime(2026, 7), reviewAskCount: 1),
      ),
      isNull,
    );
    // Asked after the last ack: no new ack since.
    expect(
      ReviewAskRule.candidate(
        inputs(reviewAskedAt: DateTime(2026, 9, 20, 23, 30), reviewAskCount: 1),
      ),
      isNull,
    );
  });

  test('skips a fire time that already passed', () {
    expect(
      ReviewAskRule.candidate(inputs(lastAck: DateTime(2026, 9, 10))),
      isNull,
    );
  });

  test('iOS waits for the App Store id', () {
    expect(ReviewAskRule.candidate(inputs(isIos: true)), isNull);
    expect(
      ReviewAskRule.candidate(inputs(isIos: true, appStoreId: '6700000000')),
      isNotNull,
    );
  });

  test('skips after a failed test since the ack', () {
    expect(
      ReviewAskRule.candidate(
        inputs(lastTestFailedAt: DateTime(2026, 9, 21, 8)),
      ),
      isNull,
    );
  });

  test('skips while an incident is open or acked', () {
    expect(
      ReviewAskRule.candidate(
        inputs(
          incidents: const [
            ReminderIncident(id: 'i', topic: 'prod-db', isOpenOrAcked: true),
          ],
        ),
      ),
      isNull,
    );
  });

  test('skips with a ring in the 24 hours before the fire time', () {
    expect(
      ReviewAskRule.candidate(
        inputs(
          incidents: [
            ReminderIncident(
              id: 'i',
              topic: 'prod-db',
              openedAt: DateTime(2026, 9, 23, 15),
            ),
          ],
        ),
      ),
      isNull,
    );
  });

  test('skips within 7 days of a feedback ask', () {
    expect(
      ReviewAskRule.candidate(inputs(feedbackAskedAt: DateTime(2026, 9, 20))),
      isNull,
    );
  });

  test('alternates the two lines with the ask count', () {
    final c = ReviewAskRule.candidate(
      inputs(reviewAskedAt: DateTime(2026, 4), reviewAskCount: 1),
    )!;
    expect(c.args[ReminderArgs.pool], '1');
  });
}
