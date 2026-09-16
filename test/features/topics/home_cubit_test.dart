import 'package:bloc_test/bloc_test.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/design/components/chips.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/home_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockServer server;
  late MockApiClient apiClient;
  late TopicRepository topicRepo;
  late IncidentRepository incidentRepo;
  late IncidentsCubit incidentsCubit;
  late TopicsCubit topicsCubit;

  setUp(() {
    server = MockServer();
    apiClient = MockApiClient(server);
    topicRepo = InMemoryTopicRepository(apiClient);
    incidentRepo = InMemoryIncidentRepository(apiClient);
    incidentsCubit = IncidentsCubit(GetIncidentsUsecase(incidentRepo));
    topicsCubit = TopicsCubit(GetTopicsUsecase(topicRepo));
  });

  tearDown(() async {
    await incidentsCubit.close();
    await topicsCubit.close();
  });

  group('HomeCubit', () {
    test('initial state has calm face and no stage word yet', () {
      final cubit = HomeCubit(incidentsCubit, topicsCubit, incidentRepo);
      expect(cubit.state.status, HomeStatus.initial);
      expect(cubit.state.faceState, FaceState.calm);
      // The stage word is written by load(), so it is blank until then.
      expect(cubit.state.word, '');
      expect(cubit.state.severity, SeverityMode.none);
    });

    blocTest<HomeCubit, HomeState>(
      'a calm topic reports how it is set up, not the priority of the last '
      'page it took',
      setUp: () => server.seedCalm(),
      build: () => HomeCubit(incidentsCubit, topicsCubit, incidentRepo),
      act: (cubit) => cubit.load(),
      skip: 1,
      expect: () => [
        isA<HomeState>()
            // prod-db still carries priority 5 from a page that was
            // acknowledged, so the row must not show it. Nothing is open and
            // nothing is warning, so every topic is at rest.
            .having(
              (s) => s.topicItems.every((t) => !t.isLive),
              'no topic is live',
              isTrue,
            )
            .having(
              (s) => s.topicItems[0].ringsThroughSilent,
              'prod-db rings through silent',
              isTrue,
            )
            .having(
              (s) => s.topicItems[1].ringsThroughSilent,
              'nas-backup rings through silent',
              isFalse,
            ),
      ],
    );

    blocTest<HomeCubit, HomeState>(
      'a topic with an open incident is live, so the row shows the priority '
      'that came in',
      setUp: () => server.seedAlarmed(),
      build: () => HomeCubit(incidentsCubit, topicsCubit, incidentRepo),
      act: (cubit) => cubit.load(),
      skip: 1,
      expect: () => [
        isA<HomeState>().having(
          (s) => s.topicItems.any((t) => t.isLive),
          'at least one topic is live',
          isTrue,
        ),
      ],
    );

    blocTest<HomeCubit, HomeState>(
      'calm fixture uses current server data for every topic',
      setUp: () => server.seedCalm(),
      build: () => HomeCubit(incidentsCubit, topicsCubit, incidentRepo),
      act: (cubit) => cubit.load(),
      expect: () => [
        const HomeState(status: HomeStatus.loading),
        isA<HomeState>()
            .having((s) => s.status, 'status', HomeStatus.success)
            .having((s) => s.faceState, 'faceState', FaceState.calm)
            .having((s) => s.word, 'word', 'All clear')
            .having((s) => s.severity, 'severity', SeverityMode.none)
            .having((s) => s.topicItems.length, 'topics length', 4)
            .having(
              (s) => s.topicItems[0].name,
              'first topic',
              'prod-db',
            )
            .having(
              (s) => s.topicItems[0].priority,
              'prod-db priority',
              PriorityLevel.critical,
            )
            .having(
              (s) => s.topicItems[1].name,
              'second topic',
              'nas-backup',
            )
            .having(
              (s) => s.topicItems[1].priority,
              'nas-backup priority',
              PriorityLevel.defaultPriority,
            )
            .having(
              (s) => s.topicItems[2].name,
              'third topic',
              'uptime-kuma',
            )
            .having(
              (s) => s.topicItems[2].priority,
              'uptime-kuma priority',
              PriorityLevel.defaultPriority,
            )
            .having(
              (s) => s.topicItems[3].name,
              'fourth topic',
              'home-ha',
            )
            .having(
              (s) => s.topicItems[3].priority,
              'home-ha priority',
              PriorityLevel.defaultPriority,
            ),
      ],
    );

    blocTest<HomeCubit, HomeState>(
      'worried fixture: emits worried face, 1 warning, severity high',
      setUp: () => server.seedWorried(),
      build: () => HomeCubit(incidentsCubit, topicsCubit, incidentRepo),
      act: (cubit) => cubit.load(),
      expect: () => [
        const HomeState(status: HomeStatus.loading),
        isA<HomeState>()
            .having((s) => s.status, 'status', HomeStatus.success)
            .having((s) => s.faceState, 'faceState', FaceState.worried)
            .having((s) => s.word, 'word', '1 warning')
            .having((s) => s.severity, 'severity', SeverityMode.high),
      ],
    );

    blocTest<HomeCubit, HomeState>(
      'alarmed fixture: emits alarmed face, CRITICAL, severity crit',
      setUp: () => server.seedAlarmed(),
      build: () => HomeCubit(incidentsCubit, topicsCubit, incidentRepo),
      act: (cubit) => cubit.load(),
      expect: () => [
        const HomeState(status: HomeStatus.loading),
        isA<HomeState>()
            .having((s) => s.status, 'status', HomeStatus.success)
            .having((s) => s.faceState, 'faceState', FaceState.alarmed)
            .having((s) => s.word, 'word', 'CRITICAL')
            .having((s) => s.severity, 'severity', SeverityMode.crit)
            .having(
              (s) => s.topicItems.firstWhere((t) => t.name == 'prod-db').isCrit,
              'prod-db isCrit',
              isTrue,
            ),
      ],
    );

    blocTest<HomeCubit, HomeState>(
      'empty/watching fixture: emits watching face, No topics yet',
      setUp: () => server.seedWatching(),
      build: () => HomeCubit(incidentsCubit, topicsCubit, incidentRepo),
      act: (cubit) => cubit.load(),
      expect: () => [
        const HomeState(status: HomeStatus.loading),
        isA<HomeState>()
            .having((s) => s.status, 'status', HomeStatus.success)
            .having((s) => s.faceState, 'faceState', FaceState.watching)
            .having((s) => s.word, 'word', 'No topics yet')
            .having((s) => s.topicItems.isEmpty, 'topics empty', isTrue),
      ],
    );
  });
}
