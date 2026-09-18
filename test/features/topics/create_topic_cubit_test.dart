import 'package:bloc_test/bloc_test.dart';
import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/create_topic_usecase.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_cubit.dart';
import 'package:critalarm/features/topics/presentation/cubits/create_topic_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockServer server;
  late MockApiClient apiClient;
  late TopicRepository topicRepo;
  late CreateTopicUsecase createTopicUsecase;

  setUp(() {
    server = MockServer();
    apiClient = MockApiClient(server);
    topicRepo = InMemoryTopicRepository(apiClient);
    createTopicUsecase = CreateTopicUsecase(topicRepo);
  });

  group('CreateTopicCubit', () {
    test(
      'initial state has an empty name and isCritical is FALSE',
      () {
        final cubit = CreateTopicCubit(createTopicUsecase);
        expect(cubit.state.name, '');
        expect(
          cubit.state.isCritical,
          isFalse,
        ); // Commitment to Apple: defaults to OFF!
        expect(cubit.state.status, CreateTopicStatus.initial);
      },
    );

    blocTest<CreateTopicCubit, CreateTopicState>(
      'nameChanged updates name and clears error',
      build: () => CreateTopicCubit(createTopicUsecase),
      seed: () => const CreateTopicState(errorMessage: 'some error'),
      act: (cubit) => cubit.nameChanged('new-topic-name'),
      expect: () => [
        const CreateTopicState(name: 'new-topic-name'),
      ],
    );

    blocTest<CreateTopicCubit, CreateTopicState>(
      'criticalToggled toggles isCritical state',
      build: () => CreateTopicCubit(createTopicUsecase),
      act: (cubit) => cubit.criticalToggled(isCritical: true),
      expect: () => [
        const CreateTopicState(isCritical: true),
      ],
    );

    blocTest<CreateTopicCubit, CreateTopicState>(
      'createTopic with empty name emits error',
      build: () => CreateTopicCubit(createTopicUsecase),
      seed: () => const CreateTopicState(name: '   '),
      act: (cubit) => cubit.createTopic(),
      expect: () => [
        const CreateTopicState(
          name: '   ',
          errorMessage: 'Give the topic a name.',
        ),
      ],
    );

    blocTest<CreateTopicCubit, CreateTopicState>(
      'createTopic with invalid characters emits validation error',
      build: () => CreateTopicCubit(createTopicUsecase),
      seed: () => const CreateTopicState(name: 'invalid name!'),
      act: (cubit) => cubit.createTopic(),
      expect: () => [
        const CreateTopicState(
          name: 'invalid name!',
          errorMessage:
              'Use 1 to 64 lowercase letters, digits and hyphens. Try prod-db.',
        ),
      ],
    );

    blocTest<CreateTopicCubit, CreateTopicState>(
      'createTopic succeeds and emits topic and token',
      build: () => CreateTopicCubit(createTopicUsecase),
      seed: () => const CreateTopicState(name: 'prod-api'),
      act: (cubit) => cubit.createTopic(),
      expect: () => [
        const CreateTopicState(
          name: 'prod-api',
          status: CreateTopicStatus.submitting,
        ),
        isA<CreateTopicState>()
            .having((s) => s.status, 'status', CreateTopicStatus.success)
            .having((s) => s.createdTopic?.name, 'created name', 'prod-api')
            .having((s) => s.createdToken, 'created token', isNotNull)
            .having(
              (s) => s.createdTopic?.critical,
              'created topic critical is false by default',
              isFalse,
            ),
      ],
    );
    blocTest<CreateTopicCubit, CreateTopicState>(
      'createTopic succeeds with valid 64-character topic name',
      build: () => CreateTopicCubit(createTopicUsecase),
      seed: () => CreateTopicState(name: 'a' * 64),
      act: (cubit) => cubit.createTopic(),
      expect: () => [
        CreateTopicState(
          name: 'a' * 64,
          status: CreateTopicStatus.submitting,
        ),
        isA<CreateTopicState>()
            .having((s) => s.status, 'status', CreateTopicStatus.success)
            .having((s) => s.createdTopic?.name, 'created name', 'a' * 64),
      ],
    );

    blocTest<CreateTopicCubit, CreateTopicState>(
      'createTopic with name exceeding 64 characters emits validation error',
      build: () => CreateTopicCubit(createTopicUsecase),
      seed: () => CreateTopicState(name: 'a' * 65),
      act: (cubit) => cubit.createTopic(),
      expect: () => [
        CreateTopicState(
          name: 'a' * 65,
          errorMessage:
              'Use 1 to 64 lowercase letters, digits and hyphens. Try prod-db.',
        ),
      ],
    );

    test('criticalRemaining helper computes correctly', () {
      const freeState = CreateTopicState(
        criticalUsed: 1,
      );
      expect(freeState.criticalRemaining, 1);

      const exhaustedState = CreateTopicState(
        criticalUsed: 2,
      );
      expect(exhaustedState.criticalRemaining, 0);

      const proState = CreateTopicState(
        isFreeTier: false,
        criticalLimit: null,
        criticalUsed: 5,
      );
      expect(proState.criticalRemaining, isNull);
    });
  });
}
