import 'package:critalarm/core/alarm/quiet_hours.dart';
import 'package:critalarm/features/reminders/domain/reminder_budget.dart';
import 'package:critalarm/features/reminders/domain/reminder_candidate.dart';
import 'package:critalarm/features/reminders/domain/reminder_inputs.dart';
import 'package:critalarm/features/reminders/domain/reminder_kind.dart';
import 'package:critalarm/features/reminders/domain/reminder_planner.dart';
import 'package:critalarm/features/reminders/domain/reminder_switches.dart';
import 'package:critalarm/features/reminders/domain/reminder_time_rules.dart';
import 'package:critalarm/features/reminders/domain/self_hosted_matrix.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planner = ReminderPlanner();
  const rules = ReminderTimeRules(quietHours: QuietHours.defaults);
  // Tuesday 22 September 2026.
  final now = DateTime(2026, 9, 22, 12);

  ReminderCandidate candidate(
    ReminderKind kind,
    DateTime fireAt, {
    bool isOverdue = false,
  }) => ReminderCandidate(
    kind: kind,
    id: 9000 + kind.index,
    fireAt: fireAt,
    isOverdue: isOverdue,
  );

  // A drill (Saturday 26 September) and a silent topic (23 September).
  ReminderInputs busy({
    ReminderSwitches switches = ReminderSwitches.defaults,
    bool isSelfHosted = false,
    bool isWeb = false,
    DateTime? budgetSpentAt,
    QuietHours quietHours = QuietHours.defaults,
  }) => ReminderInputs(
    now: now,
    switches: switches,
    isSelfHosted: isSelfHosted,
    isHosted: !isSelfHosted,
    isWeb: isWeb,
    budgetSpentAt: budgetSpentAt,
    quietHours: quietHours,
    topics: const [
      ReminderTopic(name: 'prod-db', isCritical: true),
      ReminderTopic(name: 'fresh'),
    ],
    lastTestAt: {'prod-db': DateTime(2026, 8)},
    topicsCreatedHere: {'fresh': DateTime(2026, 9, 22, 15)},
    silentTopicNames: const {'fresh'},
  );

  group('SelfHostedMatrix', () {
    test('matches the spec table', () {
      expect(SelfHostedMatrix.allows(ReminderKind.fireDrill), isTrue);
      expect(SelfHostedMatrix.allows(ReminderKind.silentTopic), isTrue);
      expect(SelfHostedMatrix.allows(ReminderKind.backup), isFalse);
      expect(SelfHostedMatrix.allows(ReminderKind.planHeadsUp), isFalse);
      expect(SelfHostedMatrix.allows(ReminderKind.morningAfter), isFalse);
      expect(SelfHostedMatrix.allows(ReminderKind.proLater), isFalse);
      expect(SelfHostedMatrix.allows(ReminderKind.reviewAsk), isTrue);
      expect(SelfHostedMatrix.allows(ReminderKind.feedbackAsk), isTrue);
      expect(SelfHostedMatrix.showsOffers, isFalse);
    });
  });

  group('ReminderBudget.pick', () {
    test('priority 1 > 10 > 2 > 7 > 21 > 22 inside one week', () {
      final order = [
        ReminderKind.fireDrill,
        ReminderKind.morningAfter,
        ReminderKind.silentTopic,
        ReminderKind.backup,
        ReminderKind.reviewAsk,
        ReminderKind.feedbackAsk,
      ];
      for (var i = 0; i < order.length - 1; i++) {
        final winner = ReminderBudget.pick(
          [
            candidate(order[i + 1], DateTime(2026, 9, 23, 10)),
            candidate(order[i], DateTime(2026, 9, 25, 10)),
          ],
          spentAt: null,
          rules: rules,
        );
        expect(
          winner!.kind,
          order[i],
          reason: '${order[i]} beats ${order[i + 1]}',
        );
      }
    });

    test('a later, higher priority reminder does not starve a sooner one', () {
      final winner = ReminderBudget.pick(
        [
          candidate(ReminderKind.feedbackAsk, DateTime(2026, 9, 22, 10)),
          candidate(ReminderKind.backup, DateTime(2026, 10, 5, 10)),
        ],
        spentAt: null,
        rules: rules,
      );
      expect(winner!.kind, ReminderKind.feedbackAsk);
    });

    test('an overdue drill wins outright', () {
      final winner = ReminderBudget.pick(
        [
          candidate(ReminderKind.morningAfter, DateTime(2026, 9, 23, 9)),
          candidate(
            ReminderKind.fireDrill,
            DateTime(2026, 9, 26, 10),
            isOverdue: true,
          ),
        ],
        spentAt: null,
        rules: rules,
      );
      expect(winner!.kind, ReminderKind.fireDrill);
    });

    test('a spent slot pushes the winner a week past the last one', () {
      final winner = ReminderBudget.pick(
        [candidate(ReminderKind.silentTopic, DateTime(2026, 9, 23, 15))],
        spentAt: DateTime(2026, 9, 20, 10),
        rules: rules,
      );
      expect(winner!.fireAt, DateTime(2026, 9, 27, 10));
    });

    test('a spent slot moves a drill to the next open Saturday', () {
      final winner = ReminderBudget.pick(
        [candidate(ReminderKind.fireDrill, DateTime(2026, 9, 26, 10))],
        spentAt: DateTime(2026, 9, 21, 10),
        rules: rules,
      );
      expect(winner!.fireAt, DateTime(2026, 10, 3, 10));
    });

    test('a spent slot drops the morning after instead of moving it', () {
      expect(
        ReminderBudget.pick(
          [candidate(ReminderKind.morningAfter, DateTime(2026, 9, 23, 9))],
          spentAt: DateTime(2026, 9, 20, 10),
          rules: rules,
        ),
        isNull,
      );
    });

    test('a spent slot re-snaps the feedback ask to Tue, Wed or Thu 10:00', () {
      // A drill spends the slot Saturday 26 September; the feedback ask due
      // Tuesday 29 September would otherwise move to Saturday 3 October.
      final winner = ReminderBudget.pick(
        [candidate(ReminderKind.feedbackAsk, DateTime(2026, 9, 29, 10))],
        spentAt: DateTime(2026, 9, 26, 10),
        rules: rules,
      );
      expect(winner!.fireAt, DateTime(2026, 10, 6, 10));
      expect(
        [DateTime.tuesday, DateTime.wednesday, DateTime.thursday],
        contains(winner.fireAt.weekday),
      );
    });

    test('ignores a candidate whose kind does not use the weekly budget', () {
      expect(
        ReminderBudget.pick(
          [candidate(ReminderKind.planHeadsUp, DateTime(2026, 9, 22, 10))],
          spentAt: null,
          rules: rules,
        ),
        isNull,
      );
    });
  });

  group('ReminderBudget.snapFeedbackAsk', () {
    test('keeps a Tuesday, Wednesday or Thursday 10:00 as is', () {
      // Tuesday 29 September 2026, already allowed.
      final snapped = ReminderBudget.snapFeedbackAsk(
        DateTime(2026, 9, 29, 10),
        rules,
      );
      expect(snapped, DateTime(2026, 9, 29, 10));
    });

    test('moves a Saturday to the next Tuesday at 10:00', () {
      final snapped = ReminderBudget.snapFeedbackAsk(
        DateTime(2026, 10, 3, 10),
        rules,
      );
      expect(snapped, DateTime(2026, 10, 6, 10));
    });

    test('a blocked Thursday moves to the next Tuesday, not Friday', () {
      // Thursday 24 September 2026, 10:00 held by a ring two hours before.
      final blocked = ReminderTimeRules(
        quietHours: QuietHours.defaults,
        ringsAt: [DateTime(2026, 9, 24, 9)],
      );
      final snapped = ReminderBudget.snapFeedbackAsk(
        DateTime(2026, 9, 24, 10),
        blocked,
      );
      expect(snapped, DateTime(2026, 9, 29, 10));
    });
  });

  group('ReminderPlanner.plan', () {
    test('plans nothing on web', () {
      expect(planner.plan(busy(isWeb: true)), isEmpty);
    });

    test('plans one budgeted reminder, the drill', () {
      final plan = planner.plan(busy());
      expect(plan.map((c) => c.kind), [ReminderKind.fireDrill]);
    });

    test('Reminders off plans none of 1, 2, 7, 8, 21, 22', () {
      // Inputs that would produce a candidate for every one of those ideas
      // with Reminders on: a stale critical topic (1), a silent fresh one
      // (2), two topics on a signed-out hosted phone (7), a billing issue
      // (8), an ack four days back (21), and three weeks installed (22).
      final inputs = ReminderInputs(
        now: now,
        switches: const ReminderSwitches(reminders: false, offers: true),
        topics: [
          ReminderTopic(
            name: 'prod-db',
            isCritical: true,
            createdAt: DateTime(2026, 8),
          ),
          ReminderTopic(name: 'fresh', createdAt: DateTime(2026, 8, 2)),
        ],
        lastTestAt: {'prod-db': DateTime(2026, 8)},
        topicsCreatedHere: {'fresh': DateTime(2026, 9, 22, 15)},
        silentTopicNames: const {'fresh'},
        plan: PlanStatus(
          isActive: true,
          isYearly: false,
          willRenew: true,
          billingIssueAt: DateTime(2026, 9, 21),
        ),
        installedAt: DateTime(2026, 9, 1, 9),
        consentAskedAt: DateTime(2026, 9, 2),
        lastAcknowledgedAt: DateTime(2026, 9, 20, 23),
        feedbackFormUrl: 'https://example.com/feedback',
      );
      expect(planner.plan(inputs), isEmpty);
    });

    test('Offers off drops the morning after', () {
      final inputs = ReminderInputs(
        now: DateTime(2026, 9, 23, 7),
        proShouldAsk: true,
        incidents: [
          ReminderIncident(
            id: 'inc_1',
            topic: 'db-2',
            openedAt: DateTime(2026, 9, 23, 3),
            ackedAt: DateTime(2026, 9, 23, 3, 1),
          ),
        ],
      );
      expect(planner.plan(inputs), isEmpty);
      final on = planner.plan(
        ReminderInputs(
          now: inputs.now,
          proShouldAsk: true,
          incidents: inputs.incidents,
          switches: const ReminderSwitches(reminders: true, offers: true),
        ),
      );
      expect(on.map((c) => c.kind), [ReminderKind.morningAfter]);
    });

    test('plan heads-up skips the budget', () {
      final plan = planner.plan(
        ReminderInputs(
          now: now,
          topics: const [ReminderTopic(name: 'prod-db', isCritical: true)],
          lastTestAt: {'prod-db': DateTime(2026, 8)},
          plan: PlanStatus(
            isActive: true,
            isYearly: false,
            willRenew: true,
            billingIssueAt: DateTime(2026, 9, 21),
          ),
        ),
      );
      expect(
        plan.map((c) => c.kind).toSet(),
        {ReminderKind.fireDrill, ReminderKind.planHeadsUp},
      );
    });

    test('self-hosted keeps the drill and drops the backup', () {
      final plan = planner.plan(
        ReminderInputs(
          now: now,
          isSelfHosted: true,
          isHosted: false,
          topics: [
            ReminderTopic(
              name: 'prod-db',
              isCritical: true,
              createdAt: DateTime(2026, 8),
            ),
            ReminderTopic(name: 'db-2', createdAt: DateTime(2026, 8, 2)),
          ],
          lastTestAt: {'prod-db': DateTime(2026, 8)},
        ),
      );
      expect(plan.map((c) => c.kind), [ReminderKind.fireDrill]);
    });

    test('self-hosted still plans the review and feedback asks', () {
      final plan = planner.plan(
        ReminderInputs(
          now: DateTime(2026, 9, 21, 12),
          isSelfHosted: true,
          isHosted: false,
          installedAt: DateTime(2026, 9, 1, 9),
          consentAskedAt: DateTime(2026, 9, 2),
          lastAcknowledgedAt: DateTime(2026, 9, 20, 23),
        ),
      );
      expect(plan.map((c) => c.kind), [ReminderKind.reviewAsk]);
    });

    test('moves a late evening silent topic to 10:00 next day', () {
      final plan = planner.plan(
        ReminderInputs(
          now: now,
          topics: const [ReminderTopic(name: 'fresh')],
          topicsCreatedHere: {'fresh': DateTime(2026, 9, 21, 23)},
          silentTopicNames: const {'fresh'},
        ),
      );
      expect(plan.single.fireAt, DateTime(2026, 9, 23, 10));
    });

    test('user quiet hours move the drill to the first open hour', () {
      final plan = planner.plan(
        busy(
          quietHours: const QuietHours(
            isEnabled: true,
            startMinutes: 9 * 60,
            endMinutes: 11 * 60,
            criticalRingsThrough: true,
          ),
        ),
      );
      expect(plan.single.fireAt, DateTime(2026, 9, 26, 11));
    });

    test('the lab switch skips the time rules and the budget', () {
      final plan = planner.plan(
        ReminderInputs(
          now: now,
          skipRules: true,
          topics: const [
            ReminderTopic(name: 'prod-db', isCritical: true),
            ReminderTopic(name: 'fresh'),
          ],
          lastTestAt: {'prod-db': DateTime(2026, 8)},
          topicsCreatedHere: {'fresh': DateTime(2026, 9, 21, 23)},
          silentTopicNames: const {'fresh'},
        ),
      );
      expect(plan, hasLength(2));
    });
  });
}
