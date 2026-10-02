import 'package:critalarm/features/local_reminders/domain/local_reminder_args.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_ids.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_inputs.dart';
import 'package:critalarm/features/local_reminders/domain/rules/backup_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final topics = [
    LocalReminderTopic(name: 'prod-db', createdAt: DateTime(2026, 9)),
    LocalReminderTopic(name: 'db-2', createdAt: DateTime(2026, 9, 10)),
  ];

  LocalReminderInputs inputs({
    DateTime? now,
    bool isHosted = true,
    bool isSelfHosted = false,
    bool isSignedIn = false,
    List<LocalReminderTopic>? list,
    DateTime? dismissedAt,
    DateTime? firstTopicAt,
    bool noFirstTopic = false,
  }) => LocalReminderInputs(
    now: now ?? DateTime(2026, 9, 12),
    isHosted: isHosted,
    isSelfHosted: isSelfHosted,
    isSignedIn: isSignedIn,
    topics: list ?? topics,
    accountNoticeDismissedAt: dismissedAt,
    firstTopicOwnedAt: noFirstTopic ? null : firstTopicAt ?? DateTime(2026, 9),
  );

  test('plans 10:00 seven days after the second topic', () {
    final c = BackupRule.candidate(inputs())!;
    expect(c.id, LocalReminderIds.backup);
    expect(c.fireAt, DateTime(2026, 9, 17, 10));
    expect(c.args[LocalReminderArgs.count], '2');
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

  test('waits a day after the first topic was stamped', () {
    final c = BackupRule.candidate(
      inputs(
        now: DateTime(2026, 9, 12),
        firstTopicAt: DateTime(2026, 9, 16, 12),
      ),
    )!;
    // Seven days after the second topic is 17 Sep 00:00, but a day after
    // the stamp is 17 Sep 12:00, so the next 10:00 is 18 Sep.
    expect(c.fireAt, DateTime(2026, 9, 18, 10));
  });

  test('plans nothing until the first topic has been seen', () {
    expect(BackupRule.candidate(inputs(noFirstTopic: true)), isNull);
  });
}
