import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';

/// Usecase to fetch a single topic by name.
class GetTopicUsecase implements UseCase<String, Topic> {
  const GetTopicUsecase(this._repository);

  final TopicRepository _repository;

  @override
  Future<AppResult<Topic>> call(String topicName) async {
    final result = await _repository.getTopics();
    return result.fold(
      (topics) {
        final matches = topics.where((t) => t.name == topicName);
        if (matches.isEmpty) {
          return Failure.notFound(
            message: 'Topic "$topicName" not found',
          ).toFailure();
        }
        return matches.first.toSuccess();
      },
      (failure) => failure.toFailure(),
    );
  }
}
