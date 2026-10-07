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
          reason: MissedReason.rangUnanswered,
        ),
      ]);
      expect(result.state, ReliabilityState.needsLook);
      expect(result.reason, 'missed_rang');
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

  test('a phone that got no push, or did not ring, is offered a test', () {
    for (final reason in [
      MissedReason.noPushReached,
      MissedReason.pushButNoRing,
    ]) {
      expect(
        check([
          alarm('a', now.subtract(const Duration(hours: 1)), reason: reason),
        ]).fix,
        const OpenRouteFix('testRing'),
      );
    }
  });

  test('a phone that rang, or cannot tell, is offered nothing', () {
    for (final reason in [
      MissedReason.rangUnanswered,
      MissedReason.unanswered,
    ]) {
      expect(
        check([
          alarm('a', now.subtract(const Duration(hours: 1)), reason: reason),
        ]).fix,
        isNull,
      );
    }
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
