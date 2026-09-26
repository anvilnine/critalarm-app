import 'package:critalarm/features/local_reminders/domain/local_reminder_args.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_candidate.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_dates.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_ids.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_inputs.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';
import 'package:easy_localization/easy_localization.dart';

/// Idea 10: a real alarm woke the user between 00:00 and 06:00 and they
/// acked it. At 09:00 the same morning, one Pro nudge that names the ring.
abstract final class MorningAfterRule {
  static const int nightEndHour = 6;
  static const int fireHour = 9;

  static bool isNight(DateTime at) => at.hour < nightEndHour;

  static LocalReminderCandidate? candidate(LocalReminderInputs inputs) {
    if (!inputs.proShouldAsk) return null;
    final fireAt = LocalReminderDates.atHour(inputs.now, fireHour);
    if (!inputs.now.isBefore(fireAt)) return null;

    final rings = [
      for (final incident in inputs.incidents)
        if (!incident.isTest &&
            incident.openedAt != null &&
            incident.ackedAt != null &&
            LocalReminderDates.isSameDay(incident.openedAt!, inputs.now) &&
            isNight(incident.openedAt!) &&
            !inputs.morningAfterDone.contains(incident.id))
          incident,
    ]..sort((a, b) => a.openedAt!.compareTo(b.openedAt!));
    if (rings.isEmpty) return null;

    final first = rings.first;
    final opened = first.openedAt!;
    final seconds = first.ackedAt!.difference(opened).inSeconds;
    return LocalReminderCandidate(
      kind: LocalReminderKind.morningAfter,
      id: LocalReminderIds.morningAfter,
      fireAt: fireAt,
      args: {
        LocalReminderArgs.time: DateFormat('HH:mm').format(opened),
        LocalReminderArgs.topic: first.topic,
        LocalReminderArgs.seconds: '${seconds < 0 ? 0 : seconds}',
        LocalReminderArgs.incidentId: first.id,
      },
      dedupeKey: first.id,
    );
  }
}
