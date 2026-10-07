import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_reader.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_rule.dart';
import 'package:critalarm/features/reliability/domain/reliability_check_source.dart';

/// Whether this phone may have let an alarm down lately.
///
/// It looks at the missed alarms from the last [missedAlarmWindow] that
/// were not closed, on Home or on the Reliability screen. Both close the
/// same entries.
///
/// An alarm that rang and went unanswered is not this phone's failure, so
/// it never asks for a look. With only such alarms left the check is fine
/// and carries the reason `missed_rang`, so the row can still say what
/// happened. Home's notice is where that alarm is told.
///
/// Any other missed alarm needs a look. The newest of them gives the
/// reason: `missed_no_push`, `missed_push_no_ring` or `missed_unanswered`.
/// Its fix is a [MissedAlarmFix]: a test alarm through [testRouteName],
/// the topic and time of that alarm, and the ids closing clears.
final class MissedAlarmSource implements ReliabilityCheckSource {
  MissedAlarmSource({
    required this.readMissed,
    required this.readDismissedIds,
    required this.testRouteName,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Every alarm this phone missed, closed entries included.
  final Future<List<MissedAlarm>> Function() readMissed;
  final Set<String> Function() readDismissedIds;
  final String testRouteName;
  final DateTime Function() _now;

  @override
  Future<List<ReliabilityCheck>> read() async => [
    missedAlarmCheckFor(
      now: _now(),
      missed: await readMissed(),
      dismissedIds: readDismissedIds(),
      testRouteName: testRouteName,
    ),
  ];

  /// The state rule. Pure, so a test picks the clock.
  static ReliabilityCheck missedAlarmCheckFor({
    required DateTime now,
    required Iterable<MissedAlarm> missed,
    required Set<String> dismissedIds,
    required String testRouteName,
  }) {
    const id = ReliabilityCheckIds.missedAlarm;
    final shown = missedAlarmsToShow(
      missed: missed,
      dismissedIds: dismissedIds,
      now: now,
    );
    if (shown.isEmpty) {
      return const ReliabilityCheck(id: id, state: ReliabilityState.fine);
    }
    // The phone did its part for an alarm that rang. Nobody answering is
    // not something a setting on this phone can fix.
    final counted = [
      for (final alarm in shown)
        if (alarm.reason != MissedReason.rangUnanswered) alarm,
    ];
    if (counted.isEmpty) {
      return ReliabilityCheck(
        id: id,
        state: ReliabilityState.fine,
        reason: 'missed_${MissedReason.rangUnanswered.code}',
      );
    }
    final newest = counted.first;
    return ReliabilityCheck(
      id: id,
      state: ReliabilityState.needsLook,
      reason: 'missed_${newest.reason.code}',
      fix: MissedAlarmFix(
        testRouteName: testRouteName,
        topic: newest.topic,
        at: newest.at,
        // The same ids Home's notice closes, so one tap in either place
        // clears both.
        incidentIds: [for (final alarm in shown) alarm.incidentId],
      ),
    );
  }
}
