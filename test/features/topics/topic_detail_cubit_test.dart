import 'package:bloc_test/bloc_test.dart';
import 'package:critalarm/app/state/incidents_cubit.dart';
import 'package:critalarm/app/state/topics_cubit.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/incidents/domain/usecases/get_incidents_usecase.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/update_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// A topic list that never loads.
class _FailingTopics implements TopicRepository {
  @override
  Future<AppResult<List<Topic>>> getTopics() async =>
      const Failure.api(statusCode: 500).toFailure();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late MockServer server;
  late MockApiClient apiClient;
  late TopicRepository topicRepo;
  late IncidentRepository incidentRepo;
  late UpdateTopicUsecase updateTopicUsecase;
  late IncidentsCubit incidentsCubit;
  late TopicsCubit topicsCubit;

  setUp(() {
    server = MockServer();
    apiClient = MockApiClient(server);
    topicRepo = InMemoryTopicRepository(apiClient);
    incidentRepo = InMemoryIncidentRepository(apiClient);
    updateTopicUsecase = UpdateTopicUsecase(topicRepo);
    incidentsCubit = IncidentsCubit(GetIncidentsUsecase(incidentRepo));
    topicsCubit = TopicsCubit(GetTopicsUsecase(topicRepo));
  });

  tearDown(() async {
    await incidentsCubit.close();
    await topicsCubit.close();
  });

  group('TopicDetailCubit', () {
    test('refresh reports true when both lists load', () async {
      server.seedCalm();
      final cubit = TopicDetailCubit(
        incidentsCubit,
        topicsCubit,
        updateTopicUsecase,
        incidentRepo,
      );
      addTearDown(cubit.close);
      await cubit.load('prod-db');
      expect(await cubit.refresh(), isTrue);
    });

    test('refresh reports false when the topic list fails', () async {
      final failing = TopicsCubit(GetTopicsUsecase(_FailingTopics()));
      addTearDown(failing.close);
      final cubit = TopicDetailCubit(
        incidentsCubit,
        failing,
        updateTopicUsecase,
        incidentRepo,
      );
      addTearDown(cubit.close);
      expect(await cubit.refresh(), isFalse);
    });

    test('critical delivery defaults to false in initial state', () {
      final cubit = TopicDetailCubit(
        incidentsCubit,
        topicsCubit,
        updateTopicUsecase,
        incidentRepo,
      );
      expect(cubit.state.critical, isFalse);
      expect(cubit.state.status, TopicDetailStatus.initial);
    });

    blocTest<TopicDetailCubit, TopicDetailState>(
      'loads nas-backup from the current server response',
      setUp: () => server.seedWorried(),
      build: () => TopicDetailCubit(
        incidentsCubit,
        topicsCubit,
        updateTopicUsecase,
        incidentRepo,
      ),
      act: (cubit) => cubit.load('nas-backup'),
      expect: () => [
        const TopicDetailState(
          status: TopicDetailStatus.loading,
          topicName: 'nas-backup',
        ),
        isA<TopicDetailState>()
            .having((s) => s.status, 'status', TopicDetailStatus.success)
            .having((s) => s.topicName, 'topicName', 'nas-backup')
            .having((s) => s.severity, 'severity', SeverityMode.high)
            .having((s) => s.faceState, 'faceState', FaceState.worried)
            .having((s) => s.word, 'word', '1 warning')
            .having((s) => s.messages.length, 'messages length', 1)
            .having((s) => s.messages.single.isHigh, 'message isHigh', isTrue),
      ],
    );

    blocTest<TopicDetailCubit, TopicDetailState>(
      'toggleCriticalDelivery updates topic on server and emits new state',
      setUp: () => server.seedCalm(),
      build: () => TopicDetailCubit(
        incidentsCubit,
        topicsCubit,
        updateTopicUsecase,
        incidentRepo,
      ),
      act: (cubit) async {
        await cubit.load('nas-backup');
        await cubit.toggleCriticalDelivery(isCritical: true);
      },
      expect: () => [
        const TopicDetailState(
          status: TopicDetailStatus.loading,
          topicName: 'nas-backup',
        ),
        isA<TopicDetailState>()
            .having((s) => s.status, 'status', TopicDetailStatus.success)
            .having((s) => s.critical, 'initial critical', isFalse),
        isA<TopicDetailState>().having(
          (s) => s.isUpdatingCritical,
          'updating',
          isTrue,
        ),
        isA<TopicDetailState>()
            .having((s) => s.isUpdatingCritical, 'updated', isFalse)
            .having((s) => s.critical, 'critical toggled to true', isTrue),
      ],
    );

    blocTest<TopicDetailCubit, TopicDetailState>(
      'markAsRead clears high severity and returns face to calm',
      setUp: () => server.seedWorried(),
      build: () => TopicDetailCubit(
        incidentsCubit,
        topicsCubit,
        updateTopicUsecase,
        incidentRepo,
      ),
      act: (cubit) async {
        await cubit.load('nas-backup');
        await cubit.markAsRead();
      },
      expect: () => [
        const TopicDetailState(
          status: TopicDetailStatus.loading,
          topicName: 'nas-backup',
        ),
        isA<TopicDetailState>()
            .having((s) => s.status, 'status', TopicDetailStatus.success)
            .having((s) => s.severity, 'initial severity', SeverityMode.high),
        isA<TopicDetailState>().having(
          (s) => s.isMarkingAsRead,
          'marking',
          isTrue,
        ),
        isA<TopicDetailState>()
            .having((s) => s.isMarkingAsRead, 'marked', isFalse)
            .having((s) => s.severity, 'cleared severity', SeverityMode.none)
            .having((s) => s.faceState, 'calm face', FaceState.calm)
            .having((s) => s.word, 'all clear word', 'All clear')
            .having(
              (s) => s.messages.every((m) => !m.isHigh),
              'all messages normal',
              isTrue,
            ),
      ],
    );

    blocTest<TopicDetailCubit, TopicDetailState>(
      'emits failure state when topic not found',
      setUp: () => server.seedCalm(),
      build: () => TopicDetailCubit(
        incidentsCubit,
        topicsCubit,
        updateTopicUsecase,
        incidentRepo,
      ),
      act: (cubit) => cubit.load('does-not-exist'),
      expect: () => [
        const TopicDetailState(
          status: TopicDetailStatus.loading,
          topicName: 'does-not-exist',
        ),
        isA<TopicDetailState>()
            .having((s) => s.status, 'status', TopicDetailStatus.failure)
            .having((s) => s.errorMessage, 'has error', isNotNull),
      ],
    );
  });
}
