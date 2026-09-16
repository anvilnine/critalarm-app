import 'dart:convert';

import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/models/send_result.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/models/topic_token.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:http/http.dart' as http;

final class HttpApiClient implements ApiClient {
  HttpApiClient(this._http, this._sessions);

  final http.Client _http;
  final ApiSessionStore _sessions;

  Uri _path(Uri base, List<String> segments, [Map<String, String>? query]) {
    final prefix = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return _rawUri(
      base,
      '$prefix/v1/${segments.map(Uri.encodeComponent).join('/')}',
      query,
    );
  }

  Uri _rawPath(Uri base, String path, [Map<String, String>? query]) {
    final prefix = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return _rawUri(base, '$prefix/$path', query);
  }

  Uri _rawUri(Uri base, String path, Map<String, String>? query) {
    final authority = base.hasPort ? '${base.host}:${base.port}' : base.host;
    final queryString = query == null ? '' : Uri(queryParameters: query).query;
    return Uri.parse(
      '${base.scheme}://$authority$path${queryString.isEmpty ? '' : '?$queryString'}',
    );
  }

  /// How long any one request waits before it gives up.
  static const requestTimeout = Duration(seconds: 12);

  Future<http.Response> _send(
    String method,
    Uri uri, {
    Object? body,
    String? auth,
    String accept = 'application/json',
  }) async {
    final headers = <String, String>{'accept': accept};
    if (body != null) headers['content-type'] = 'application/json';
    if (auth != null) headers['authorization'] = 'Bearer $auth';
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    // A host that accepts the socket and then says nothing used to hang until
    // the OS gave up, with the connect button spinning the whole time.
    final response = await _http.send(request).timeout(requestTimeout);
    final result = await http.Response.fromStream(response).timeout(
      requestTimeout,
    );
    if (result.statusCode < 200 || result.statusCode >= 300) {
      var json = <String, dynamic>{};
      try {
        json = jsonDecode(result.body) as Map<String, dynamic>;
      } on FormatException {
        // Preserve generic HTTP failure when server body is not JSON.
      }
      throw ApiException(
        statusCode: result.statusCode,
        message:
            json['error']?.toString() ??
            result.reasonPhrase ??
            'Request failed',
        code: (json['code'] as num?)?.toInt(),
        cap: json['cap']?.toString(),
      );
    }
    return result;
  }

  Future<(ApiSession, Uri)> _sessionUri(
    List<String> segments, {
    Map<String, String>? query,
  }) async {
    final session = await _sessions.read();
    if (session == null) throw StateError('No API session configured');
    return (session, _path(session.baseUri, segments, query));
  }

  dynamic _json(http.Response response) => jsonDecode(response.body);

  @override
  Future<ServerInfo> getServerInfo([Uri? candidateBaseUri]) async {
    if (candidateBaseUri == null) {
      throw ArgumentError('candidateBaseUri is required');
    }
    final response = await _send(
      'GET',
      _path(candidateBaseUri, const ['info']),
    );
    return ServerInfo.fromJson(_json(response) as Map<String, dynamic>);
  }

