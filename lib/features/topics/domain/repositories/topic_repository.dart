import 'package:critalarm/core/models/topic_token.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';

/// Domain contract for managing topics on the server.
abstract interface class TopicRepository {
  Future<AppResult<List<Topic>>> getTopics();

  Future<AppResult<Topic>> createTopic({
    required String name,
    bool critical = false,
    int repeatIntervalS = 30,
    int maxRingS = 1800,
    int deskTimerS = 600,
    String relayContent = 'none',
    String? tokenName,
  });

  Future<AppResult<Topic>> updateTopic(
    String name, {
    bool? critical,
    int? repeatIntervalS,
    int? maxRingS,
    int? deskTimerS,
  });

  Future<AppResult<Unit>> deleteTopic(String name);

  /// Ids, names and dates. The server never gives a token value back.
  Future<AppResult<List<TopicTokenInfo>>> getTopicTokens(String name);

  Future<AppResult<TopicToken>> createTopicToken(
    String name, {
    String? tokenName,
  });

  Future<AppResult<TopicTokenInfo>> renameTopicToken(
    String name,
    String tokenId,
    String tokenName,
  );

  Future<AppResult<Unit>> deleteTopicToken(String name, String tokenId);
}
