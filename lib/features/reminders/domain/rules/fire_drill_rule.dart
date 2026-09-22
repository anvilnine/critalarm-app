import 'package:critalarm/features/reminders/domain/fire_drill_pool.dart';
import 'package:critalarm/features/reminders/domain/reminder_args.dart';
import 'package:critalarm/features/reminders/domain/reminder_candidate.dart';
import 'package:critalarm/features/reminders/domain/reminder_dates.dart';
import 'package:critalarm/features/reminders/domain/reminder_ids.dart';
import 'package:critalarm/features/reminders/domain/reminder_inputs.dart';
import 'package:critalarm/features/reminders/domain/reminder_kind.dart';

/// Idea 1: a critical topic nobody has proven works for 30+ days gets a
/// Saturday 10:00 nudge to ring it once.
abstract final class FireDrillRule {
  static const Duration staleAfter = Duration(days: 30);
  static const Duration overdueBy = Duration(days: 14);
  static const int fireHour = 10;

  static ReminderCandidate? candidate(ReminderInputs inputs) {
    final fireAt = ReminderDates.weekdayAtHourOnOrAfter(
      inputs.now,
      DateTime.saturday,
      fireHour,
    );

    String? topicName;
    DateTime? oldest;
    var somethingRang = false;
    var neverTested = false;

    for (final topic in inputs.topics) {
      if (!topic.isCritical) continue;
      final isBusy = inputs.incidents.any(
        (i) => i.topic == topic.name && i.isOpenOrAcked,
      );
      if (isBusy) continue;

      final lastTest = inputs.lastTestAt[topic.name];
      final lastRealAck = ReminderDates.latest([
        for (final i in inputs.incidents)
          if (i.topic == topic.name && !i.isTest) i.ackedAt,
      ]);
      final seen =
          ReminderDates.latest([lastTest, lastRealAck]) ??
          topic.createdAt ??
          inputs.installedAt;
      if (seen == null) continue;

      if (oldest == null || seen.isBefore(oldest)) {
        topicName = topic.name;
        oldest = seen;
        somethingRang =
            lastRealAck != null &&
            (lastTest == null || lastRealAck.isAfter(lastTest));
        // No test in the app (or none since this update), so "Last test
        // alarm: N days ago" would be false.
        neverTested = lastTest == null;
      }
    }
    if (topicName == null || oldest == null) return null;

    final days = ReminderDates.daysBetween(oldest, fireAt);
    if (days < staleAfter.inDays) return null;

    final pool = FireDrillPool.pick(
      random: FireDrillPool.randomFor(fireAt),
      lastIndex: inputs.drillLastIndex,
      somethingRang: somethingRang,
      neverTested: neverTested,
    );
    return ReminderCandidate(
      kind: ReminderKind.fireDrill,
      id: ReminderIds.drill,
      fireAt: fireAt,
      args: {
        ReminderArgs.topic: topicName,
        ReminderArgs.days: '$days',
        ReminderArgs.pool: '$pool',
      },
      poolIndex: pool,
      isOverdue: days >= staleAfter.inDays + overdueBy.inDays,
    );
  }
}
