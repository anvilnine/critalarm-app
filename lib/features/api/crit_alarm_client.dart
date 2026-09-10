import 'dart:convert';

import 'package:critalarm/features/api/api_failure.dart';
import 'package:critalarm/features/api/models/crit_message.dart';
import 'package:critalarm/features/api/models/device_registration.dart';
import 'package:critalarm/features/api/models/incident.dart';
import 'package:critalarm/features/api/models/server_info.dart';
import 'package:critalarm/features/api/models/topic.dart';
import 'package:critalarm/features/api/models/topic_with_token.dart';
import 'package:http/http.dart' as http;
import 'package:result_dart/result_dart.dart';

export 'package:critalarm/features/api/api_failure.dart';
export 'package:critalarm/features/api/models/api_error.dart';
export 'package:critalarm/features/api/models/caps.dart';
export 'package:critalarm/features/api/models/crit_message.dart';
export 'package:critalarm/features/api/models/device_registration.dart';
export 'package:critalarm/features/api/models/incident.dart';
export 'package:critalarm/features/api/models/server_info.dart';
export 'package:critalarm/features/api/models/topic.dart';
export 'package:critalarm/features/api/models/topic_with_token.dart';
export 'package:result_dart/result_dart.dart';

/// Result type used by [CritAlarmClient].
typedef Result<T extends Object> = ResultDart<T, ApiFailure>;

/// HTTP client for Crit Alarm server and relay APIs.
class CritAlarmClient {
  /// Creates a new [CritAlarmClient] with a base URL and an HTTP client.
  CritAlarmClient(
    String baseUrl,
    this.client, {
    this.deviceToken,
    this.topicToken,
  }) : baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl;

  /// Base URL of the Crit Alarm server.
  final String baseUrl;

  /// Underlying HTTP client.
  final http.Client client;

  /// Device token (`dv_...`) used for `/v1/` and `/relay/v1/` routes.
  final String? deviceToken;

  /// Topic token (`tk_...`) used for polling or publish routes.
  final String? topicToken;

  Map<String, String> _headers({
    bool jsonContent = false,
    String? bearerToken,
  }) {
    final headers = <String, String>{};
    if (jsonContent) {
      headers['Content-Type'] = 'application/json';
    }
    if (bearerToken != null && bearerToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $bearerToken';
    }
    return headers;
  }

