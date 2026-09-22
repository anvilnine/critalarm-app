import 'package:critalarm/features/reminders/domain/reminder_args.dart';
import 'package:critalarm/features/reminders/domain/reminder_inputs.dart';
import 'package:critalarm/features/reminders/domain/reminder_kind.dart';
import 'package:critalarm/features/reminders/domain/rules/silent_topic_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 22, 9);
  const prod = ReminderTopic(name: 'prod-db');

  ReminderInputs inputs({
    Set<String> silent = const {'prod-db'},
    Set<String> done = const {},
    List<ReminderTopic> topics = const [prod],
    DateTime? createdAt,
    DateTime? at,
  }) => ReminderInputs(
    now: at ?? now,
    topics: topics,
    topicsCreatedHere: {'prod-db': createdAt ?? DateTime(2026, 9, 21, 15)},
    silentTopicNames: silent,
    silentDone: done,
  );

  test('plans 24 hours after the topic was made here', () {
    final list = SilentTopicRule.candidates(inputs());
    expect(list, hasLength(1));
    final c = list.single;
    expect(c.kind, ReminderKind.silentTopic);
    expect(c.id, 9200);
    expect(c.fireAt, DateTime(2026, 9, 22, 15));
    expect(c.args[ReminderArgs.topic], 'prod-db');
    expect(c.dedupeKey, 'prod-db');
  });

  test('stays quiet once the topic has messages', () {
    expect(SilentTopicRule.candidates(inputs(silent: const {})), isEmpty);
  });

  test('fires once per topic', () {
    expect(
      SilentTopicRule.candidates(inputs(done: const {'prod-db'})),
      isEmpty,
    );
  });

  test('forgets a topic that was deleted', () {
    expect(SilentTopicRule.candidates(inputs(topics: const [])), isEmpty);
  });

  test('a day that already passed plans for a minute from now', () {
    final c = SilentTopicRule.candidates(
      inputs(
        createdAt: DateTime(2026, 9, 19),
        at: DateTime(2026, 9, 22, 12),
      ),
    ).single;
    expect(c.fireAt, DateTime(2026, 9, 22, 12, 1));
  });
}
