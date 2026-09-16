import 'package:critalarm/core/models/topic_token.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';

/// Lists a topic's tokens. Ids and dates, never a value.
class GetTopicTokensUsecase
    implements UseCase<String, List<TopicTokenInfo>> {
  const GetTopicTokensUsecase(this._repository);

  final TopicRepository _repository;

  @override
  Future<AppResult<List<TopicTokenInfo>>> call(String topicName) =>
      _repository.getTopicTokens(topicName);
}

/// Makes one more token for a topic. The value comes back once, here.
class CreateTopicTokenUsecase implements UseCase<String, TopicToken> {
  const CreateTopicTokenUsecase(this._repository);

  final TopicRepository _repository;

  @override
  Future<AppResult<TopicToken>> call(String topicName) =>
      _repository.createTopicToken(topicName);
}

/// Which token on which topic to revoke.
class RevokeTopicTokenParams {
  const RevokeTopicTokenParams({
    required this.topicName,
    required this.tokenId,
  });

  final String topicName;
  final String tokenId;
}

/// Revokes one token. The server refuses to take a topic's last one.
class RevokeTopicTokenUsecase
    implements UseCase<RevokeTopicTokenParams, Unit> {
  const RevokeTopicTokenUsecase(this._repository);

  final TopicRepository _repository;

  @override
  Future<AppResult<Unit>> call(RevokeTopicTokenParams params) =>
      _repository.deleteTopicToken(params.topicName, params.tokenId);
}
