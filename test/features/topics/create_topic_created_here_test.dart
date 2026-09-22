import 'package:critalarm/core/api/mock_api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/features/topics/data/repositories/in_memory_topic_repository.dart';
import 'package:critalarm/features/topics/domain/usecases/create_topic_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a topic made on this phone is reported once it exists', () async {
    final made = <Topic>[];
    final usecase = CreateTopicUsecase(
      InMemoryTopicRepository(MockApiClient(MockServer()..seedCalm())),
      onCreated: (topic) async => made.add(topic),
    );
    final result = await usecase(const CreateTopicParams(name: 'fresh'));
    expect(result.isSuccess(), isTrue);
    expect(made.single.name, 'fresh');
  });

  test('a refused create reports nothing', () async {
    final made = <Topic>[];
    final usecase = CreateTopicUsecase(
      InMemoryTopicRepository(MockApiClient(MockServer()..seedCalm())),
      onCreated: (topic) async => made.add(topic),
    );
    await usecase(const CreateTopicParams(name: 'prod-db'));
    expect(made, isEmpty);
  });

  test(
    'the server already made the topic, so onCreated failing is not the '
    "caller's problem",
    () async {
      final usecase = CreateTopicUsecase(
        InMemoryTopicRepository(MockApiClient(MockServer()..seedCalm())),
        onCreated: (topic) async =>
            throw StateError('preference write blew up'),
      );
      final result = await usecase(const CreateTopicParams(name: 'fresh'));
      expect(result.isSuccess(), isTrue);
      expect(result.getOrNull()?.name, 'fresh');
    },
  );
}
