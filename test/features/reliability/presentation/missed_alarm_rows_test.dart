import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/in_app_notices/presentation/missed_alarm_notice_view.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_reader.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_rule.dart';
import 'package:critalarm/features/reliability/domain/sources/missed_alarm_source.dart';
import 'package:critalarm/features/reliability/presentation/reliability_rows.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 7, 18);
  final at = DateTime(2026, 10, 7, 13, 23);

  /// The check the real source gives for one missed alarm.
  ReliabilityCheck missed(MissedReason reason) =>
      MissedAlarmSource.missedAlarmCheckFor(
        now: now,
        missed: [
          MissedAlarm(
            incidentId: 'inc_1',
            topic: 'prod-db',
            at: at,
            reason: reason,
          ),
        ],
        dismissedIds: const {},
        testRouteName: 'testRing',
      );

  const needsLook = [
    MissedReason.noPushReached,
    MissedReason.pushButNoRing,
    MissedReason.unanswered,
  ];

  test('the missed alarm row has a title', () {
    expect(
      reliabilityTitleKey(ReliabilityCheckIds.missedAlarm),
      LocaleKeys.reliability_check_missed_alarm,
    );
  });

  test('every reason that needs a look has its own line', () {
    final lines = {
      for (final reason in needsLook) reliabilityLineKey(missed(reason)),
    };
    expect(lines, hasLength(needsLook.length));
    expect(lines, isNot(contains(LocaleKeys.reliability_line_look_generic)));
  });

  test('the line names the topic and the time Home shows', () {
    for (final reason in needsLook) {
      final line = reliabilityLine(missed(reason), now: now)!;
      expect(line.args, {
        'topic': 'prod-db',
        'time': missedAlarmTime(at, now: now),
      }, reason: reason.name);
    }
    expect(
      reliabilityLine(missed(MissedReason.noPushReached), now: now)!.key,
      LocaleKeys.reliability_line_missed_no_push_when,
    );
    expect(
      reliabilityLine(missed(MissedReason.pushButNoRing), now: now)!.key,
      LocaleKeys.reliability_line_missed_push_no_ring_when,
    );
    expect(
      reliabilityLine(missed(MissedReason.unanswered), now: now)!.key,
      LocaleKeys.reliability_line_missed_unanswered_when,
    );
  });

  test('an alarm from another day says which day', () {
    final line = reliabilityLine(
      missed(MissedReason.unanswered),
      now: now.add(const Duration(days: 2)),
    )!;
    expect(line.args['time'], 'Wed 13:23');
  });

  test('a missed line with no alarm to name falls back to the generic', () {
    // No source gives this. It must not draw "{topic}, {time}".
    expect(
      reliabilityLineKey(
        const ReliabilityCheck(
          id: ReliabilityCheckIds.missedAlarm,
          state: ReliabilityState.needsLook,
          reason: 'missed_no_push',
        ),
      ),
      LocaleKeys.reliability_line_look_generic,
    );
  });

  group('an alarm that rang', () {
    final rang = missed(MissedReason.rangUnanswered);

    test('is a fine row that still says it rang', () {
      expect(rang.state, ReliabilityState.fine);
      final line = reliabilityLine(rang, now: now)!;
      expect(line.key, LocaleKeys.reliability_line_missed_rang);
      expect(line.args, isEmpty);
    });

    test('keeps the plain title, since an alarm was missed', () {
      expect(
        reliabilityRowTitleKey(rang),
        LocaleKeys.reliability_check_missed_alarm,
      );
    });

    test('has no button and a calm face', () {
      expect(rang.fix, isNull);
      expect(reliabilityClearLabelKey(rang.fix), isNull);
      expect(reliabilityRowFace(rang), FaceState.content);
    });
  });

  test('a row that needs a look has "Ring a test" and "Got it"', () {
    for (final reason in needsLook) {
      final fix = missed(reason).fix!;
      expect(
        reliabilityFixLabelKey(fix, testRouteName: 'testRing'),
        LocaleKeys.reliability_fix_ring_test,
        reason: reason.name,
      );
      expect(
        reliabilityClearLabelKey(fix),
        LocaleKeys.reliability_fix_got_it,
        reason: reason.name,
      );
    }
  });

  test('only a missed alarm can be cleared from its row', () {
    expect(reliabilityClearLabelKey(null), isNull);
    expect(reliabilityClearLabelKey(const OpenRouteFix('testRing')), isNull);
    expect(
      reliabilityClearLabelKey(
        const RunFix(ReliabilityFixAction.reRegisterPushToken),
      ),
      isNull,
    );
  });

  test('the row shows the face Home shows for the same reason', () {
    for (final reason in needsLook) {
      expect(
        reliabilityRowFace(missed(reason)),
        missedAlarmFace(reason),
        reason: reason.name,
      );
    }
  });

  test('with nothing missed the title says so', () {
    expect(
      reliabilityRowTitleKey(
        const ReliabilityCheck(
          id: ReliabilityCheckIds.missedAlarm,
          state: ReliabilityState.fine,
        ),
      ),
      LocaleKeys.reliability_check_missed_alarm_fine,
    );
  });
}
