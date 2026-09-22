import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/send_result.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/core/store/local_store.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/entities/message.dart';
import 'package:critalarm/features/incidents/domain/repositories/incident_repository.dart';

/// [IncidentRepository] backed by [ApiClient], with the phone's own copy in
/// front of it.
///
/// api.md §4.2: a hosted or relay server deletes rows past the account's
/// `history_days`, so the server is no longer the archive. Reads answer from
/// [LocalStore] and the network call only adds what the phone has not seen.
/// Without a store it behaves exactly as it did before, which is what the
/// tests that build it with an [ApiClient] alone rely on.
class InMemoryIncidentRepository implements IncidentRepository {
  const InMemoryIncidentRepository(this._client, {this.store});

  final ApiClient _client;

  /// The phone's copy. Null in the tests that only exercise the wire.
  final LocalStore? store;

  @override
  Future<AppResult<List<Incident>>> getIncidents({
    required int limit,
    String? state,
    String? topic,
    DateTime? since,
    bool fullRefresh = false,
  }) async {
    final store = this.store;
    if (store == null) {
      try {
        final incidents = await _client.getIncidents(
          limit: limit,
          state: state,
          topic: topic,
          since: since,
        );
        return incidents.toSuccess();
      } on ApiException catch (e) {
        return _apiFailure(e);
      } on Exception catch (e) {
        return Failure.unexpected(message: e.toString()).toFailure();
      }
    }

    // What the phone already holds. This is the answer when the network
    // never gives one, so History opens with the server down.
    Future<List<Incident>> local() =>
        store.incidents.page(limit: limit, topic: topic);

    final askFor = fullRefresh
        ? null
        : (since ?? await store.incidents.newestOpenedAt());

    try {
      final fresh = await _client.getIncidents(
        limit: limit,
        state: state,
        topic: topic,
        since: askFor,
      );
      await store.incidents.upsertAll(fresh);
    } on Exception catch (e) {
      // The server being down is not an empty history any more.
      final held = await local();
      if (held.isNotEmpty) return held.toSuccess();
      return e is ApiException
          ? _apiFailure(e)
          : Failure.unexpected(message: e.toString()).toFailure();
    }

    return (await local()).toSuccess();
  }

  AppResult<T> _apiFailure<T extends Object>(ApiException e) => Failure.api(
    statusCode: e.statusCode,
    message: e.message,
    code: e.code,
    cap: e.cap,
  ).toFailure();

  @override
  Future<AppResult<Incident>> getIncident(String id) async {
    try {
      final incident = await _client.getIncident(id);
      return incident.toSuccess();
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
  Future<AppResult<Incident>> ackIncident(String id) async {
    try {
      final incident = await _client.ackIncident(id);
      return incident.toSuccess();
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
  Future<AppResult<Incident>> closeIncident(String id) async {
    try {
      final incident = await _client.closeIncident(id);
      return incident.toSuccess();
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
  Future<AppResult<String>> triggerTest({required String topic}) async {
    try {
      final incidentId = await _client.triggerTest(topic: topic);
      return incidentId.toSuccess();
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
  Future<AppResult<SendResult>> publishMessage(
    String topic, {
    required String message,
    String? title,
    int priority = 3,
    List<String>? tags,
  }) async {
    try {
      final msg = await _client.publishMessage(
        topic,
        message: message,
        title: title,
        priority: priority,
        tags: tags,
      );
      return msg.toSuccess();
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
  Future<AppResult<List<Message>>> pollMessages(
    String topic, {
    required int poll,
    String? since,
  }) async {
    final store = this.store;
    if (store != null) {
      Future<List<Message>> local() =>
          store.messages.page(topic: topic, limit: maxIncidentLimit);

      final askFor = since ?? await store.messages.newestMessageId(topic);
      try {
        final fresh = await _client.pollMessages(
          topic,
          poll: poll,
          since: askFor,
        );
        await store.messages.upsertAll(fresh);
      } on Exception catch (e) {
        final held = await local();
        if (held.isNotEmpty) return held.toSuccess();
        return e is ApiException
            ? _apiFailure(e)
            : Failure.unexpected(message: e.toString()).toFailure();
      }
      return (await local()).toSuccess();
    }

    try {
      final messages = await _client.pollMessages(
        topic,
        poll: poll,
        since: since,
      );
      return messages.toSuccess();
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
