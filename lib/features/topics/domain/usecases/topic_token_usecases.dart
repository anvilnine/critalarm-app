import 'package:critalarm/core/models/topic_token.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/usecase/usecase.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';

/// Lists a topic's tokens. Ids, names and dates, never a value.
class GetTopicTokensUsecase implements UseCase<String, List<TopicTokenInfo>> {
  const GetTopicTokensUsecase(this._repository);

  final TopicRepository _repository;

  @override
  Future<AppResult<List<TopicTokenInfo>>> call(String topicName) =>
      _repository.getTopicTokens(topicName);
}

/// Which topic to make a token on, and what to call it.
class CreateTopicTokenParams {
  const CreateTopicTokenParams({required this.topicName, this.name});

  final String topicName;

  /// Optional. Leave it off and the server calls it `Token N`.
  final String? name;
}

/// Makes one more token for a topic. The value comes back once, here.
class CreateTopicTokenUsecase
    implements UseCase<CreateTopicTokenParams, TopicToken> {
  const CreateTopicTokenUsecase(this._repository);

  final TopicRepository _repository;

  @override
  Future<AppResult<TopicToken>> call(CreateTopicTokenParams params) =>
      _repository.createTopicToken(params.topicName, tokenName: params.name);
}

/// Which token on which topic to rename, and to what.
class RenameTopicTokenParams {
  const RenameTopicTokenParams({
    required this.topicName,
    required this.tokenId,
    required this.name,
  });

  final String topicName;
  final String tokenId;
  final String name;
}

/// Renames one token. The name is required, unlike on creation.
class RenameTopicTokenUsecase
    implements UseCase<RenameTopicTokenParams, TopicTokenInfo> {
  const RenameTopicTokenUsecase(this._repository);

  final TopicRepository _repository;

  @override
  Future<AppResult<TopicTokenInfo>> call(RenameTopicTokenParams params) =>
      _repository.renameTopicToken(
        params.topicName,
        params.tokenId,
        params.name,
      );
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
class RevokeTopicTokenUsecase implements UseCase<RevokeTopicTokenParams, Unit> {
  const RevokeTopicTokenUsecase(this._repository);

  final TopicRepository _repository;

  @override
  Future<AppResult<Unit>> call(RevokeTopicTokenParams params) =>
      _repository.deleteTopicToken(params.topicName, params.tokenId);
}
