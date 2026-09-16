import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/server_info_validator.dart';
import 'package:critalarm/core/models/topic_token.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';

/// In-memory implementation of [TopicRepository] backed by [ApiClient].
class InMemoryTopicRepository implements TopicRepository {
  const InMemoryTopicRepository(
    this._client, {
    this.sessions,
    this.identity,
  });

  final ApiSessionStore? sessions;
  final DeviceIdentityStore? identity;

  /// Web has no registered handset. Mobile subscriptions use the canonical
  /// base_url saved from /v1/info, never the address entered by the user.
  Future<void> _subscriptions(String name, {required bool remove}) async {
    final identity = await this.identity?.readOrCreate();
    if (identity?.deviceToken == null) return;
    final session = await sessions?.read();
    if (session == null) throw StateError('No API session configured');
    final hash = ServerInfoValidation.deriveTopicHash(
      baseUrl: session.baseUri.toString(),
      topic: name,
    );
    if (remove) {
      await _client.unsubscribeTopic(
        deviceId: identity!.deviceId,
        deviceToken: identity.deviceToken!,
        topicHash: hash,
      );
    } else {
      await _client.subscribeTopic(
        deviceId: identity!.deviceId,
        deviceToken: identity.deviceToken!,
        topicHash: hash,
      );
    }
  }

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
        cap: e.cap,
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
      try {
        await _subscriptions(name, remove: false);
      } on Exception {
        // Do not leave a created topic whose one-time token was never returned.
        await _client.deleteTopic(name);
        rethrow;
      }
      return topic.toSuccess();
    } on ApiException catch (e) {
      if (e.statusCode == 409 && e.code == 40901) {
        return Failure.topicAlreadyExists(message: e.message).toFailure();
      }
      return Failure.api(
        statusCode: e.statusCode,
        message: e.message,
        code: e.code,
        cap: e.cap,
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
        cap: e.cap,
      ).toFailure();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  @override
  Future<AppResult<Unit>> deleteTopic(String name) async {
    try {
      await _subscriptions(name, remove: true);
      try {
        await _client.deleteTopic(name);
      } on Exception {
        await _subscriptions(name, remove: false);
        rethrow;
      }
      return unit.toSuccess();
    } on ApiException catch (e) {
      return Failure.api(
        statusCode: e.statusCode,
        message: e.message,
        code: e.code,
        cap: e.cap,
      ).toFailure();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  @override
  Future<AppResult<List<TopicTokenInfo>>> getTopicTokens(String name) async {
    try {
      final tokens = await _client.getTopicTokens(name);
      return tokens.toSuccess();
    } on ApiException catch (e) {
      return Failure.api(
        statusCode: e.statusCode,
        message: e.message,
        code: e.code,
        cap: e.cap,
      ).toFailure();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }

  @override
  Future<AppResult<TopicToken>> createTopicToken(String name) async {
    try {
      final token = await _client.createTopicToken(name);
      return token.toSuccess();
    } on ApiException catch (e) {
      return Failure.api(
        statusCode: e.statusCode,
        message: e.message,
        code: e.code,
        cap: e.cap,
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
        cap: e.cap,
      ).toFailure();
    } on Exception catch (e) {
      return Failure.unexpected(message: e.toString()).toFailure();
    }
  }
}
