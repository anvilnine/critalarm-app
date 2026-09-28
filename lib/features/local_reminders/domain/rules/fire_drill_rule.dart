import 'package:critalarm/features/local_reminders/domain/fire_drill_pool.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_args.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_candidate.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_dates.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_ids.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_inputs.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';

/// Idea 1: a critical topic nobody has proven works for 30+ days gets a
/// Saturday 10:00 nudge to ring it once.
abstract final class FireDrillRule {
  static const Duration staleAfter = Duration(days: 30);
  static const Duration overdueBy = Duration(days: 14);
  static const int fireHour = 10;

  static LocalReminderCandidate? candidate(LocalReminderInputs inputs) {
    final fireAt = LocalReminderDates.weekdayAtHourOnOrAfter(
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
      final lastRealAck = LocalReminderDates.latest([
        for (final i in inputs.incidents)
          if (i.topic == topic.name && !i.isTest) i.ackedAt,
      ]);
      final seen =
          LocalReminderDates.latest([lastTest, lastRealAck]) ??
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

    final days = LocalReminderDates.daysBetween(oldest, fireAt);
    if (days < staleAfter.inDays) return null;

    final pool = FireDrillPool.pick(
      random: FireDrillPool.randomFor(fireAt),
      lastIndex: inputs.drillLastIndex,
      somethingRang: somethingRang,
      neverTested: neverTested,
    );
    return LocalReminderCandidate(
      kind: LocalReminderKind.fireDrill,
      id: LocalReminderIds.drill,
      fireAt: fireAt,
      args: {
        LocalReminderArgs.topic: topicName,
        LocalReminderArgs.days: '$days',
        LocalReminderArgs.pool: '$pool',
      },
      poolIndex: pool,
      isOverdue: days >= staleAfter.inDays + overdueBy.inDays,
    );
  }
}
