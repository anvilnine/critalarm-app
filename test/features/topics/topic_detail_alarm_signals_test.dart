import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/alarm/alarm_signal_store.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/update_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/alarm/fake_alarm_host.dart';

void main() {
  late MockServer server;
  late IncidentRepository incidentRepo;
  late UpdateTopicUsecase updateTopicUsecase;
  late IncidentsCubit incidentsCubit;
  late TopicsCubit topicsCubit;
  late FakeAlarmHost alarm;
  late SharedPreferences prefs;
  late AlarmSignalStore store;

  TopicDetailCubit build() => TopicDetailCubit(
    incidentsCubit,
    topicsCubit,
    updateTopicUsecase,
    incidentRepo,
    alarm: alarm.host,
    signalStore: store,
  );

  setUp(() async {
    server = MockServer()..seedAlarmed();
    final apiClient = MockApiClient(server);
    incidentRepo = InMemoryIncidentRepository(apiClient);
    final topicRepo = InMemoryTopicRepository(apiClient);
    updateTopicUsecase = UpdateTopicUsecase(topicRepo);
    incidentsCubit = IncidentsCubit(GetIncidentsUsecase(incidentRepo));
    topicsCubit = TopicsCubit(GetTopicsUsecase(topicRepo));
    alarm = FakeAlarmHost();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = AlarmSignalStore(prefs);
  });

  tearDown(() async {
    alarm.dispose();
    await incidentsCubit.close();
    await topicsCubit.close();
  });

  test('both switches start off', () async {
    final cubit = build();

    await cubit.load('prod-db');

    expect(cubit.state.flashOn, isFalse);
    expect(cubit.state.strongVibrationOn, isFalse);
    await cubit.close();
  });

  test('the page shows what the phone says about its flash', () async {
    alarm.answers['hasTorch'] = true;
    final withFlash = build();
    await withFlash.load('prod-db');
    expect(withFlash.state.hasTorch, isTrue);
    await withFlash.close();

    alarm.answers['hasTorch'] = false;
    final without = build();
    await without.load('prod-db');
    expect(without.state.hasTorch, isFalse);
    await without.close();
  });

  test('a phone that does not answer has no flash', () async {
    alarm.answers.remove('hasTorch');
    final cubit = build();

    await cubit.load('prod-db');

    expect(cubit.state.hasTorch, isFalse);
    await cubit.close();
  });

  test('turning the flash on saves it for this topic only', () async {
    final cubit = build();
    await cubit.load('prod-db');

    await cubit.setFlash(on: true);

    expect(cubit.state.flashOn, isTrue);
    expect(cubit.state.strongVibrationOn, isFalse);
    expect(store.read().flashFor('prod-db'), isTrue);
    expect(store.read().vibrationFor('prod-db'), isFalse);
    expect(store.read().flashTopics, {'prod-db'});
    await cubit.close();
  });

  test('turning strong vibration on saves it for this topic only', () async {
    final cubit = build();
    await cubit.load('prod-db');

    await cubit.setStrongVibration(on: true);

    expect(cubit.state.strongVibrationOn, isTrue);
    expect(cubit.state.flashOn, isFalse);
    expect(store.read().vibrationTopics, {'prod-db'});
    await cubit.close();
  });

  test('the page opens with what was saved before', () async {
    await store.setFlash('prod-db', on: true);
    await store.setStrongVibration('prod-db', on: true);
    final cubit = build();

    await cubit.load('prod-db');

    expect(cubit.state.flashOn, isTrue);
    expect(cubit.state.strongVibrationOn, isTrue);
    await cubit.close();
  });

  test('turning one off again saves that too', () async {
    await store.setFlash('prod-db', on: true);
    final cubit = build();
    await cubit.load('prod-db');

    await cubit.setFlash(on: false);

    expect(cubit.state.flashOn, isFalse);
    expect(store.read().flashFor('prod-db'), isFalse);
    await cubit.close();
  });

  test('a seed for another topic does not carry the switches over', () async {
    await store.setFlash('prod-db', on: true);
    await store.setStrongVibration('prod-db', on: true);
    final cubit = build();
    await cubit.load('prod-db');
    expect(cubit.state.flashOn, isTrue);

    final seed = cubit.seedFor('nas-backup');

    expect(seed, isNotNull);
    expect(seed!.flashOn, isFalse);
    expect(seed.strongVibrationOn, isFalse);
    await cubit.close();
  });

  test('neither switch changes the topic on the server', () async {
    final cubit = build();
    await cubit.load('prod-db');
    final before = topicsCubit.state.named('prod-db');

    await cubit.setFlash(on: true);
    await cubit.setStrongVibration(on: true);
    await topicsCubit.refresh();

    expect(topicsCubit.state.named('prod-db'), before);
    await cubit.close();
  });
}
