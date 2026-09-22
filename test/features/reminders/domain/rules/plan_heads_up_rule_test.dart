import 'package:critalarm/features/reminders/domain/reminder_args.dart';
import 'package:critalarm/features/reminders/domain/reminder_candidate.dart';
import 'package:critalarm/features/reminders/domain/reminder_inputs.dart';
import 'package:critalarm/features/reminders/domain/rules/plan_heads_up_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 22, 8);
  const url = 'https://apps.apple.com/account/subscriptions';

  List<PlanNotice> notices(List<ReminderCandidate> list) => [
    for (final c in list)
      PlanNotice.values.byName(c.args[ReminderArgs.notice]!),
  ];

  ReminderInputs inputs(
    PlanStatus plan, {
    Set<String> sent = const {},
    DateTime? at,
    bool isHosted = true,
  }) => ReminderInputs(
    now: at ?? now,
    plan: plan,
    planNoticesSent: sent,
    isHosted: isHosted,
  );

  test('a billing issue plans the next 10:00', () {
    final list = PlanHeadsUpRule.candidates(
      inputs(
        PlanStatus(
          isActive: true,
          isYearly: false,
          willRenew: true,
          billingIssueAt: DateTime(2026, 9, 21),
          managementUrl: url,
        ),
      ),
    );
    expect(notices(list), [PlanNotice.billing]);
    expect(list.single.fireAt, DateTime(2026, 9, 22, 10));
    expect(list.single.id, 9350);
    expect(list.single.args[ReminderArgs.url], url);
  });

  test('a yearly renewal plans 3 days ahead with date and price', () {
    final c = PlanHeadsUpRule.candidates(
      inputs(
        PlanStatus(
          isActive: true,
          isYearly: true,
          willRenew: true,
          expiresAt: DateTime(2026, 10, 4, 7),
          priceString: 'PRICE',
        ),
      ),
    ).single;
    expect(c.id, 9351);
    expect(c.fireAt, DateTime(2026, 10, 1, 10));
    expect(c.args[ReminderArgs.date], '4 Oct');
    expect(c.args[ReminderArgs.price], 'PRICE');
  });

  test('monthly renewals get nothing', () {
    expect(
      PlanHeadsUpRule.candidates(
        inputs(
          PlanStatus(
            isActive: true,
            isYearly: false,
            willRenew: true,
            expiresAt: DateTime(2026, 10, 4),
          ),
        ),
      ),
      isEmpty,
    );
  });

  test('a cancelled plan warns 2 days before it ends', () {
    final c = PlanHeadsUpRule.candidates(
      inputs(
        PlanStatus(
          isActive: true,
          isYearly: false,
          willRenew: false,
          expiresAt: DateTime(2026, 10, 2, 7),
        ),
      ),
    ).single;
    expect(c.id, 9352);
    expect(c.fireAt, DateTime(2026, 9, 30, 10));
    expect(c.args[ReminderArgs.weekday], 'Friday');
  });

  test('each notice fires once per billing period', () {
    final expires = DateTime(2026, 10, 2, 7);
    expect(
      PlanHeadsUpRule.candidates(
        inputs(
          PlanStatus(
            isActive: true,
            isYearly: false,
            willRenew: false,
            expiresAt: expires,
          ),
          sent: {PlanHeadsUpRule.keyFor(PlanNotice.ends, expires)},
        ),
      ),
      isEmpty,
    );
  });

  test('nothing when the fire day already passed, off hosted, or not Pro', () {
    final yearly = PlanStatus(
      isActive: true,
      isYearly: true,
      willRenew: true,
      expiresAt: DateTime(2026, 10, 4),
      priceString: 'PRICE',
    );
    expect(
      PlanHeadsUpRule.candidates(inputs(yearly, at: DateTime(2026, 10, 2))),
      isEmpty,
    );
    expect(
      PlanHeadsUpRule.candidates(inputs(yearly, isHosted: false)),
      isEmpty,
    );
    expect(
      PlanHeadsUpRule.candidates(
        inputs(
          PlanStatus(
            isActive: false,
            isYearly: true,
            willRenew: true,
            expiresAt: DateTime(2026, 10, 4),
            priceString: 'PRICE',
          ),
        ),
      ),
      isEmpty,
    );
  });
}
