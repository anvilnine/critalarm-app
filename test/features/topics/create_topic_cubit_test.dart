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

    test('Next moves step 1 to step 2 without creating anything', () async {
      final cubit = CreateTopicCubit(createTopicUsecase)
        ..nameChanged('prod-api')
        ..nextStep();

      expect(cubit.state.step, CreateTopicStep.token);
      expect(cubit.state.errorMessage, isNull);
      // Nothing reached the server: backing out now leaves no orphan topic.
      expect(server.getTopics(), isEmpty);
    });

    test('Next refuses a topic name the server would not take', () {
      final cubit = CreateTopicCubit(createTopicUsecase)
        ..nameChanged('invalid name!')
        ..nextStep();

      expect(cubit.state.step, CreateTopicStep.topic);
      expect(
        cubit.state.errorMessage,
        'Use 1 to 64 lowercase letters, digits and hyphens. Try prod-db.',
      );
    });

    test('Back from step 2 keeps the typed topic name', () {
      final cubit = CreateTopicCubit(createTopicUsecase)
        ..nameChanged('prod-api')
        ..criticalToggled(isCritical: true)
        ..nextStep()
        ..previousStep();

      expect(cubit.state.step, CreateTopicStep.topic);
      expect(cubit.state.name, 'prod-api');
      expect(cubit.state.isCritical, isTrue);
    });

    test('Create sends the topic name and the token name', () async {
      final cubit = CreateTopicCubit(createTopicUsecase)
        ..nameChanged('prod-api')
        ..nextStep()
        ..tokenNameChanged('CI server');

      await cubit.createTopic();

      expect(cubit.state.status, CreateTopicStatus.success);
      expect(cubit.state.createdTopic?.name, 'prod-api');
      expect(cubit.state.createdTopic?.tokenName, 'CI server');
      expect(server.getTopicTokens('prod-api').single.name, 'CI server');
    });

    test('an empty token name leaves the server to call it Token 1', () async {
      final cubit = CreateTopicCubit(createTopicUsecase)
        ..nameChanged('prod-api')
        ..nextStep();

      await cubit.createTopic();

      expect(cubit.state.status, CreateTopicStatus.success);
      expect(server.getTopicTokens('prod-api').single.name, 'Token 1');
    });

    test('a failed create sends the user back to step 1', () async {
      // The name is taken, so the server answers 409. The message belongs
      // under the topic name field, which only step 1 shows.
      server.createTopic(name: 'prod');

      final cubit = CreateTopicCubit(createTopicUsecase)
        ..nameChanged('prod')
        ..nextStep()
        ..tokenNameChanged('CI server');
      expect(cubit.state.step, CreateTopicStep.token);

      await cubit.createTopic();

      expect(cubit.state.status, CreateTopicStatus.failure);
      expect(cubit.state.step, CreateTopicStep.topic);
      expect(
        cubit.state.errorMessage,
        'A topic with that name already exists.',
      );
      // The typed token name survives, so pressing Next again does not lose it.
      expect(cubit.state.tokenName, 'CI server');
    });

    test('a name already in the topic list is caught on step 1', () {
      final cubit = CreateTopicCubit(createTopicUsecase)
        ..existingNamesChanged(['prod-api', 'staging'])
        ..nameChanged('  PROD-API  ');

      // The screen disables Next while this is true and shows the message
      // under the topic name field.
      expect(cubit.state.isDuplicateName, isTrue);

      cubit.nextStep();

      expect(cubit.state.step, CreateTopicStep.topic);
      expect(
        cubit.state.errorMessage,
        'A topic with that name already exists.',
      );
    });

    test('editing the name to a free one lets Next through again', () {
      final cubit = CreateTopicCubit(createTopicUsecase)
        ..existingNamesChanged(['prod-api'])
        ..nameChanged('prod-api');
      expect(cubit.state.isDuplicateName, isTrue);

      cubit.nameChanged('prod-api-2');
      expect(cubit.state.isDuplicateName, isFalse);

      cubit.nextStep();

      expect(cubit.state.step, CreateTopicStep.token);
      expect(cubit.state.errorMessage, isNull);
    });

    test(
      'the server still decides: a 409 returns to step 1 with the error and '
      'the typed token name',
      () async {
        // The list in memory does not hold this name, so nothing stops the
        // user before step 2. The server does. Z hit this on a real device.
        server.createTopic(name: 'prod');

        final cubit = CreateTopicCubit(createTopicUsecase)
          ..existingNamesChanged(['something-else'])
          ..nameChanged('prod')
          ..nextStep()
          ..tokenNameChanged('CI server');
        expect(cubit.state.isDuplicateName, isFalse);
        expect(cubit.state.step, CreateTopicStep.token);

        await cubit.createTopic();

        expect(cubit.state.status, CreateTopicStatus.failure);
        expect(cubit.state.step, CreateTopicStep.topic);
        expect(
          cubit.state.errorMessage,
          'A topic with that name already exists.',
        );
        expect(cubit.state.tokenName, 'CI server');
      },
    );

    test('making a critical topic moves the used count on', () async {
      final cubit = CreateTopicCubit(createTopicUsecase)
        ..nameChanged('prod-api')
        ..criticalToggled(isCritical: true)
        ..nextStep();

      await cubit.createTopic();

      expect(cubit.state.status, CreateTopicStatus.success);
      // The count was read when the screen opened, so without the bump
      // anything asking "how many are left" right after a create is told
      // one too many.
      expect(cubit.state.criticalUsed, 1);
      expect(cubit.state.criticalRemaining, 1);
    });

    test('making a topic that is not critical leaves the count alone',
        () async {
      final cubit = CreateTopicCubit(createTopicUsecase)
        ..nameChanged('prod-api')
        ..nextStep();

      await cubit.createTopic();

      expect(cubit.state.status, CreateTopicStatus.success);
      expect(cubit.state.criticalUsed, 0);
    });

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