  @override
  Future<List<Topic>> getTopics() async {
    final (session, uri) = await _sessionUri(const ['topics']);
    final json =
        _json(await _send('GET', uri, auth: session.managementCredential))
            as List<dynamic>;
    return json.map((e) => Topic.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<Topic> createTopic({
    required String name,
    bool critical = false,
    int repeatIntervalS = 30,
    int maxRingS = 1800,
    int deskTimerS = 600,
    String relayContent = 'none',
  }) async {
    final (session, uri) = await _sessionUri(const ['topics']);
    final response = await _send(
      'POST',
      uri,
      auth: session.managementCredential,
      body: {
        'name': name,
        'critical': critical,
      },
    );
    return Topic.fromJson(_json(response) as Map<String, dynamic>);
  }

  @override
  Future<Topic> updateTopic(
    String name, {
    bool? critical,
    int? repeatIntervalS,
    int? maxRingS,
    int? deskTimerS,
  }) async {
    final (session, uri) = await _sessionUri(['topics', name]);
    final body = <String, Object?>{};
    if (critical != null) body['critical'] = critical;
    if (repeatIntervalS != null) body['repeat_interval_s'] = repeatIntervalS;
    if (maxRingS != null) body['max_ring_s'] = maxRingS;
    if (deskTimerS != null) body['desk_timer_s'] = deskTimerS;
    return Topic.fromJson(
      _json(
            await _send(
              'PATCH',
              uri,
              auth: session.managementCredential,
              body: body,
            ),
          )
          as Map<String, dynamic>,
    );
  }

  @override
  Future<void> deleteTopic(String name) async {
    final (s, u) = await _sessionUri(['topics', name]);
    await _send('DELETE', u, auth: s.managementCredential);
  }

  @override
  Future<TopicToken> createTopicToken(String name) async {
    final (s, u) = await _sessionUri(['topics', name, 'tokens']);
    final j =
        _json(await _send('POST', u, auth: s.managementCredential))
            as Map<String, dynamic>;
    return TopicToken.fromJson(j);
  }

  @override
  Future<void> deleteTopicToken(String name, String tokenId) async {
    final (s, u) = await _sessionUri(['topics', name, 'tokens', tokenId]);
    await _send('DELETE', u, auth: s.managementCredential);
  }

  @override
  Future<List<Incident>> getIncidents({
    required int limit,
    String? state,
    String? topic,
  }) async {
    // Always on the wire. An absent `limit` means 20 on the server, never
    // "everything", so this line is the whole fix for paid History.
    final query = <String, String>{'limit': '$limit'};
    if (state != null) query['state'] = state;
    if (topic != null) query['topic'] = topic;
    final (s, u) = await _sessionUri(
      const ['incidents'],
      query: query,
    );
    final j =
        _json(await _send('GET', u, auth: s.managementCredential))
            as List<dynamic>;
    return j.map((e) => Incident.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<Incident> getIncident(String id) async {
    final (s, u) = await _sessionUri(['incidents', id]);
    return Incident.fromJson(
      _json(await _send('GET', u, auth: s.managementCredential))
          as Map<String, dynamic>,
    );
  }

  @override
  Future<Incident> ackIncident(String id) async {
    final (s, u) = await _sessionUri(['incidents', id, 'ack']);
    return Incident.fromJson(
      _json(await _send('POST', u, auth: s.managementCredential))
          as Map<String, dynamic>,
    );
  }

  @override
  Future<Incident> closeIncident(String id) async {
    final (s, u) = await _sessionUri(['incidents', id, 'close']);
    return Incident.fromJson(
      _json(await _send('POST', u, auth: s.managementCredential))
          as Map<String, dynamic>,
    );
  }

  @override
  Future<String> triggerTest({required String topic}) async {
    final (s, u) = await _sessionUri(const ['test'], query: {'topic': topic});
    final j =
        _json(await _send('POST', u, auth: s.managementCredential))
            as Map<String, dynamic>;
    return j['incident_id'] as String;
  }

  @override
  Future<DeviceRegistrationResponse> registerDevice(
    DeviceRegistration registration, {
    Uri? relayUri,
  }) async {
    final base = relayUri ?? (await _sessions.read())?.relayUri;
    if (base == null) throw StateError('No API session configured');
    final uri = _rawPath(base, 'relay/v1/devices');
    final response = await _send('POST', uri, body: registration.toJson());
    return DeviceRegistrationResponse.fromJson(
      _json(response) as Map<String, dynamic>,
    );
  }

  @override
  Future<DeviceRegistrationResponse> refreshDevice(
    DeviceRegistration registration,
    String deviceToken, {
    Uri? relayUri,
  }) async {
    final base = relayUri ?? (await _sessions.read())?.relayUri;
    if (base == null) throw StateError('No API session configured');
    final uri = _rawPath(
      base,
      'relay/v1/devices/${Uri.encodeComponent(registration.deviceId)}',
    );
    final response = await _send(
      'PATCH',
      uri,
      auth: deviceToken,
      body: {
        'push_token': registration.pushToken,
        'app_version': registration.appVersion,
      },
    );
    return DeviceRegistrationResponse.fromJson(
      _json(response) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> subscribeTopic({
    required String deviceId,
    required String deviceToken,
    required String topicHash,
  }) async {
    final session = await _sessions.read();
    if (session == null) throw StateError('No API session configured');
    await _send(
      'POST',
      _rawPath(
        session.relayUri,
        'relay/v1/devices/${Uri.encodeComponent(deviceId)}/subscriptions',
      ),
      auth: deviceToken,
      body: {'topic_hash': topicHash},
    );
  }

  @override
  Future<void> unsubscribeTopic({
    required String deviceId,
    required String deviceToken,
    required String topicHash,
  }) async {
    final session = await _sessions.read();
    if (session == null) throw StateError('No API session configured');
    await _send(
      'DELETE',
      _rawPath(
        session.relayUri,
        'relay/v1/devices/${Uri.encodeComponent(deviceId)}/subscriptions/${Uri.encodeComponent(topicHash)}',
      ),
      auth: deviceToken,
    );
  }

  @override
  Future<void> uploadActivityToken({
    required String deviceId,
    required String deviceToken,
    required String kind,
    required String token,
    String? incidentId,
    String? activityId,
  }) async {
    final session = await _sessions.read();
    if (session == null) throw StateError('No API session configured');
    final uri = _rawPath(
      session.relayUri,
      'relay/v1/devices/${Uri.encodeComponent(deviceId)}/tokens',
    );
    if (kind == 'la_update' && (activityId == null || activityId.isEmpty)) {
      throw ArgumentError('la_update requires activityId');
    }
    await _send(
      'POST',
      uri,
      auth: deviceToken,
      body: {
        'kind': kind,
        'token': token,
        if (kind == 'la_update') 'activity_id': activityId,
        if (kind == 'la_update' && incidentId != null)
          'incident_id': incidentId,
      },
    );
  }

  @override
  Future<SendResult> publishMessage(
    String topic, {
    required String message,
    String? title,
    int priority = 3,
    List<String>? tags,
  }) async {
    final (s, uri) = await _sessionUri(['topics', topic, 'send']);
    final response = await _send(
      'POST',
      uri,
      auth: s.managementCredential,
      body: {
        'message': message,
        'priority': priority,
        'title': ?title,
        'tags': ?tags,
      },
    );
    return SendResult.fromJson(_json(response) as Map<String, dynamic>);
  }

  @override
  Future<List<Message>> pollMessages(
    String topic, {
    required int poll,
    String? since,
  }) async {
    final session = await _sessions.read();
    if (session == null) throw StateError('No API session configured');
    final uri = _rawPath(
      session.baseUri,
      '${Uri.encodeComponent(topic)}/json',
      {'poll': '$poll', 'since': ?since},
    );
    final response = await _send(
      'GET',
      uri,
      auth: session.managementCredential,
      accept: 'application/x-ndjson',
    );
    return const LineSplitter()
        .convert(response.body)
        .where((line) => line.trim().isNotEmpty)
        .map(
          (line) => Message.fromJson(jsonDecode(line) as Map<String, dynamic>),
        )
        .toList();
  }
}
