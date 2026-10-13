import 'dart:async';

import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/server_info_validator.dart';
import 'package:critalarm/core/models/topic_token.dart';
import 'package:critalarm/core/notifications/topic_timer_cache.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/features/topics/domain/entities/topic.dart';
import 'package:critalarm/features/topics/domain/repositories/topic_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory implementation of [TopicRepository] backed by [ApiClient].
class InMemoryTopicRepository implements TopicRepository {
  InMemoryTopicRepository(
    this._client, {
    this.sessions,
    this.identity,
    this.prefs,
  });

  final ApiSessionStore? sessions;
  final DeviceIdentityStore? identity;
  final SharedPreferences? prefs;

  /// Key prefix for the mark that a topic's subscription has moved from its
  /// name to its `relay_name` on one server. Kept in preferences, which live
  /// and die with this install, so a reinstall repeats the move. The repeat is
  /// safe: adding a hash the device already holds changes nothing, and the
  /// plain hash it removes is gone already.
  static const String movedKeyPrefix = 'relay_hash_moved.';

  /// Relay names seen in this run, by topic name, so a delete knows which
  /// second hash to remove. Memory only: the secret is never written to disk
  /// by this class.
  final Map<String, String> _relayNames = {};

  /// Stands in for [prefs] when there are none (web, some tests).
  final Set<String> _movedInMemory = {};

  /// Moves run one after another, so two refreshes at once cannot both add
  /// and remove the same hash.
  Future<void> _moves = Future<void>.value();

  /// Completes when every move started so far has finished, so a test can wait
  /// for the relay calls a list kicked off.
  @visibleForTesting
  Future<void> get movesSettled => _moves;

  /// The relay call's inputs, or null for a handset with no push token (web,
  /// or not registered yet), which has nothing to subscribe. Mobile
  /// subscriptions use the canonical base_url saved from /v1/info, never the
  /// address entered by the user.
  Future<({String deviceId, String deviceToken, String baseUrl})?>
  _relayTarget() async {
    final identity = await this.identity?.readOrCreate();
    final deviceToken = identity?.deviceToken;
    if (identity == null || deviceToken == null) return null;
    final session = await sessions?.read();
    if (session == null) throw StateError('No API session configured');
    return (
      deviceId: identity.deviceId,
      deviceToken: deviceToken,
      baseUrl: session.baseUri.toString(),
    );
  }

  String _hash(String baseUrl, String source) =>
      ServerInfoValidation.deriveTopicHash(baseUrl: baseUrl, topic: source);

  Future<void> _subscribe(
    ({String deviceId, String deviceToken, String baseUrl}) target,
    String source,
  ) => _client.subscribeTopic(
    deviceId: target.deviceId,
    deviceToken: target.deviceToken,
    topicHash: _hash(target.baseUrl, source),
  );

  /// A hash the relay does not hold answers 404. That is the state this wants,
  /// so it counts as removed.
  Future<void> _unsubscribe(
    ({String deviceId, String deviceToken, String baseUrl}) target,
    String source,
  ) async {
    try {
      await _client.unsubscribeTopic(
        deviceId: target.deviceId,
        deviceToken: target.deviceToken,
        topicHash: _hash(target.baseUrl, source),
      );
    } on ApiException catch (e) {
      if (e.statusCode != 404) rethrow;
    }
  }

  String _movedKey(String baseUrl, String name) =>
      '$movedKeyPrefix${ServerInfoValidation.normalizeBaseUrl(baseUrl)}|$name';

  bool _isMoved(String baseUrl, String name) {
    final key = _movedKey(baseUrl, name);
    return prefs?.getBool(key) ?? _movedInMemory.contains(key);
  }

  Future<void> _markMoved(String baseUrl, String name) async {
    final key = _movedKey(baseUrl, name);
    _movedInMemory.add(key);
    await prefs?.setBool(key, true);
  }

