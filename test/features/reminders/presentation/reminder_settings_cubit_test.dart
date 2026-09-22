import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/features/reminders/data/shared_prefs_reminder_store.dart';
import 'package:critalarm/features/reminders/domain/reminder_plan_trigger.dart';
import 'package:critalarm/features/reminders/domain/reminder_scheduler.dart';
import 'package:critalarm/features/reminders/domain/reminder_switches.dart';
import 'package:critalarm/features/reminders/presentation/cubits/reminder_settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_reminder_scheduler.dart';

class _CountingTrigger implements ReminderPlanTrigger {
  int runs = 0;

  @override
  Future<void> run() async => runs++;
}

void main() {
  late SharedPrefsReminderStore store;
  late FakeReminderScheduler scheduler;
  late _CountingTrigger trigger;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SharedPrefsReminderStore(await SharedPreferences.getInstance());
    scheduler = FakeReminderScheduler();
    trigger = _CountingTrigger();
  });

  ReminderSettingsCubit build({ServerMode mode = ServerMode.hosted}) =>
      ReminderSettingsCubit(
        store: store,
        scheduler: scheduler,
        readServerMode: () async => mode,
        trigger: trigger,
      );

  test('loads Reminders on, Offers off, and the OS state', () async {
    scheduler.state = const ReminderSystemState(notificationsAllowed: false);
    final cubit = build();
    await cubit.load();
    expect(cubit.state.switches, ReminderSwitches.defaults);
    expect(cubit.state.notificationsAllowed, isFalse);
    expect(cubit.state.isSelfHosted, isFalse);
    expect(cubit.state.isLoaded, isTrue);
  });

  test('a switch saves and starts a plan pass', () async {
    final cubit = build();
    await cubit.load();
    await cubit.setReminders(isOn: false);
    await cubit.setOffers(isOn: true);
    expect(
      store.readSwitches(),
      const ReminderSwitches(reminders: false, offers: true),
    );
    expect(cubit.state.switches, store.readSwitches());
    expect(trigger.runs, 2);
  });

  test('knows a self-hosted server, which hides Offers', () async {
    final cubit = build(mode: ServerMode.selfhosted);
    await cubit.load();
    expect(cubit.state.isSelfHosted, isTrue);
  });
}
