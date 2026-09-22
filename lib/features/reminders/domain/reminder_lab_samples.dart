import 'package:critalarm/features/reminders/domain/fire_drill_pool.dart';
import 'package:critalarm/features/reminders/domain/reminder_args.dart';
import 'package:critalarm/features/reminders/domain/reminder_candidate.dart';
import 'package:critalarm/features/reminders/domain/reminder_ids.dart';
import 'package:critalarm/features/reminders/domain/reminder_kind.dart';
import 'package:critalarm/features/reminders/domain/rules/plan_heads_up_rule.dart';

/// Made-up reminders for the Reminder lab's "Fire one", with the same
/// numbers the approved screens use.
abstract final class ReminderLabSamples {
  static const String sampleManagementUrl =
      'https://apps.apple.com/account/subscriptions';

  static Map<String, String> argsFor(ReminderKind kind) => switch (kind) {
    ReminderKind.fireDrill => {
      ReminderArgs.topic: 'prod-db',
      ReminderArgs.days: '34',
      ReminderArgs.pool: '0',
    },
    ReminderKind.silentTopic => {ReminderArgs.topic: 'prod-db'},
    ReminderKind.backup => {ReminderArgs.count: '3'},
    ReminderKind.planHeadsUp => {
      ReminderArgs.notice: PlanNotice.billing.name,
      ReminderArgs.url: sampleManagementUrl,
    },
    ReminderKind.morningAfter => {
      ReminderArgs.time: '03:12',
      ReminderArgs.topic: 'db-2',
      ReminderArgs.seconds: '48',
      ReminderArgs.incidentId: 'inc_lab',
    },
    ReminderKind.proLater => const {},
    ReminderKind.reviewAsk => {ReminderArgs.pool: '0'},
    ReminderKind.feedbackAsk => {ReminderArgs.pool: '0'},
  };

  static ReminderCandidate candidate(ReminderKind kind, DateTime fireAt) =>
      ReminderCandidate(
        kind: kind,
        id: ReminderIds.lab(kind),
        fireAt: fireAt,
        args: argsFor(kind),
      );

  static List<ReminderCandidate> drillPool(DateTime fireAt) => [
    for (var i = 0; i < FireDrillPool.size; i++)
      ReminderCandidate(
        kind: ReminderKind.fireDrill,
        id: ReminderIds.lab(ReminderKind.fireDrill),
        fireAt: fireAt,
        args: {
          ReminderArgs.topic: 'prod-db',
          ReminderArgs.days: '34',
          ReminderArgs.pool: '$i',
        },
        poolIndex: i,
      ),
  ];
}
