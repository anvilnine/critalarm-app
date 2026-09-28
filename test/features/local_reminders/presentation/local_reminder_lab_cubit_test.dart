import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/features/local_reminders/data/shared_prefs_local_reminder_store.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_copy.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_ids.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_kind.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_plan_trigger.dart';
import 'package:critalarm/features/local_reminders/presentation/cubits/local_reminder_lab_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_in_app_notice_repository.dart';
import '../fake_local_reminder_scheduler.dart';

class _CountingTrigger implements LocalReminderPlanTrigger {
  int runs = 0;

  @override
  Future<void> run() async => runs++;
}

void main() {
  late SharedPrefsLocalReminderStore store;
  late FakeLocalReminderScheduler scheduler;
  late FakeInAppNoticeRepository notices;
  late _CountingTrigger trigger;
  late LocalReminderLabCubit cubit;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SharedPrefsLocalReminderStore(
      await SharedPreferences.getInstance(),
    );
    scheduler = FakeLocalReminderScheduler();
    notices = FakeInAppNoticeRepository()
      ..proDismissCount = 1
      ..reviewAskCount = 2;
    trigger = _CountingTrigger();
    cubit = LocalReminderLabCubit(
      store: store,
      notices: notices,
      scheduler: scheduler,
      copy: const LocalReminderCopy(isIos: true),
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
    await cubit.fire(
      LocalReminderKind.backup,
      delay: const Duration(seconds: 10),
    );
    final request =
        scheduler.scheduled[LocalReminderIds.lab(LocalReminderKind.backup)]!;
    expect(request.fireAt, DateTime(2026, 9, 22, 12, 0, 10));
    expect(
      cubit.state.pending.single.id,
      LocalReminderIds.lab(LocalReminderKind.backup),
    );
  });

  test('"Now" still gives the platform a second', () async {
    await cubit.fire(LocalReminderKind.reviewAsk, delay: Duration.zero);
    final request =
        scheduler.scheduled[LocalReminderIds.lab(LocalReminderKind.reviewAsk)]!;
    expect(request.fireAt, DateTime(2026, 9, 22, 12, 0, 1));
  });

  test('Cancel drops one pending reminder', () async {
    await cubit.fire(
      LocalReminderKind.backup,
      delay: const Duration(seconds: 10),
    );
    await cubit.cancel(LocalReminderIds.lab(LocalReminderKind.backup));
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
