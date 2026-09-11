import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';

/// Usecase to fetch all topics from the repository.
class GetTopicsUsecase implements UseCase<NoParams, List<Topic>> {
  const GetTopicsUsecase(this._repository);

  final TopicRepository _repository;

  @override
  Future<AppResult<List<Topic>>> call(NoParams input) =>
      _repository.getTopics();
}
