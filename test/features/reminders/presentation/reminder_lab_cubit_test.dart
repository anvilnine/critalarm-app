import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/features/reminders/data/shared_prefs_reminder_store.dart';
import 'package:critalarm/features/reminders/domain/reminder_copy.dart';
import 'package:critalarm/features/reminders/domain/reminder_ids.dart';
import 'package:critalarm/features/reminders/domain/reminder_kind.dart';
import 'package:critalarm/features/reminders/domain/reminder_plan_trigger.dart';
import 'package:critalarm/features/reminders/presentation/cubits/reminder_lab_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_in_app_notice_repository.dart';
import '../fake_reminder_scheduler.dart';

class _CountingTrigger implements ReminderPlanTrigger {
  int runs = 0;

  @override
  Future<void> run() async => runs++;
}

void main() {
  late SharedPrefsReminderStore store;
  late FakeReminderScheduler scheduler;
  late FakeInAppNoticeRepository notices;
  late _CountingTrigger trigger;
  late ReminderLabCubit cubit;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SharedPrefsReminderStore(await SharedPreferences.getInstance());
    scheduler = FakeReminderScheduler();
    notices = FakeInAppNoticeRepository()
      ..proDismissCount = 1
      ..reviewAskCount = 2;
    trigger = _CountingTrigger();
    cubit = ReminderLabCubit(
      store: store,
      notices: notices,
      scheduler: scheduler,
      copy: const ReminderCopy(isIos: true),
      trigger: trigger,
      readServerMode: () async => ServerMode.hosted,
      clock: () => DateTime.utc(2026, 9, 22, 12),
    );
  });

  test('shows the counters and what the phone holds', () async {
    await cubit.load();
    expect(cubit.state.proDismissCount, 1);
    expect(cubit.state.reviewAskCount, 2);
    expect(cubit.state.timeZone, 'UTC');
    expect(cubit.state.pending, isEmpty);
  });

  test('"In 10 s" schedules a lab id ten seconds out', () async {
    await cubit.fire(ReminderKind.backup, delay: const Duration(seconds: 10));
    final request = scheduler.scheduled[ReminderIds.lab(ReminderKind.backup)]!;
    expect(request.fireAt, DateTime(2026, 9, 22, 12, 0, 10));
    expect(cubit.state.pending.single.id, ReminderIds.lab(ReminderKind.backup));
  });

  test('"Now" still gives the platform a second', () async {
    await cubit.fire(ReminderKind.reviewAsk, delay: Duration.zero);
    final request =
        scheduler.scheduled[ReminderIds.lab(ReminderKind.reviewAsk)]!;
    expect(request.fireAt, DateTime(2026, 9, 22, 12, 0, 1));
  });

  test('Cancel drops one pending reminder', () async {
    await cubit.fire(ReminderKind.backup, delay: const Duration(seconds: 10));
    await cubit.cancel(ReminderIds.lab(ReminderKind.backup));
    expect(cubit.state.pending, isEmpty);
  });

  test('"Skip all rules" saves and re-plans', () async {
    await cubit.setSkipRules(skip: true);
    expect(store.readSkipRules(), isTrue);
    expect(cubit.state.skipRules, isTrue);
    expect(trigger.runs, 1);
  });

  test('Reset wipes the reminder flags and re-plans', () async {
    await store.markSheetShown();
    await store.writeBudgetSpentAt(DateTime(2026, 9, 20));
    await cubit.resetAll();
    expect(store.readSheetShown(), isFalse);
    expect(cubit.state.budgetSpentAt, isNull);
    expect(trigger.runs, 1);
  });

  test('the pool preview renders ten lines', () {
    expect(cubit.poolPreview(), hasLength(10));
  });
}
