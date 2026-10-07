import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_reader.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_rule.dart';
import 'package:critalarm/features/reliability/domain/sources/missed_alarm_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 7, 9);

  MissedAlarm alarm(
    String id,
    DateTime at, {
    MissedReason reason = MissedReason.unanswered,
  }) => MissedAlarm(incidentId: id, topic: 'prod', at: at, reason: reason);

  ReliabilityCheck check(
    List<MissedAlarm> missed, {
    Set<String> dismissed = const {},
  }) => MissedAlarmSource.missedAlarmCheckFor(
    now: now,
    missed: missed,
    dismissedIds: dismissed,
    testRouteName: 'testRing',
  );

  test('nothing missed is fine', () {
    expect(
      check(const []),
      const ReliabilityCheck(
        id: ReliabilityCheckIds.missedAlarm,
        state: ReliabilityState.fine,
      ),
    );
  });

  test('a missed alarm from last night needs a look', () {
    final result = check([alarm('a', now.subtract(const Duration(hours: 6)))]);
    expect(result.state, ReliabilityState.needsLook);
    expect(result.reason, 'missed_unanswered');
  });

  group('the 7 day edge', () {
    test('exactly seven days old still needs a look', () {
      expect(
        check([alarm('a', now.subtract(const Duration(days: 7)))]).state,
        ReliabilityState.needsLook,
      );
    });

    test('one second past seven days is fine', () {
      expect(
        check([
          alarm('a', now.subtract(const Duration(days: 7, seconds: 1))),
        ]).state,
        ReliabilityState.fine,
      );
    });

    test('an old one does not hide a new one', () {
      final result = check([
        alarm('old', now.subtract(const Duration(days: 9))),
        alarm(
          'new',
          now.subtract(const Duration(days: 6, hours: 23)),
          reason: MissedReason.noPushReached,
        ),
      ]);
      expect(result.state, ReliabilityState.needsLook);
      expect(result.reason, 'missed_no_push');
    });
  });

  test('a closed entry is fine', () {
    expect(
      check(
        [alarm('a', now.subtract(const Duration(hours: 6)))],
        dismissed: {'a'},
      ).state,
      ReliabilityState.fine,
    );
  });

  test('one closed and one not still needs a look', () {
    expect(
      check(
        [
          alarm('a', now.subtract(const Duration(hours: 6))),
          alarm('b', now.subtract(const Duration(hours: 7))),
        ],
        dismissed: {'a'},
      ).state,
      ReliabilityState.needsLook,
    );
  });

  test('a time after now is not counted', () {
    expect(
      check([alarm('a', now.add(const Duration(minutes: 5)))]).state,
      ReliabilityState.fine,
    );
  });

  test('the newest missed alarm gives the reason', () {
    final result = check([
      alarm(
        'a',
        now.subtract(const Duration(days: 2)),
        reason: MissedReason.rangUnanswered,
      ),
      alarm(
        'b',
        now.subtract(const Duration(hours: 2)),
        reason: MissedReason.noPushReached,
      ),
    ]);
    expect(result.reason, 'missed_no_push');
  });

  group('an alarm that rang and went unanswered', () {
    final rang = alarm(
      'rang',
      now.subtract(const Duration(hours: 1)),
      reason: MissedReason.rangUnanswered,
    );

    test('is fine: the phone did its part', () {
      final result = check([rang]);
      expect(result.state, ReliabilityState.fine);
      expect(result.fix, isNull);
    });

    test('still says what happened', () {
      expect(check([rang]).reason, 'missed_rang');
    });

    test('says nothing once its entry is closed', () {
      expect(
        check([rang], dismissed: {'rang'}),
        const ReliabilityCheck(
          id: ReliabilityCheckIds.missedAlarm,
          state: ReliabilityState.fine,
        ),
      );
    });

    test('does not hide an older alarm the phone may have let down', () {
      final result = check([
        rang,
        alarm(
          'older',
          now.subtract(const Duration(days: 2)),
          reason: MissedReason.pushButNoRing,
        ),
      ]);
      expect(result.state, ReliabilityState.needsLook);
      expect(result.reason, 'missed_push_no_ring');
      expect(
        (result.fix! as MissedAlarmFix).at,
        now.subtract(
          const Duration(days: 2),
        ),
      );
    });
  });

  test('every reason that needs a look is offered a test', () {
    for (final reason in [
      MissedReason.noPushReached,
      MissedReason.pushButNoRing,
      MissedReason.unanswered,
    ]) {
      final result = check([
        alarm('a', now.subtract(const Duration(hours: 1)), reason: reason),
      ]);
      expect(result.state, ReliabilityState.needsLook, reason: reason.name);
      expect(
        result.fix,
        MissedAlarmFix(
          testRouteName: 'testRing',
          topic: 'prod',
          at: now.subtract(const Duration(hours: 1)),
          incidentIds: const ['a'],
        ),
        reason: reason.name,
      );
    }
  });

  test('the fix names the newest alarm that counts', () {
    final fix =
        check([
              MissedAlarm(
                incidentId: 'old',
                topic: 'nas',
                at: now.subtract(const Duration(days: 3)),
                reason: MissedReason.noPushReached,
              ),
              MissedAlarm(
                incidentId: 'new',
                topic: 'prod-db',
                at: now.subtract(const Duration(hours: 2)),
                reason: MissedReason.unanswered,
              ),
            ]).fix!
            as MissedAlarmFix;
    expect(fix.topic, 'prod-db');
    expect(fix.at, now.subtract(const Duration(hours: 2)));
  });

  test('closing clears every entry Home counts, newest first', () {
    final fix =
        check(
              [
                alarm('gone', now.subtract(const Duration(hours: 1))),
                alarm(
                  'rang',
                  now.subtract(const Duration(hours: 2)),
                  reason: MissedReason.rangUnanswered,
                ),
                alarm('older', now.subtract(const Duration(days: 2))),
                alarm('too_old', now.subtract(const Duration(days: 9))),
              ],
              dismissed: {'gone'},
            ).fix!
            as MissedAlarmFix;
    // The same list `missedAlarmsToShow` gives Home's notice.
    expect(fix.incidentIds, ['rang', 'older']);
  });

  test('read asks both callbacks and answers one check', () async {
    final source = MissedAlarmSource(
      readMissed: () async => [
        alarm('a', now.subtract(const Duration(hours: 1))),
      ],
      readDismissedIds: () => const {},
      testRouteName: 'testRing',
      now: () => now,
    );
    final checks = await source.read();
    expect(checks.single.id, ReliabilityCheckIds.missedAlarm);
    expect(checks.single.state, ReliabilityState.needsLook);
  });
}
