import 'package:critalarm/features/reminders/domain/reminder_args.dart';
import 'package:critalarm/features/reminders/domain/reminder_ids.dart';
import 'package:critalarm/features/reminders/domain/reminder_inputs.dart';
import 'package:critalarm/features/reminders/domain/rules/backup_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final topics = [
    ReminderTopic(name: 'prod-db', createdAt: DateTime(2026, 9)),
    ReminderTopic(name: 'db-2', createdAt: DateTime(2026, 9, 10)),
  ];

  ReminderInputs inputs({
    DateTime? now,
    bool isHosted = true,
    bool isSelfHosted = false,
    bool isSignedIn = false,
    List<ReminderTopic>? list,
    DateTime? dismissedAt,
  }) => ReminderInputs(
    now: now ?? DateTime(2026, 9, 12),
    isHosted: isHosted,
    isSelfHosted: isSelfHosted,
    isSignedIn: isSignedIn,
    topics: list ?? topics,
    accountPromptDismissedAt: dismissedAt,
  );

  test('plans 10:00 seven days after the second topic', () {
    final c = BackupRule.candidate(inputs())!;
    expect(c.id, ReminderIds.backup);
    expect(c.fireAt, DateTime(2026, 9, 17, 10));
    expect(c.args[ReminderArgs.count], '2');
  });

  test('needs a signed-out hosted phone with two topics', () {
    expect(BackupRule.candidate(inputs(isSignedIn: true)), isNull);
    expect(
      BackupRule.candidate(inputs(isHosted: false, isSelfHosted: true)),
      isNull,
    );
    expect(BackupRule.candidate(inputs(list: [topics.first])), isNull);
  });

  test('shares the home card snooze', () {
    final c = BackupRule.candidate(
      inputs(dismissedAt: DateTime(2026, 9, 16, 8)),
    )!;
    expect(c.fireAt, DateTime(2026, 9, 23, 10));
  });

  test('a due day that passed moves to the next 10:00', () {
    final c = BackupRule.candidate(inputs(now: DateTime(2026, 9, 20, 12)))!;
    expect(c.fireAt, DateTime(2026, 9, 21, 10));
  });
}
