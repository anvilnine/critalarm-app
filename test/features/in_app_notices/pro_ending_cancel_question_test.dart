import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/models/device_identity.dart';
import 'package:critalarm/features/in_app_notices/domain/pro_ending.dart';
import 'package:critalarm/features/local_reminders/domain/device_time_zone.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_inputs.dart';
import 'package:critalarm/features/local_reminders/domain/plan_status_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_in_app_notice_repository.dart';

class _Plan implements PlanStatusSource {
  PlanStatus? status;
  @override
  Future<PlanStatus?> read(DeviceTimeZone timeZone) async => status;
}

void main() {
  const manila = DeviceTimeZone(name: 'Asia/Manila', offsetMinutes: 480);
  const newYork = DeviceTimeZone(name: 'America/New_York', offsetMinutes: -240);
  final clock = DateTime(2026, 10, 1, 12);
  final instant = DateTime.utc(2026, 10, 20, 9, 15, 2);

  late FakeInAppNoticeRepository notices;
  late _Plan plan;

  ProEnding endingIn(DeviceTimeZone zone) => ProEnding(
    notices: notices,
    plan: plan,
    readIdentity: () async => const DeviceIdentity(
      deviceId: 'dev_1',
      accountId: 'acc_1',
      tier: 'hosted',
    ),
    readServerSaysHosted: () async => true,
    readServerMode: () async => ServerMode.hosted,
    refreshRegistration: () async {},
    now: () => clock,
    timeZone: () => zone,
  );

  PlanStatus cancelled({
    DateTime? wall,
    DateTime? at,
    DateTime? billingIssueAt,
  }) => PlanStatus(
    isActive: true,
    isYearly: false,
    willRenew: false,
    expiresAt: wall ?? DateTime(2026, 10, 20, 17, 15, 2),
    expiresAtInstant: at,
    billingIssueAt: billingIssueAt,
  );

  setUp(() {
    notices = FakeInAppNoticeRepository()..now = () => clock;
    plan = _Plan();
  });

  test('a billing issue shows on the ending view and on the pill', () async {
    plan.status = cancelled(
      at: instant,
      billingIssueAt: DateTime(2026, 9, 21, 9),
    );
    final ending = endingIn(manila);
    final first = await ending.read();
    expect(first.sheet, ProPlanSheet.ending);
    expect(first.hasBillingIssue, isTrue);

    await ending.markEndingSheetShown(first.endsAt!);
    final pill = await endingIn(manila).read();
    expect(pill.showPill, isTrue);
    expect(pill.hasBillingIssue, isTrue);
  });

  test('without a billing issue the flag is false', () async {
    plan.status = cancelled(at: instant);
    final ending = endingIn(manila);
    final first = await ending.read();
    expect(first.hasBillingIssue, isFalse);

    await ending.markEndingSheetShown(first.endsAt!);
    expect((await endingIn(manila).read()).hasBillingIssue, isFalse);
  });

  test('the view defaults to no billing issue and no instant', () {
    expect(ProEndingView.nothing.hasBillingIssue, isFalse);
    expect(ProEndingView.nothing.endsAtInstant, isNull);
  });

  test('endsAtInstant is the plan instant in every zone', () async {
    plan.status = cancelled(
      wall: DateTime(2026, 10, 20, 17, 15, 2),
      at: instant,
    );
    final inManila = await endingIn(manila).read();

    plan.status = cancelled(
      wall: DateTime(2026, 10, 20, 5, 15, 2),
      at: instant,
    );
    final inNewYork = await endingIn(newYork).read();

    expect(inManila.endsAt, isNot(inNewYork.endsAt));
    expect(inManila.endsAtInstant, instant);
    expect(inNewYork.endsAtInstant, instant);
  });

  test('a plan with no instant gives a null endsAtInstant', () async {
    plan.status = cancelled();
    final view = await endingIn(manila).read();
    expect(view.sheet, ProPlanSheet.ending);
    expect(view.endsAtInstant, isNull);
  });
}
