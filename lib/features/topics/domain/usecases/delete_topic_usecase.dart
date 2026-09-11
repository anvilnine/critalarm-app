import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';

/// Usecase to delete a topic by name.
class DeleteTopicUsecase implements UseCase<String, Unit> {
  const DeleteTopicUsecase(this._repository);

  final TopicRepository _repository;

  @override
  Future<AppResult<Unit>> call(String topicName) =>
      _repository.deleteTopic(topicName);
}
