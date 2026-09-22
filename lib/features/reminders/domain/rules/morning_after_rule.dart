import 'package:critalarm/features/reminders/domain/reminder_args.dart';
import 'package:critalarm/features/reminders/domain/reminder_candidate.dart';
import 'package:critalarm/features/reminders/domain/reminder_dates.dart';
import 'package:critalarm/features/reminders/domain/reminder_ids.dart';
import 'package:critalarm/features/reminders/domain/reminder_inputs.dart';
import 'package:critalarm/features/reminders/domain/reminder_kind.dart';
import 'package:easy_localization/easy_localization.dart';

/// Idea 10: a real alarm woke the user between 00:00 and 06:00 and they
/// acked it. At 09:00 the same morning, one Pro nudge that names the ring.
abstract final class MorningAfterRule {
  static const int nightEndHour = 6;
  static const int fireHour = 9;

  static bool isNight(DateTime at) => at.hour < nightEndHour;

  static ReminderCandidate? candidate(ReminderInputs inputs) {
    if (!inputs.proShouldAsk) return null;
    final fireAt = ReminderDates.atHour(inputs.now, fireHour);
    if (!inputs.now.isBefore(fireAt)) return null;

    final rings = [
      for (final incident in inputs.incidents)
        if (!incident.isTest &&
            incident.openedAt != null &&
            incident.ackedAt != null &&
            ReminderDates.isSameDay(incident.openedAt!, inputs.now) &&
            isNight(incident.openedAt!) &&
            !inputs.morningAfterDone.contains(incident.id))
          incident,
    ]..sort((a, b) => a.openedAt!.compareTo(b.openedAt!));
    if (rings.isEmpty) return null;

    final first = rings.first;
    final opened = first.openedAt!;
    final seconds = first.ackedAt!.difference(opened).inSeconds;
    return ReminderCandidate(
      kind: ReminderKind.morningAfter,
      id: ReminderIds.morningAfter,
      fireAt: fireAt,
      args: {
        ReminderArgs.time: DateFormat('HH:mm').format(opened),
        ReminderArgs.topic: first.topic,
        ReminderArgs.seconds: '${seconds < 0 ? 0 : seconds}',
        ReminderArgs.incidentId: first.id,
      },
      dedupeKey: first.id,
    );
  }
}
