import 'package:bloc_test/bloc_test.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/design/components/chips.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/topics_list_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topics_list_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockServer server;
  late MockApiClient apiClient;
  late TopicRepository topicRepo;
  late IncidentRepository incidentRepo;
  late GetTopicsUsecase getTopicsUsecase;

  setUp(() {
    server = MockServer();
    apiClient = MockApiClient(server);
    topicRepo = InMemoryTopicRepository(apiClient);
    incidentRepo = InMemoryIncidentRepository(apiClient);
    getTopicsUsecase = GetTopicsUsecase(topicRepo);
  });

  group('TopicsListCubit', () {
    test('initial state is initial with empty list', () {
      final cubit = TopicsListCubit(getTopicsUsecase, incidentRepo);
      expect(cubit.state.status, TopicsListStatus.initial);
      expect(cubit.state.topics, isEmpty);
    });

    blocTest<TopicsListCubit, TopicsListState>(
      'loads 4 topics when server is seeded with calm fixture',
      setUp: () => server.seedCalm(),
      build: () => TopicsListCubit(getTopicsUsecase, incidentRepo),
      act: (cubit) => cubit.load(),
      expect: () => [
        const TopicsListState(status: TopicsListStatus.loading),
        isA<TopicsListState>()
            .having((s) => s.status, 'status', TopicsListStatus.success)
            .having((s) => s.topics.length, 'topics length', 4)
            .having(
              (s) => s.topics.map((t) => t.name).toList(),
              'topic names',
              ['prod-db', 'nas-backup', 'uptime-kuma', 'home-ha'],
            )
            .having(
              (s) => s.topics.firstWhere((t) => t.name == 'prod-db').priority,
              'prod-db priority',
              PriorityLevel.critical,
            )
            .having(
              (s) => s.topics.firstWhere((t) => t.name == 'home-ha').isQuiet,
              'home-ha isQuiet',
              isTrue,
            ),
      ],
    );

    blocTest<TopicsListCubit, TopicsListState>(
      'loads empty list when server has no topics',
      setUp: () => server.seedWatching(),
      build: () => TopicsListCubit(getTopicsUsecase, incidentRepo),
      act: (cubit) => cubit.load(),
      expect: () => [
        const TopicsListState(status: TopicsListStatus.loading),
        isA<TopicsListState>()
            .having((s) => s.status, 'status', TopicsListStatus.success)
            .having((s) => s.topics.isEmpty, 'empty list', isTrue)
            .having((s) => s.isEmpty, 'isEmpty getter', isTrue),
      ],
    );

    blocTest<TopicsListCubit, TopicsListState>(
      'reflects worried face on nas-backup in worried fixture',
      setUp: () => server.seedWorried(),
      build: () => TopicsListCubit(getTopicsUsecase, incidentRepo),
      act: (cubit) => cubit.load(),
      expect: () => [
        const TopicsListState(status: TopicsListStatus.loading),
        isA<TopicsListState>()
            .having((s) => s.status, 'status', TopicsListStatus.success)
            .having(
              (s) => s.topics
                  .firstWhere((t) => t.name == 'nas-backup')
                  .faceState,
              'nas-backup faceState',
              FaceState.worried,
            ),
      ],
    );
  });
}
