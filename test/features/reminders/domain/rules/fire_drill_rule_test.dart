import 'package:critalarm/features/reminders/domain/fire_drill_pool.dart';
import 'package:critalarm/features/reminders/domain/reminder_args.dart';
import 'package:critalarm/features/reminders/domain/reminder_ids.dart';
import 'package:critalarm/features/reminders/domain/reminder_inputs.dart';
import 'package:critalarm/features/reminders/domain/reminder_kind.dart';
import 'package:critalarm/features/reminders/domain/rules/fire_drill_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Tuesday 22 September 2026, noon. The next Saturday is 26 September.
  final now = DateTime(2026, 9, 22, 12);
  const prod = ReminderTopic(name: 'prod-db', isCritical: true);

  test('plans Saturday 10:00 for a critical topic untested for 30+ days', () {
    final c = FireDrillRule.candidate(
      ReminderInputs(
        now: now,
        topics: const [prod],
        lastTestAt: {'prod-db': DateTime(2026, 8, 20, 12)},
      ),
    )!;
    expect(c.kind, ReminderKind.fireDrill);
    expect(c.id, ReminderIds.drill);
    expect(c.fireAt, DateTime(2026, 9, 26, 10));
    expect(c.args[ReminderArgs.topic], 'prod-db');
    expect(c.args[ReminderArgs.days], '37');
    expect(c.isOverdue, isFalse);
  });

  test('waits while the last test is under 30 days old at fire time', () {
    expect(
      FireDrillRule.candidate(
        ReminderInputs(
          now: now,
          topics: const [prod],
          lastTestAt: {'prod-db': DateTime(2026, 9, 10)},
        ),
      ),
      isNull,
    );
  });

  test('a real alarm acked recently counts as proof it works', () {
    expect(
      FireDrillRule.candidate(
        ReminderInputs(
          now: now,
          topics: const [prod],
          lastTestAt: {'prod-db': DateTime(2026, 7)},
          incidents: [
            ReminderIncident(
              id: 'inc_1',
              topic: 'prod-db',
              openedAt: DateTime(2026, 9, 10, 3),
              ackedAt: DateTime(2026, 9, 10, 3, 1),
            ),
          ],
        ),
      ),
      isNull,
    );
  });

  test('skips normal topics and does nothing without a critical one', () {
    expect(
      FireDrillRule.candidate(
        ReminderInputs(
          now: now,
          topics: const [ReminderTopic(name: 'backups')],
          lastTestAt: {'backups': DateTime(2026, 7)},
        ),
      ),
      isNull,
    );
  });

  test('skips a topic that has an open or acked incident', () {
    expect(
      FireDrillRule.candidate(
        ReminderInputs(
          now: now,
          topics: const [prod],
          lastTestAt: {'prod-db': DateTime(2026, 7)},
          incidents: const [
            ReminderIncident(
              id: 'inc_2',
              topic: 'prod-db',
              isOpenOrAcked: true,
            ),
          ],
        ),
      ),
      isNull,
    );
  });

  test('names the critical topic tested longest ago', () {
    final c = FireDrillRule.candidate(
      ReminderInputs(
        now: now,
        topics: const [
          prod,
          ReminderTopic(name: 'db-2', isCritical: true),
        ],
        lastTestAt: {
          'prod-db': DateTime(2026, 8, 20),
          'db-2': DateTime(2026, 8),
        },
      ),
    )!;
    expect(c.args[ReminderArgs.topic], 'db-2');
  });

  test('a topic never tested counts from when it was made', () {
    final c = FireDrillRule.candidate(
      ReminderInputs(
        now: now,
        topics: [
          ReminderTopic(
            name: 'prod-db',
            isCritical: true,
            createdAt: DateTime(2026, 8, 10),
          ),
        ],
      ),
    )!;
    expect(c.args[ReminderArgs.days], '47');
  });

  test('a topic never tested never gets the "last test" line', () {
    for (var week = 0; week < 60; week++) {
      final c = FireDrillRule.candidate(
        ReminderInputs(
          now: now.add(Duration(days: 7 * week)),
          topics: [
            ReminderTopic(
              name: 'prod-db',
              isCritical: true,
              createdAt: DateTime(2026, 6),
            ),
          ],
        ),
      )!;
      expect(c.poolIndex, isNot(FireDrillPool.lastTestLine), reason: '$week');
    }
  });

  test('marks a drill 14+ days past its mark as overdue', () {
    final c = FireDrillRule.candidate(
      ReminderInputs(
        now: now,
        topics: const [prod],
        lastTestAt: {'prod-db': DateTime(2026, 8)},
      ),
    )!;
    expect(c.isOverdue, isTrue);
  });

  test('after a real alarm the line never claims nothing rang', () {
    final c = FireDrillRule.candidate(
      ReminderInputs(
        now: now,
        topics: const [prod],
        lastTestAt: {'prod-db': DateTime(2026, 7)},
        incidents: [
          ReminderIncident(
            id: 'inc_3',
            topic: 'prod-db',
            openedAt: DateTime(2026, 8, 10, 3),
            ackedAt: DateTime(2026, 8, 10, 3, 1),
          ),
        ],
      ),
    )!;
    expect(FireDrillPool.nothingRangLines.contains(c.poolIndex), isFalse);
    expect(c.args[ReminderArgs.pool], '${c.poolIndex}');
  });

  test('never repeats the last line', () {
    final c = FireDrillRule.candidate(
      ReminderInputs(
        now: now,
        topics: const [prod],
        lastTestAt: {'prod-db': DateTime(2026, 7)},
        drillLastIndex: 0,
      ),
    )!;
    expect(c.poolIndex, isNot(0));
  });
}