  Result<T> _handleError<T extends Object>(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final code = decoded['code'] as int? ?? (response.statusCode * 100 + 1);
        final httpStatus = decoded['http'] as int? ?? response.statusCode;
        final error = decoded['error'] as String? ?? response.body;
        return Failure(
          ApiFailure(
            code: code,
            http: httpStatus,
            error: error,
          ),
        );
      }
    } on Object catch (_) {
      // Body was not JSON.
    }
    return Failure(
      ApiFailure(
        code: response.statusCode * 100 + 1,
        http: response.statusCode,
        error: response.body.isNotEmpty
            ? response.body
            : (response.reasonPhrase ?? 'HTTP ${response.statusCode}'),
      ),
    );
  }

  /// Fetches server info via `GET /v1/info`. No auth required.
  Future<Result<ServerInfo>> info() async {
    try {
      final uri = Uri.parse('$baseUrl/v1/info');
      final response = await client.get(uri);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return Success(ServerInfo.fromJson(json));
      }
      return _handleError<ServerInfo>(response);
    } on Exception catch (e) {
      return Failure(
        ApiFailure(code: 50001, http: 500, error: e.toString()),
      );
    }
  }

  /// Registers a device via `POST /relay/v1/devices`. No auth required.
  Future<Result<DeviceRegistration>> registerDevice({
    required String deviceId,
    required String platform,
    required String pushToken,
    required String appVersion,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/relay/v1/devices');
      final body = jsonEncode({
        'device_id': deviceId,
        'platform': platform,
        'push_token': pushToken,
        'app_version': appVersion,
      });
      final response = await client.post(
        uri,
        headers: _headers(jsonContent: true),
        body: body,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return Success(DeviceRegistration.fromJson(json));
      }
      return _handleError<DeviceRegistration>(response);
    } on Exception catch (e) {
      return Failure(
        ApiFailure(code: 50001, http: 500, error: e.toString()),
      );
    }
  }

  /// Updates device push token or app version via `PATCH /relay/v1/devices/{id}`.
  Future<Result<void>> updateDevice({
    required String deviceId,
    required String pushToken,
    required String appVersion,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/relay/v1/devices/$deviceId');
      final body = jsonEncode({
        'push_token': pushToken,
        'app_version': appVersion,
      });
      final response = await client.patch(
        uri,
        headers: _headers(jsonContent: true, bearerToken: deviceToken),
        body: body,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const Success(unit);
      }
      return _handleError<Unit>(response);
    } on Exception catch (e) {
      return Failure(
        ApiFailure(code: 50001, http: 500, error: e.toString()),
      );
    }
  }

  /// Subscribes a device to a topic hash via
  /// `POST /relay/v1/devices/{id}/subscriptions`.
  Future<Result<void>> subscribe(String deviceId, String topicHash) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/relay/v1/devices/$deviceId/subscriptions',
      );
      final body = jsonEncode({'topic_hash': topicHash});
      final response = await client.post(
        uri,
        headers: _headers(jsonContent: true, bearerToken: deviceToken),
        body: body,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const Success(unit);
      }
      return _handleError<Unit>(response);
    } on Exception catch (e) {
      return Failure(
        ApiFailure(code: 50001, http: 500, error: e.toString()),
      );
    }
  }

  /// Unsubscribes a device from a topic hash via
  /// `DELETE /relay/v1/devices/{id}/subscriptions/{hash}`.
  Future<Result<void>> unsubscribe(String deviceId, String topicHash) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/relay/v1/devices/$deviceId/subscriptions/$topicHash',
      );
      final response = await client.delete(
        uri,
        headers: _headers(bearerToken: deviceToken),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const Success(unit);
      }
      return _handleError<Unit>(response);
    } on Exception catch (e) {
      return Failure(
        ApiFailure(code: 50001, http: 500, error: e.toString()),
      );
    }
  }

  /// Lists all topics owned by the account via `GET /v1/topics`.
  Future<Result<List<Topic>>> listTopics() async {
    try {
      final uri = Uri.parse('$baseUrl/v1/topics');
      final response = await client.get(
        uri,
        headers: _headers(bearerToken: deviceToken),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as List<dynamic>;
        final topics = decoded
            .map((e) => Topic.fromJson(e as Map<String, dynamic>))
            .toList();
        return Success(topics);
      }
      return _handleError<List<Topic>>(response);
    } on Exception catch (e) {
      return Failure(
        ApiFailure(code: 50001, http: 500, error: e.toString()),
      );
    }
  }

  /// Creates a new topic via `POST /v1/topics`.
  Future<Result<TopicWithToken>> createTopic(String name) async {
    try {
      final uri = Uri.parse('$baseUrl/v1/topics');
      final body = jsonEncode({'name': name});
      final response = await client.post(
        uri,
        headers: _headers(jsonContent: true, bearerToken: deviceToken),
        body: body,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return Success(TopicWithToken.fromJson(json));
      }
      return _handleError<TopicWithToken>(response);
    } on Exception catch (e) {
      return Failure(
        ApiFailure(code: 50001, http: 500, error: e.toString()),
      );
    }
  }

  /// Updates topic settings via `PATCH /v1/topics/{name}`.
  Future<Result<Topic>> patchTopic(
    String name, {
    bool? critical,
    int? repeatIntervalS,
    int? maxRingS,
    int? deskTimerS,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/v1/topics/$name');
      final payload = <String, dynamic>{};
      if (critical != null) payload['critical'] = critical;
      if (repeatIntervalS != null) {
        payload['repeat_interval_s'] = repeatIntervalS;
      }
      if (maxRingS != null) payload['max_ring_s'] = maxRingS;
      if (deskTimerS != null) payload['desk_timer_s'] = deskTimerS;

      final response = await client.patch(
        uri,
        headers: _headers(jsonContent: true, bearerToken: deviceToken),
        body: jsonEncode(payload),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return Success(Topic.fromJson(json));
      }
      return _handleError<Topic>(response);
    } on Exception catch (e) {
      return Failure(
        ApiFailure(code: 50001, http: 500, error: e.toString()),
      );
    }
  }

  /// Deletes a topic via `DELETE /v1/topics/{name}`.
  Future<Result<void>> deleteTopic(String name) async {
    try {
      final uri = Uri.parse('$baseUrl/v1/topics/$name');
      final response = await client.delete(
        uri,
        headers: _headers(bearerToken: deviceToken),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const Success(unit);
      }
      return _handleError<Unit>(response);
    } on Exception catch (e) {
      return Failure(
        ApiFailure(code: 50001, http: 500, error: e.toString()),
      );
    }
  }

  /// Lists incidents via `GET /v1/incidents`.
  Future<Result<List<Incident>>> listIncidents({
    int limit = 20,
    String? state,
    String? topic,
  }) async {
    try {
      final queryParameters = <String, String>{
        'limit': limit.toString(),
      };
      if (state != null) queryParameters['state'] = state;
      if (topic != null) queryParameters['topic'] = topic;

      final baseUri = Uri.parse('$baseUrl/v1/incidents');
      final uri = baseUri.replace(queryParameters: queryParameters);

      final response = await client.get(
        uri,
        headers: _headers(bearerToken: deviceToken),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body) as List<dynamic>;
        final incidents = decoded
            .map((e) => Incident.fromJson(e as Map<String, dynamic>))
            .toList();
        return Success(incidents);
      }
      return _handleError<List<Incident>>(response);
    } on Exception catch (e) {
      return Failure(
        ApiFailure(code: 50001, http: 500, error: e.toString()),
      );
    }
  }

  /// Fetches an incident by id via `GET /v1/incidents/{id}`.
  Future<Result<Incident>> getIncident(String id) async {
    try {
      final uri = Uri.parse('$baseUrl/v1/incidents/$id');
      final response = await client.get(
        uri,
        headers: _headers(bearerToken: deviceToken),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return Success(Incident.fromJson(json));
      }
      return _handleError<Incident>(response);
    } on Exception catch (e) {
      return Failure(
        ApiFailure(code: 50001, http: 500, error: e.toString()),
      );
    }
  }

  /// Acknowledges an incident via `POST /v1/incidents/{id}/ack`.
  Future<Result<Incident>> ack(String id) async {
    try {
      final uri = Uri.parse('$baseUrl/v1/incidents/$id/ack');
      final response = await client.post(
        uri,
        headers: _headers(bearerToken: deviceToken),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return Success(Incident.fromJson(json));
      }
      return _handleError<Incident>(response);
    } on Exception catch (e) {
      return Failure(
        ApiFailure(code: 50001, http: 500, error: e.toString()),
      );
    }
  }

  /// Closes an incident via `POST /v1/incidents/{id}/close`.
  Future<Result<Incident>> close(String id) async {
    try {
      final uri = Uri.parse('$baseUrl/v1/incidents/$id/close');
      final response = await client.post(
        uri,
        headers: _headers(bearerToken: deviceToken),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return Success(Incident.fromJson(json));
      }
      return _handleError<Incident>(response);
    } on Exception catch (e) {
      return Failure(
        ApiFailure(code: 50001, http: 500, error: e.toString()),
      );
    }
  }

  /// Triggers a test alarm via `POST /v1/test?topic={topic}`.
  /// Returns the generated incident ID.
  Future<Result<String>> testAlarm(String topic) async {
    try {
      final baseUri = Uri.parse('$baseUrl/v1/test');
      final uri = baseUri.replace(queryParameters: {'topic': topic});
      final response = await client.post(
        uri,
        headers: _headers(bearerToken: deviceToken),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final incidentId = json['incident_id'] as String;
        return Success(incidentId);
      }
      return _handleError<String>(response);
    } on Exception catch (e) {
      return Failure(
        ApiFailure(code: 50001, http: 500, error: e.toString()),
      );
    }
  }

  /// Polls messages for a topic via `GET /{topic}/json?poll=1[&since={since}]`.
  /// Uses [token] if provided, otherwise falls back to [topicToken].
  /// Never sends [deviceToken].
  Future<Result<List<CritMessage>>> poll(
    String topic, {
    String? since,
    String? token,
  }) async {
    try {
      final queryParameters = <String, String>{'poll': '1'};
      if (since != null) queryParameters['since'] = since;

      final baseUri = Uri.parse('$baseUrl/$topic/json');
      final uri = baseUri.replace(queryParameters: queryParameters);

      final authToken = token ?? topicToken;
      final response = await client.get(
        uri,
        headers: _headers(bearerToken: authToken),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final messages = <CritMessage>[];
        final lines = const LineSplitter().convert(response.body);
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          final json = jsonDecode(trimmed) as Map<String, dynamic>;
          messages.add(CritMessage.fromJson(json));
        }
        return Success(messages);
      }
      return _handleError<List<CritMessage>>(response);
    } on Exception catch (e) {
      return Failure(
        ApiFailure(code: 50001, http: 500, error: e.toString()),
      );
    }
  }
}
