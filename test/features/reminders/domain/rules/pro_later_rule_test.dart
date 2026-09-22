import 'package:critalarm/features/reminders/domain/reminder_ids.dart';
import 'package:critalarm/features/reminders/domain/reminder_inputs.dart';
import 'package:critalarm/features/reminders/domain/rules/pro_later_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 22);

  test('comes back at the first 10:00 thirty days later', () {
    final c = ProLaterRule.candidate(
      ReminderInputs(now: now, proLaterAt: DateTime(2026, 9, 1, 12)),
    )!;
    expect(c.id, ReminderIds.proLater);
    expect(c.fireAt, DateTime(2026, 10, 2, 10));
  });

  test('nothing without a "Remind me later"', () {
    expect(ProLaterRule.candidate(ReminderInputs(now: now)), isNull);
  });

  test('nothing for somebody who pays or said no twice', () {
    expect(
      ProLaterRule.candidate(
        ReminderInputs(now: now, proLaterAt: DateTime(2026, 9), isPaid: true),
      ),
      isNull,
    );
    expect(
      ProLaterRule.candidate(
        ReminderInputs(
          now: now,
          proLaterAt: DateTime(2026, 9),
          proDismissCount: 2,
        ),
      ),
      isNull,
    );
  });
}
