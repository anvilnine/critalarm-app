import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';

/// Parameters for creating a new topic.
///
/// Commitment made to Apple: [critical] defaults to `false`.
/// Never change this default.
class CreateTopicParams {
  const CreateTopicParams({
    required this.name,
    this.critical = false,
    this.repeatIntervalS = 30,
    this.maxRingS = 1800,
    this.deskTimerS = 600,
    this.relayContent = 'none',
    this.tokenName,
  });

  final String name;
  final bool critical;
  final int repeatIntervalS;
  final int maxRingS;
  final int deskTimerS;
  final String relayContent;

  /// What to call the token the server mints with the topic. Optional: leave
  /// it off and the server calls it `Token 1`.
  final String? tokenName;
}

/// Usecase to create a new topic on the server.
class CreateTopicUsecase implements UseCase<CreateTopicParams, Topic> {
  const CreateTopicUsecase(this._repository);

  final TopicRepository _repository;

  @override
  Future<AppResult<Topic>> call(CreateTopicParams params) =>
      _repository.createTopic(
        name: params.name,
        critical: params.critical,
        repeatIntervalS: params.repeatIntervalS,
        maxRingS: params.maxRingS,
        deskTimerS: params.deskTimerS,
        relayContent: params.relayContent,
        tokenName: params.tokenName,
      );
}
