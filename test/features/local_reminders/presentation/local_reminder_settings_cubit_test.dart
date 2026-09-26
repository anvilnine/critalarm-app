import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/features/local_reminders/data/shared_prefs_local_reminder_store.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_plan_trigger.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_scheduler.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_switches.dart';
import 'package:critalarm/features/local_reminders/presentation/cubits/local_reminder_settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_local_reminder_scheduler.dart';

class _CountingTrigger implements LocalReminderPlanTrigger {
  int runs = 0;

  @override
  Future<void> run() async => runs++;
}

void main() {
  late SharedPrefsLocalReminderStore store;
  late FakeLocalReminderScheduler scheduler;
  late _CountingTrigger trigger;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SharedPrefsLocalReminderStore(
      await SharedPreferences.getInstance(),
    );
    scheduler = FakeLocalReminderScheduler();
    trigger = _CountingTrigger();
  });

  LocalReminderSettingsCubit build({
    ServerMode mode = ServerMode.hosted,
    Future<bool> Function()? readIsPaid,
  }) => LocalReminderSettingsCubit(
    store: store,
    scheduler: scheduler,
    readServerMode: () async => mode,
    trigger: trigger,
    readIsPaid: readIsPaid,
  );

  test('loads Reminders on, Offers off, and the OS state', () async {
    scheduler.state = const LocalReminderSystemState(
      notificationsAllowed: false,
    );
    final cubit = build();
    await cubit.load();
    expect(cubit.state.switches, LocalReminderSwitches.defaults);
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
      const LocalReminderSwitches(reminders: false, offers: true),
    );
    expect(cubit.state.switches, store.readSwitches());
    expect(trigger.runs, 2);
  });

  test('knows a self-hosted server, which hides Offers', () async {
    final cubit = build(mode: ServerMode.selfhosted);
    await cubit.load();
    expect(cubit.state.isSelfHosted, isTrue);
  });

  test('shows Offers to a free hosted user', () async {
    final cubit = build(readIsPaid: () async => false);
    await cubit.load();
    expect(cubit.state.isPaid, isFalse);
    expect(cubit.state.showsOffers, isTrue);
  });

  test('a paid user does not see Offers', () async {
    final cubit = build(readIsPaid: () async => true);
    await cubit.load();
    expect(cubit.state.isPaid, isTrue);
    expect(cubit.state.showsOffers, isFalse);
  });

  test('a failed paid read hides Offers', () async {
    final cubit = build(readIsPaid: () async => throw StateError('keychain'));
    await cubit.load();
    expect(cubit.state.showsOffers, isFalse);
  });
}
