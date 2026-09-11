import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';

/// Parameters for updating an existing topic.
class UpdateTopicParams {
  const UpdateTopicParams({
    required this.name,
    this.critical,
    this.repeatIntervalS,
    this.maxRingS,
    this.deskTimerS,
  });

  final String name;
  final bool? critical;
  final int? repeatIntervalS;
  final int? maxRingS;
  final int? deskTimerS;
}

/// Usecase to update topic settings on the server.
class UpdateTopicUsecase implements UseCase<UpdateTopicParams, Topic> {
  const UpdateTopicUsecase(this._repository);

  final TopicRepository _repository;

  @override
  Future<AppResult<Topic>> call(UpdateTopicParams params) =>
      _repository.updateTopic(
        params.name,
        critical: params.critical,
        repeatIntervalS: params.repeatIntervalS,
        maxRingS: params.maxRingS,
        deskTimerS: params.deskTimerS,
      );
}
