import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';

/// In-memory implementation of [TopicRepository] backed by [ApiClient].
class InMemoryTopicRepository implements TopicRepository {
  const InMemoryTopicRepository(this._client);

  final ApiClient _client;

  @override
  Future<AppResult<List<Topic>>> getTopics() async {
    try {
      final topics = await _client.getTopics();
      return topics.toSuccess();
    } on ApiException catch (e) {
      return Failure.api(
        statusCode: e.statusCode,
        message: e.message,
        code: e.code,
      ).toFailure();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  @override
  Future<AppResult<Topic>> createTopic({
    required String name,
    bool critical = false,
    int repeatIntervalS = 30,
    int maxRingS = 1800,
    int deskTimerS = 600,
    String relayContent = 'none',
  }) async {
    try {
      final topic = await _client.createTopic(
        name: name,
        critical: critical,
        repeatIntervalS: repeatIntervalS,
        maxRingS: maxRingS,
        deskTimerS: deskTimerS,
        relayContent: relayContent,
      );
      return topic.toSuccess();
    } on ApiException catch (e) {
      return Failure.api(
        statusCode: e.statusCode,
        message: e.message,
        code: e.code,
      ).toFailure();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  @override
  Future<AppResult<Topic>> updateTopic(
    String name, {
    bool? critical,
    int? repeatIntervalS,
    int? maxRingS,
    int? deskTimerS,
  }) async {
    try {
      final topic = await _client.updateTopic(
        name,
        critical: critical,
        repeatIntervalS: repeatIntervalS,
        maxRingS: maxRingS,
        deskTimerS: deskTimerS,
      );
      return topic.toSuccess();
    } on ApiException catch (e) {
      return Failure.api(
        statusCode: e.statusCode,
        message: e.message,
        code: e.code,
      ).toFailure();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  @override
  Future<AppResult<Unit>> deleteTopic(String name) async {
    try {
      await _client.deleteTopic(name);
      return unit.toSuccess();
    } on ApiException catch (e) {
      return Failure.api(
        statusCode: e.statusCode,
        message: e.message,
        code: e.code,
      ).toFailure();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  @override
  Future<AppResult<String>> createTopicToken(String name) async {
    try {
      final token = await _client.createTopicToken(name);
      return token.toSuccess();
    } on ApiException catch (e) {
      return Failure.api(
        statusCode: e.statusCode,
        message: e.message,
        code: e.code,
      ).toFailure();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  @override
  Future<AppResult<Unit>> deleteTopicToken(String name, String tokenId) async {
    try {
      await _client.deleteTopicToken(name, tokenId);
      return unit.toSuccess();
    } on ApiException catch (e) {
      return Failure.api(
        statusCode: e.statusCode,
        message: e.message,
        code: e.code,
      ).toFailure();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }
}