  void _rememberRelayNames(Iterable<Topic> topics) {
    for (final topic in topics) {
      final secret = topic.relayName?.trim() ?? '';
      if (secret.isEmpty) {
        _relayNames.remove(topic.name);
      } else {
        _relayNames[topic.name] = secret;
      }
    }
  }

  /// For every topic that has a `relay_name` this device has not moved to yet:
  /// add the new subscription, wait for the relay to accept it, then remove
  /// the plain one. A failed add leaves the plain subscription in place, a
  /// failed remove leaves both, and either is tried again on the next list.
  /// A failure never fails the list itself.
  Future<void> _moveToRelayNames(List<Topic> topics) {
    final run = _moves.then((_) async {
      final target = await _relayTarget();
      if (target == null) return;
      for (final topic in topics) {
        final secret = topic.relayName?.trim() ?? '';
        if (secret.isEmpty || _isMoved(target.baseUrl, topic.name)) continue;
        try {
          await _subscribe(target, secret);
          await _unsubscribe(target, topic.name);
          await _markMoved(target.baseUrl, topic.name);
        } on Exception {
          // Keep whatever is subscribed. The next refresh tries again.
        }
      }
    });
    return _moves = run.catchError((Object _) {});
  }

  /// The topic's `relay_name`, from this run's list or, failing that, from the
  /// server.
  Future<String?> _relayNameOf(String name) async {
    final known = _relayNames[name];
    if (known != null) return known;
    final topics = await _client.getTopics();
    _rememberRelayNames(topics);
    return _relayNames[name];
  }

  final ApiClient _client;

  @override
  Future<AppResult<List<Topic>>> getTopics() async {
    try {
      final topics = await _client.getTopics();
      final prefs = this.prefs;
      if (prefs != null) {
        await TopicTimerCache(prefs).save(topics);
      }
      _rememberRelayNames(topics);
      // Not awaited: the list should not wait on relay calls, and a failed
      // move is retried on the next list anyway.
      unawaited(_moveToRelayNames(topics));
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
    String? tokenName,
  }) async {
    try {
      final topic = await _client.createTopic(
        name: name,
        critical: critical,
        repeatIntervalS: repeatIntervalS,
        maxRingS: maxRingS,
        deskTimerS: deskTimerS,
        relayContent: relayContent,
        tokenName: tokenName,
      );
      try {
        final target = await _relayTarget();
        if (target != null) {
          await _subscribe(
            target,
            ServerInfoValidation.hashSourceFor(
              name: topic.name,
              relayName: topic.relayName,
            ),
          );
          // Nothing was ever subscribed by name, so there is nothing to move.
          if (topic.relayName?.trim().isNotEmpty ?? false) {
            await _markMoved(target.baseUrl, topic.name);
          }
        }
      } on Exception {
        // Do not leave a created topic whose one-time token was never returned.
        await _client.deleteTopic(name);
        rethrow;
      }
      _rememberRelayNames([topic]);
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
      // Both hashes go: a topic deleted halfway through a move holds the plain
      // one and the secret one, and neither may outlive it.
      final target = await _relayTarget();
      final relayName = target == null ? null : await _relayNameOf(name);
      if (target != null) {
        await _unsubscribe(target, name);
        if (relayName != null) await _unsubscribe(target, relayName);
      }
      try {
        await _client.deleteTopic(name);
      } on Exception {
        // Put back the one hash the topic should be on, the secret one when it
        // has one. The plain hash stays gone.
        if (target != null) {
          await _subscribe(
            target,
            ServerInfoValidation.hashSourceFor(
              name: name,
              relayName: relayName,
            ),
          );
        }
        rethrow;
      }
      _relayNames.remove(name);
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
  Future<AppResult<TopicToken>> createTopicToken(
    String name, {
    String? tokenName,
  }) async {
    try {
      final token = await _client.createTopicToken(name, tokenName: tokenName);
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
  Future<AppResult<TopicTokenInfo>> renameTopicToken(
    String name,
    String tokenId,
    String tokenName,
  ) async {
    try {
      final renamed = await _client.renameTopicToken(name, tokenId, tokenName);
      return renamed.toSuccess();
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
