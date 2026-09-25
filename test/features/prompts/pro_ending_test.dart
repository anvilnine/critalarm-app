import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/models/device_identity.dart';
import 'package:critalarm/features/prompts/domain/pro_ending.dart';
import 'package:critalarm/features/reminders/domain/device_time_zone.dart';
import 'package:critalarm/features/reminders/domain/plan_status_source.dart';
import 'package:critalarm/features/reminders/domain/reminder_inputs.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_home_prompt_repository.dart';

class _Plan implements PlanStatusSource {
  PlanStatus? status;
  @override
  Future<PlanStatus?> read(DeviceTimeZone timeZone) async => status;
}

void main() {
  late FakeHomePromptRepository prompts;
  late _Plan plan;
  late DeviceIdentity identity;
  late ServerMode mode;
  late DateTime clock;
  late int refreshes;
  late int paidChanges;
  late ProEnding ending;

  final endsAt = DateTime(2026, 10, 20, 9);

  DeviceIdentity account(String id, String tier) =>
      DeviceIdentity(deviceId: 'dev_1', accountId: id, tier: tier);

  PlanStatus cancelled() => PlanStatus(
    isActive: true,
    isYearly: false,
    willRenew: false,
    expiresAt: endsAt,
  );

  setUp(() {
    prompts = FakeHomePromptRepository();
    plan = _Plan();
    identity = account('acc_1', 'hosted');
    mode = ServerMode.hosted;
    clock = DateTime(2026, 10, 1, 12);
    refreshes = 0;
    paidChanges = 0;
    prompts.now = () => clock;
    ending = ProEnding(
      prompts: prompts,
      plan: plan,
      readIdentity: () async => identity,
      readServerMode: () async => mode,
      refreshRegistration: () async => refreshes++,
      onPaidChanged: () => paidChanges++,
      now: () => clock,
      timeZone: () => DeviceTimeZone.utc,
    );
  });

  test('a renewing plan shows nothing', () async {
    plan.status = PlanStatus(
      isActive: true,
      isYearly: false,
      willRenew: true,
      expiresAt: endsAt,
    );
    final view = await ending.read();
    expect(view.sheet, ProPlanSheet.none);
    expect(view.showPill, isFalse);
  });

  test('a first cancel asks for the ending sheet', () async {
    plan.status = cancelled();
    final view = await ending.read();
    expect(view.sheet, ProPlanSheet.ending);
    expect(view.endsAt, endsAt);
  });

  test('after the sheet, the pill shows', () async {
    plan.status = cancelled();
    await ending.markEndingSheetShown(endsAt);
    final view = await ending.read();
    expect(view.sheet, ProPlanSheet.none);
    expect(view.showPill, isTrue);
  });

  test('closing the pill in the last 2 days keeps it gone', () async {
    plan.status = cancelled();
    await ending.markEndingSheetShown(endsAt);
    clock = DateTime(2026, 10, 19);
    await ending.dismissPill(endsAt);
    expect((await ending.read()).showPill, isFalse);
  });

  test('self-hosted shows nothing', () async {
    mode = ServerMode.selfhosted;
    plan.status = cancelled();
    expect((await ending.read()).sheet, ProPlanSheet.none);
  });

  test(
    'paid then free on the same account shows the ended sheet once',
    () async {
      await ending.read();
      identity = account('acc_1', 'free');
      expect((await ending.read()).sheet, ProPlanSheet.ended);
      await ending.markEndedSheetShown();
      expect((await ending.read()).sheet, ProPlanSheet.none);
    },
  );

  test('paid account A then free account B shows nothing', () async {
    await ending.read();
    identity = account('acc_2', 'free');
    expect((await ending.read()).sheet, ProPlanSheet.none);
  });

  test('free to paid clears a pending ended sheet', () async {
    await ending.read();
    identity = account('acc_1', 'free');
    await ending.read();
    identity = account('acc_1', 'hosted');
    expect((await ending.read()).sheet, ProPlanSheet.none);
    expect(prompts.proEndedDue, isFalse);
  });

  test('a known expiry that passed asks the server again', () async {
    prompts.proKnownExpiry = DateTime(2026, 9, 30);
    await ending.read();
    expect(refreshes, 1);
  });

  test(
    'past known expiry but still paid after refresh shows nothing',
    () async {
      prompts.proKnownExpiry = DateTime(2026, 9, 30);
      final view = await ending.read();
      expect(view.sheet, ProPlanSheet.none);
    },
  );

  test('refresh runs at most once per 5 minutes', () async {
    prompts.proKnownExpiry = DateTime(2026, 9, 30);
    await ending.read();
    await ending.read();
    expect(refreshes, 1);
    clock = clock.add(const Duration(minutes: 5));
    await ending.read();
    expect(refreshes, 2);
  });

  test('a failed refresh does not throw', () async {
    ending = ProEnding(
      prompts: prompts,
      plan: plan,
      readIdentity: () async => identity,
      readServerMode: () async => mode,
      refreshRegistration: () async => throw StateError('offline'),
      now: () => clock,
      timeZone: () => DeviceTimeZone.utc,
    );
    prompts.proKnownExpiry = DateTime(2026, 9, 30);
    expect((await ending.read()).sheet, ProPlanSheet.none);
  });

  test('a change between free and paid tells the widgets', () async {
    await ending.read();
    expect(paidChanges, 0);
    identity = account('acc_1', 'free');
    await ending.read();
    expect(paidChanges, 1);
  });
}
