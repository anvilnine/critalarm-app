import 'package:critalarm/features/local_reminders/domain/fire_drill_pool.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_args.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_candidate.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_ids.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';
import 'package:critalarm/features/local_reminders/domain/rules/plan_heads_up_rule.dart';

/// Made-up reminders for the Reminder lab's "Fire one", with the same
/// numbers the approved screens use.
abstract final class LocalReminderLabSamples {
  static const String sampleManagementUrl =
      'https://apps.apple.com/account/subscriptions';

  static Map<String, String> argsFor(LocalReminderKind kind) => switch (kind) {
    LocalReminderKind.fireDrill => {
      LocalReminderArgs.topic: 'prod-db',
      LocalReminderArgs.days: '34',
      LocalReminderArgs.pool: '0',
    },
    LocalReminderKind.silentTopic => {LocalReminderArgs.topic: 'prod-db'},
    LocalReminderKind.backup => {LocalReminderArgs.count: '3'},
    LocalReminderKind.planHeadsUp => {
      LocalReminderArgs.headsUp: PlanHeadsUpKind.billing.name,
      LocalReminderArgs.url: sampleManagementUrl,
    },
    LocalReminderKind.morningAfter => {
      LocalReminderArgs.time: '03:12',
      LocalReminderArgs.topic: 'db-2',
      LocalReminderArgs.seconds: '48',
      LocalReminderArgs.incidentId: 'inc_lab',
    },
    LocalReminderKind.proLater => const {},
    LocalReminderKind.reviewAsk => {LocalReminderArgs.pool: '0'},
    LocalReminderKind.feedbackAsk => {LocalReminderArgs.pool: '0'},
  };

  static LocalReminderCandidate candidate(
    LocalReminderKind kind,
    DateTime fireAt,
  ) => LocalReminderCandidate(
    kind: kind,
    id: LocalReminderIds.lab(kind),
    fireAt: fireAt,
    args: argsFor(kind),
  );

  static List<LocalReminderCandidate> drillPool(DateTime fireAt) => [
    for (var i = 0; i < FireDrillPool.size; i++)
      LocalReminderCandidate(
        kind: LocalReminderKind.fireDrill,
        id: LocalReminderIds.lab(LocalReminderKind.fireDrill),
        fireAt: fireAt,
        args: {
          LocalReminderArgs.topic: 'prod-db',
          LocalReminderArgs.days: '34',
          LocalReminderArgs.pool: '$i',
        },
        poolIndex: i,
      ),
  ];
}
