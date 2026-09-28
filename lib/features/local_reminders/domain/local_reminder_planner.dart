import 'package:critalarm/features/local_reminders/domain/local_reminder_budget.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_candidate.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_inputs.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_time_rules.dart';
import 'package:critalarm/features/local_reminders/domain/rules/backup_rule.dart';
import 'package:critalarm/features/local_reminders/domain/rules/feedback_ask_rule.dart';
import 'package:critalarm/features/local_reminders/domain/rules/fire_drill_rule.dart';
import 'package:critalarm/features/local_reminders/domain/rules/morning_after_rule.dart';
import 'package:critalarm/features/local_reminders/domain/rules/plan_heads_up_rule.dart';
import 'package:critalarm/features/local_reminders/domain/rules/pro_later_rule.dart';
import 'package:critalarm/features/local_reminders/domain/rules/review_ask_rule.dart';
import 'package:critalarm/features/local_reminders/domain/rules/silent_topic_rule.dart';
import 'package:critalarm/features/local_reminders/domain/self_hosted_matrix.dart';

/// Turns one snapshot of the app into the reminders to schedule: every
/// budget-free one that passes its rules, plus at most one budgeted one.
final class LocalReminderPlanner {
  const LocalReminderPlanner();

  List<LocalReminderCandidate> plan(LocalReminderInputs inputs) {
    if (inputs.isWeb) return const [];

    final review = ReviewAskRule.candidate(inputs);
    final drill = FireDrillRule.candidate(inputs);
    final backup = BackupRule.candidate(inputs);
    final morning = MorningAfterRule.candidate(inputs);
    final proLater = ProLaterRule.candidate(inputs);
    final feedback = FeedbackAskRule.candidate(
      inputs,
      pendingReviewAt: review?.fireAt,
    );

    final raw = <LocalReminderCandidate>[
      ?drill,
      ...SilentTopicRule.candidates(inputs),
      ?backup,
      ...PlanHeadsUpRule.candidates(inputs),
      ?morning,
      ?proLater,
      ?review,
      ?feedback,
    ];

    final allowed = [
      for (final c in raw)
        if ((!inputs.isSelfHosted || SelfHostedMatrix.allows(c.kind)) &&
            inputs.switches.allows(c.kind))
          c,
    ];
    if (inputs.skipRules) return allowed;

    final rules = LocalReminderTimeRules(
      quietHours: inputs.quietHours,
      ringsAt: [
        for (final incident in inputs.incidents)
          if (incident.openedAt != null) incident.openedAt!,
      ],
    );

    final timed = <LocalReminderCandidate>[];
    for (final c in allowed) {
      final DateTime? at;
      if (c.kind == LocalReminderKind.morningAfter) {
        at = rules.allows(c.fireAt) ? c.fireAt : null;
      } else if (c.kind == LocalReminderKind.feedbackAsk) {
        at = LocalReminderBudget.snapFeedbackAsk(c.fireAt, rules);
      } else {
        at = rules.nextAllowed(
          c.fireAt,
          stepDays: c.kind == LocalReminderKind.fireDrill ? 7 : 1,
        );
      }
      if (at != null) timed.add(c.copyWith(fireAt: at));
    }

    final free = [
      for (final c in timed)
        if (!c.kind.usesBudget) c,
    ];
    final winner = LocalReminderBudget.pick(
      [
        for (final c in timed)
          if (c.kind.usesBudget) c,
      ],
      spentAt: inputs.budgetSpentAt,
      rules: rules,
    );
    return [...free, ?winner];
  }
}
