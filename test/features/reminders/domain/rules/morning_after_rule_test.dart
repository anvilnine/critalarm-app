import 'package:critalarm/features/reminders/domain/reminder_args.dart';
import 'package:critalarm/features/reminders/domain/reminder_ids.dart';
import 'package:critalarm/features/reminders/domain/reminder_inputs.dart';
import 'package:critalarm/features/reminders/domain/rules/morning_after_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 23, 7);

  ReminderIncident ring(
    String id, {
    required DateTime openedAt,
    Duration upAfter = const Duration(seconds: 48),
    bool isTest = false,
    bool acked = true,
  }) => ReminderIncident(
    id: id,
    topic: 'db-2',
    isTest: isTest,
    openedAt: openedAt,
    ackedAt: acked ? openedAt.add(upAfter) : null,
  );

  ReminderInputs inputs(
    List<ReminderIncident> incidents, {
    bool proShouldAsk = true,
    DateTime? at,
    Set<String> done = const {},
  }) => ReminderInputs(
    now: at ?? now,
    incidents: incidents,
    proShouldAsk: proShouldAsk,
    morningAfterDone: done,
  );

  test('plans 09:00 after a real night ring that was acked', () {
    final c = MorningAfterRule.candidate(
      inputs([ring('inc_1', openedAt: DateTime(2026, 9, 23, 3, 12))]),
    )!;
    expect(c.id, ReminderIds.morningAfter);
    expect(c.fireAt, DateTime(2026, 9, 23, 9));
    expect(c.args[ReminderArgs.time], '03:12');
    expect(c.args[ReminderArgs.topic], 'db-2');
    expect(c.args[ReminderArgs.seconds], '48');
    expect(c.dedupeKey, 'inc_1');
  });

  test('needs ProPromptRules to say yes at plan time', () {
    expect(
      MorningAfterRule.candidate(
        inputs(
          [ring('inc_1', openedAt: DateTime(2026, 9, 23, 3))],
          proShouldAsk: false,
        ),
      ),
      isNull,
    );
  });

  test('skips when the app first opens after 09:00', () {
    expect(
      MorningAfterRule.candidate(
        inputs(
          [ring('inc_1', openedAt: DateTime(2026, 9, 23, 3))],
          at: DateTime(2026, 9, 23, 9, 30),
        ),
      ),
      isNull,
    );
  });

  test('ignores test alarms, day rings, unacked rings and last night', () {
    for (final incident in [
      ring('t', openedAt: DateTime(2026, 9, 23, 3), isTest: true),
      ring('d', openedAt: DateTime(2026, 9, 23, 6, 30)),
      ring('u', openedAt: DateTime(2026, 9, 23, 3), acked: false),
      ring('y', openedAt: DateTime(2026, 9, 22, 3)),
    ]) {
      expect(MorningAfterRule.candidate(inputs([incident])), isNull);
    }
  });

  test('the first ring of the night wins', () {
    final c = MorningAfterRule.candidate(
      inputs([
        ring('inc_late', openedAt: DateTime(2026, 9, 23, 4)),
        ring('inc_early', openedAt: DateTime(2026, 9, 23, 1, 5)),
      ]),
    )!;
    expect(c.dedupeKey, 'inc_early');
  });

  test('fires once per ring', () {
    expect(
      MorningAfterRule.candidate(
        inputs(
          [ring('inc_1', openedAt: DateTime(2026, 9, 23, 3))],
          done: const {'inc_1'},
        ),
      ),
      isNull,
    );
  });
}
