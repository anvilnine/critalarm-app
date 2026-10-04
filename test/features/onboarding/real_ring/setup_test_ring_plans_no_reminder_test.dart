import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/features/in_app_notices/domain/setup_gate.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/trigger_test_alarm_usecase.dart';
import 'package:critalarm/features/local_reminders/data/shared_prefs_local_reminder_store.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_copy.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_ids.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_inputs.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_plan_pass.dart';
import 'package:critalarm/features/local_reminders/domain/local_reminder_settler.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/fake_in_app_notice_repository.dart';
import '../../local_reminders/fake_local_reminder_scheduler.dart';

/// The test ring goes through `TriggerTestAlarmUsecase`, whose `onTested`
/// hook plans the Local Reminders again. Setup shows no Local Reminder, so a
/// ring during setup must plan nothing. The plan pass waits for `SetupGate`,
/// wired here the way the app wires it.
void main() {
  late SharedPrefsLocalReminderStore store;
  late FakeLocalReminderScheduler scheduler;
  late bool isOnboardingDone;
  late bool hasSeenFeatureGuide;
  final passes = <Future<void>>[];

  // A topic that is due a fire drill, so a pass that runs has something to
  // plan.
  LocalReminderInputs inputs() => LocalReminderInputs(
    now: DateTime(2026, 9, 22, 12),
    topics: const [LocalReminderTopic(name: 'prod-db', isCritical: true)],
    lastTestAt: {'prod-db': DateTime(2026, 8, 20)},
  );

  TriggerTestAlarmUsecase build() {
    final gate = SetupGate(
      isOnboardingDone: () async => isOnboardingDone,
      hasSeenFeatureGuide: () => hasSeenFeatureGuide,
    );
    final pass = LocalReminderPlanPass(
      store: store,
      scheduler: scheduler,
      settler: LocalReminderSettler(
        store: store,
        notices: FakeInAppNoticeRepository(),
      ),
      readInputs: () async => inputs(),
      copy: const LocalReminderCopy(isIos: true),
      isPaused: () async => !await gate.isDone(),
      isWeb: false,
      clock: () => DateTime.utc(2026, 9, 22, 12),
    );
    return TriggerTestAlarmUsecase(
      InMemoryIncidentRepository(MockApiClient(MockServer()..seedCalm())),
      localReminderStore: store,
      onTested: (_) => passes.add(pass.run()),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SharedPrefsLocalReminderStore(
      await SharedPreferences.getInstance(),
    );
    scheduler = FakeLocalReminderScheduler();
    passes.clear();
  });

  test('a test ring during setup plans no Local Reminder', () async {
    isOnboardingDone = false;
    hasSeenFeatureGuide = false;

    final result = await build()('prod-db');
    await Future.wait(passes);

    expect(result.isSuccess(), isTrue);
    // The hook ran, and the gate held the pass.
    expect(passes, hasLength(1));
    expect(scheduler.scheduled, isEmpty);
    expect(store.readPlanned(), isEmpty);
  });

  test(
    'setup finished but the Topics guide unanswered still plans none',
    () async {
      isOnboardingDone = true;
      hasSeenFeatureGuide = false;

      await build()('prod-db');
      await Future.wait(passes);

      expect(scheduler.scheduled, isEmpty);
    },
  );

  test('the same ring after setup is done does plan', () async {
    // The control: without the gate the pass schedules, so the two tests
    // above pass because of the gate and not because nothing was due.
    isOnboardingDone = true;
    hasSeenFeatureGuide = true;

    await build()('prod-db');
    await Future.wait(passes);

    expect(scheduler.scheduled, isNotEmpty);
    expect(scheduler.scheduled.keys, contains(LocalReminderIds.drill));
  });
}
