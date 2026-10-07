import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_reader.dart';
import 'package:critalarm/features/reliability/domain/missed_alarm/missed_alarm_rule.dart';
import 'package:critalarm/features/reliability/domain/reliability_check_source.dart';

/// Whether this phone missed an alarm lately.
///
/// Needs a look while a missed alarm from the last [missedAlarmWindow] has
/// not been closed on Home. Fine otherwise. The reason is the newest missed
/// alarm's.
///
/// Reasons: `missed_no_push`, `missed_push_no_ring`, `missed_rang`,
/// `missed_unanswered`. The first two offer a test alarm, through
/// [testRouteName]. The other two offer nothing: the phone did its part, or
/// cannot say what went wrong.
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
    final reason = shown.first.reason;
    return ReliabilityCheck(
      id: id,
      state: ReliabilityState.needsLook,
      reason: 'missed_${reason.code}',
      fix: switch (reason) {
        MissedReason.noPushReached ||
        MissedReason.pushButNoRing => OpenRouteFix(testRouteName),
        MissedReason.rangUnanswered || MissedReason.unanswered => null,
      },
    );
  }
}
