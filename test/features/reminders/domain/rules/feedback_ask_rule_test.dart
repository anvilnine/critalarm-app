import 'package:critalarm/features/reminders/domain/reminder_ids.dart';
import 'package:critalarm/features/reminders/domain/reminder_inputs.dart';
import 'package:critalarm/features/reminders/domain/rules/feedback_ask_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const form = 'https://forms.zonily.cloud/form/f1';

  ReminderInputs inputs({
    DateTime? now,
    DateTime? installedAt,
    DateTime? lastAck,
    bool noAck = false,
    Map<String, DateTime> lastTestAt = const {},
    DateTime? feedbackAskedAt,
    DateTime? reviewAskedAt,
    String url = form,
    List<ReminderIncident> incidents = const [],
    DateTime? lastTestFailedAt,
  }) => ReminderInputs(
    now: now ?? DateTime(2026, 9, 10, 12),
    // Tuesday 1 September, so day 21 is Tuesday 22 September.
    installedAt: installedAt ?? DateTime(2026, 9, 1, 9),
    lastAcknowledgedAt: noAck ? null : (lastAck ?? DateTime(2026, 9, 5)),
    lastTestAt: lastTestAt,
    feedbackAskedAt: feedbackAskedAt,
    reviewAskedAt: reviewAskedAt,
    feedbackFormUrl: url,
    incidents: incidents,
    lastTestFailedAt: lastTestFailedAt,
  );

  test('plans the first Tuesday to Thursday on or after day 21', () {
    final c = FeedbackAskRule.candidate(inputs())!;
    expect(c.id, ReminderIds.feedbackAsk);
    expect(c.fireAt, DateTime(2026, 9, 22, 10));

    // Installed on a Thursday: day 21 is a Thursday.
    expect(
      FeedbackAskRule.candidate(
        inputs(installedAt: DateTime(2026, 9, 3)),
      )!.fireAt,
      DateTime(2026, 9, 24, 10),
    );
    // Installed on a Friday: day 21 is a Friday, so the next Tuesday.
    expect(
      FeedbackAskRule.candidate(
        inputs(installedAt: DateTime(2026, 9, 4)),
      )!.fireAt,
      DateTime(2026, 9, 29, 10),
    );
  });

  test('needs an ack or a test', () {
    expect(FeedbackAskRule.candidate(inputs(noAck: true)), isNull);
    expect(
      FeedbackAskRule.candidate(
        inputs(noAck: true, lastTestAt: {'prod-db': DateTime(2026, 9, 5)}),
      ),
      isNotNull,
    );
  });

  test('asks once per install', () {
    expect(
      FeedbackAskRule.candidate(inputs(feedbackAskedAt: DateTime(2026, 9))),
      isNull,
    );
  });

  test('never plans while the form link is blank', () {
    expect(FeedbackAskRule.candidate(inputs(url: '')), isNull);
  });

  test('moves past a pending review ask', () {
    final c = FeedbackAskRule.candidate(
      inputs(),
      pendingReviewAt: DateTime(2026, 9, 24, 10),
    )!;
    expect(c.fireAt, DateTime(2026, 10, 1, 10));
  });

  test('keeps 7 days from a review ask the home popup made', () {
    final c = FeedbackAskRule.candidate(
      inputs(reviewAskedAt: DateTime(2026, 9, 20, 12)),
    )!;
    expect(c.fireAt, DateTime(2026, 9, 29, 10));
  });

  test('skips an open incident and a failed test since the last ack', () {
    expect(
      FeedbackAskRule.candidate(
        inputs(
          incidents: const [
            ReminderIncident(id: 'i', topic: 'prod-db', isOpenOrAcked: true),
          ],
        ),
      ),
      isNull,
    );
    expect(
      FeedbackAskRule.candidate(
        inputs(lastTestFailedAt: DateTime(2026, 9, 6)),
      ),
      isNull,
    );
  });

  test('moves a day when a ring landed in the 24 hours before', () {
    final c = FeedbackAskRule.candidate(
      inputs(
        incidents: [
          ReminderIncident(
            id: 'i',
            topic: 'prod-db',
            openedAt: DateTime(2026, 9, 21, 20),
          ),
        ],
      ),
    )!;
    expect(c.fireAt, DateTime(2026, 9, 23, 10));
  });

  test('past day 21 it takes the next allowed day', () {
    final c = FeedbackAskRule.candidate(
      inputs(now: DateTime(2026, 9, 30, 12)),
    )!;
    expect(c.fireAt, DateTime(2026, 10, 1, 10));
  });
}
