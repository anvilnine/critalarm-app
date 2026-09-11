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
  });

  Future<AppResult<Topic>> updateTopic(
    String name, {
    bool? critical,
    int? repeatIntervalS,
    int? maxRingS,
    int? deskTimerS,
  });

  Future<AppResult<Unit>> deleteTopic(String name);

  Future<AppResult<String>> createTopicToken(String name);

  Future<AppResult<Unit>> deleteTopicToken(String name, String tokenId);
}
