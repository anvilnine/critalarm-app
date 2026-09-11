import 'package:bloc_test/bloc_test.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/features/incidents/data/repositories/in_memory_incident_repository.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topic_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/update_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_detail_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockServer server;
  late MockApiClient apiClient;
  late TopicRepository topicRepo;
  late IncidentRepository incidentRepo;
  late GetTopicUsecase getTopicUsecase;
  late UpdateTopicUsecase updateTopicUsecase;

  setUp(() {
    server = MockServer();
    apiClient = MockApiClient(server);
    topicRepo = InMemoryTopicRepository(apiClient);
    incidentRepo = InMemoryIncidentRepository(apiClient);
    getTopicUsecase = GetTopicUsecase(topicRepo);
    updateTopicUsecase = UpdateTopicUsecase(topicRepo);
  });

  group('TopicDetailCubit', () {
    test('critical delivery defaults to false in initial state', () {
      final cubit = TopicDetailCubit(
        getTopicUsecase,
        updateTopicUsecase,
        incidentRepo,
      );
      expect(cubit.state.critical, isFalse);
      expect(cubit.state.status, TopicDetailStatus.initial);
    });

    blocTest<TopicDetailCubit, TopicDetailState>(
      'loads nas-backup in worried fixture with high severity and 2 messages',
      setUp: () => server.seedWorried(),
      build: () => TopicDetailCubit(
        getTopicUsecase,
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
            .having((s) => s.messages.length, 'messages length', 2)
            .having((s) => s.messages[0].isHigh, 'first message isHigh', isTrue)
            .having(
              (s) => s.messages[1].isHigh,
              'second message isHigh',
              isFalse,
            ),
      ],
    );

    blocTest<TopicDetailCubit, TopicDetailState>(
      'toggleCriticalDelivery updates topic on server and emits new state',
      setUp: () => server.seedCalm(),
      build: () => TopicDetailCubit(
        getTopicUsecase,
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
        isA<TopicDetailState>()
            .having((s) => s.isUpdatingCritical, 'updating', isTrue),
        isA<TopicDetailState>()
            .having((s) => s.isUpdatingCritical, 'updated', isFalse)
            .having((s) => s.critical, 'critical toggled to true', isTrue),
      ],
    );

    blocTest<TopicDetailCubit, TopicDetailState>(
      'markAsRead clears high severity and returns face to calm',
      setUp: () => server.seedWorried(),
      build: () => TopicDetailCubit(
        getTopicUsecase,
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
        isA<TopicDetailState>()
            .having((s) => s.isMarkingAsRead, 'marking', isTrue),
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
        getTopicUsecase,
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
