import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/create_topic_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/delete_topic_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topic_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/get_topics_usecase.dart';
import 'package:critalarm/features/topics/domain/usecases/update_topic_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockServer server;
  late MockApiClient apiClient;
  late TopicRepository repository;
  late GetTopicsUsecase getTopicsUsecase;
  late GetTopicUsecase getTopicUsecase;
  late CreateTopicUsecase createTopicUsecase;
  late UpdateTopicUsecase updateTopicUsecase;
  late DeleteTopicUsecase deleteTopicUsecase;

  setUp(() {
    server = MockServer()..seedCalm();
    apiClient = MockApiClient(server);
    repository = InMemoryTopicRepository(apiClient);
    getTopicsUsecase = GetTopicsUsecase(repository);
    getTopicUsecase = GetTopicUsecase(repository);
    createTopicUsecase = CreateTopicUsecase(repository);
    updateTopicUsecase = UpdateTopicUsecase(repository);
    deleteTopicUsecase = DeleteTopicUsecase(repository);
  });

  group('GetTopicsUsecase', () {
    test('returns all seeded topics on success', () async {
      final result = await getTopicsUsecase(const NoParams());

      expect(result.isSuccess(), isTrue);
      final topics = result.getOrNull()!;
      expect(topics.length, 4);
      expect(topics.map((t) => t.name), contains('prod-db'));
    });
  });

  group('GetTopicUsecase', () {
    test('returns the requested topic when found', () async {
      final result = await getTopicUsecase('prod-db');

      expect(result.isSuccess(), isTrue);
      final topic = result.getOrNull()!;
      expect(topic.name, 'prod-db');
      expect(topic.critical, isTrue);
    });

    test('returns NotFoundFailure when topic does not exist', () async {
      final result = await getTopicUsecase('non-existent');

      expect(result.isError(), isTrue);
      final failure = result.exceptionOrNull()!;
      expect(failure, isA<NotFoundFailure>());
    });
  });

  group('CreateTopicUsecase', () {
    test('critical defaults to false (Apple entitlement commitment)', () async {
      const params = CreateTopicParams(name: 'new-service');
      expect(params.critical, isFalse);

      final result = await createTopicUsecase(params);

      expect(result.isSuccess(), isTrue);
      final topic = result.getOrNull()!;
      expect(topic.name, 'new-service');
      expect(topic.critical, isFalse);
      expect(topic.token, isNotNull);
    });

    test('creates topic with critical true when explicitly passed', () async {
      const params = CreateTopicParams(name: 'pagers', critical: true);
      final result = await createTopicUsecase(params);

      expect(result.isSuccess(), isTrue);
      final topic = result.getOrNull()!;
      expect(topic.name, 'pagers');
      expect(topic.critical, isTrue);
    });

    test('returns failure on invalid topic name', () async {
      const params = CreateTopicParams(name: 'invalid name with spaces!');
      final result = await createTopicUsecase(params);

      expect(result.isError(), isTrue);
      final failure = result.exceptionOrNull()!;
      expect(failure, isA<ApiFailure>());
      expect((failure as ApiFailure).statusCode, 400);
    });
  });

  group('UpdateTopicUsecase', () {
    test('updates critical delivery flag on existing topic', () async {
      const params = UpdateTopicParams(name: 'nas-backup', critical: true);
      final result = await updateTopicUsecase(params);

      expect(result.isSuccess(), isTrue);
      final topic = result.getOrNull()!;
      expect(topic.name, 'nas-backup');
      expect(topic.critical, isTrue);
    });
  });

  group('DeleteTopicUsecase', () {
    test('deletes topic and returns Unit', () async {
      final deleteResult = await deleteTopicUsecase('home-ha');
      expect(deleteResult.isSuccess(), isTrue);

      final fetchResult = await getTopicUsecase('home-ha');
      expect(fetchResult.isError(), isTrue);
      expect(fetchResult.exceptionOrNull(), isA<NotFoundFailure>());
    });
  });
}
