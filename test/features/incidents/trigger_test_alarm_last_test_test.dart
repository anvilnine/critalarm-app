import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/trigger_test_alarm_usecase.dart';
import 'package:critalarm/features/local_reminders/data/shared_prefs_local_reminder_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPrefsLocalReminderStore store;
  late TriggerTestAlarmUsecase usecase;
  late List<String> tested;
  final at = DateTime(2026, 9, 22, 14);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SharedPrefsLocalReminderStore(
      await SharedPreferences.getInstance(),
    );
    tested = [];
    usecase = TriggerTestAlarmUsecase(
      InMemoryIncidentRepository(MockApiClient(MockServer()..seedCalm())),
      localReminderStore: store,
      now: () => at,
      onTested: (topic) {
        // The stamp is already written when the hook runs.
        expect(store.readLastTestAt(), {topic: at});
        tested.add(topic);
      },
    );
  });

  test('stamps lastTestAt for the topic on success', () async {
    final result = await usecase('prod-db');
    expect(result.isSuccess(), isTrue);
    expect(store.readLastTestAt(), {'prod-db': at});
  });

  test('leaves lastTestAt alone on a 409', () async {
    final result = await usecase('nas-backup');
    expect(result.isError(), isTrue);
    expect(store.readLastTestAt(), isEmpty);
  });

  test('tells onTested about a success only', () async {
    await usecase('prod-db');
    await usecase('nas-backup');
    expect(tested, ['prod-db']);
  });

  test('a throwing onTested never fails the test ring', () async {
    final throwing = TriggerTestAlarmUsecase(
      InMemoryIncidentRepository(MockApiClient(MockServer()..seedCalm())),
      localReminderStore: store,
      now: () => at,
      onTested: (_) => throw StateError('boom'),
    );
    expect((await throwing('prod-db')).isSuccess(), isTrue);
  });
}
