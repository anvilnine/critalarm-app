import 'package:critalarm/features/local_reminders/domain/local_reminder_args.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_candidate.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_ids.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_inputs.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';

/// Idea 2: a topic made on this phone that has heard nothing 24 hours later
/// gets one nudge to wire up a script.
abstract final class SilentTopicRule {
  static const Duration quietFor = Duration(hours: 24);

  static List<LocalReminderCandidate> candidates(LocalReminderInputs inputs) {
    final names = inputs.topicsCreatedHere.keys.toList()..sort();
    final live = {for (final topic in inputs.topics) topic.name};
    final out = <LocalReminderCandidate>[];
    for (var index = 0; index < names.length; index++) {
      final name = names[index];
      if (!live.contains(name)) continue;
      if (inputs.silentDone.contains(name)) continue;
      if (!inputs.silentTopicNames.contains(name)) continue;

      final due = inputs.topicsCreatedHere[name]!.add(quietFor);
      final fireAt = due.isAfter(inputs.now)
          ? due
          : inputs.now.add(const Duration(minutes: 1));
      out.add(
        LocalReminderCandidate(
          kind: LocalReminderKind.silentTopic,
          id: LocalReminderIds.silent(index),
          fireAt: fireAt,
          args: {LocalReminderArgs.topic: name},
          dedupeKey: name,
        ),
      );
    }
    return out;
  }
}
