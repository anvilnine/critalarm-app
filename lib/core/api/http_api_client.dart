import 'dart:convert';

import 'package:critalarm/core/api/account_results.dart';
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
  HttpApiClient(this._http, this._sessions, {this.onDeadCredential});

  final http.Client _http;
  final ApiSessionStore _sessions;

  /// Called when a route answers 401 to this phone's own device token.
  ///
  /// api.md §3.7: after somebody deletes the account from another handset,
  /// every other device on it gets 401 on its next call. The credential is
  /// dead for good, so retrying it forever just spins. Whoever is wired in
  /// here starts the phone over on a fresh anonymous account.
  ///
  /// Only a 401 on a device token fires it. A topic token that does not match
  /// its topic answers 401 too, and that is a wrong `tk_`, not a dead account.
  final Future<void> Function()? onDeadCredential;

  /// The prefix api.md §4.2 gives every device token.
  static const _deviceTokenPrefix = 'dv_';

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
    // Statuses the caller reads off the response itself. The account routes
    // need it: a 409 carries the topic and incident counts the prompt shows,
    // and turning it into an exception throws those away.
    Set<int> tolerate = const {},
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
    if ((result.statusCode < 200 || result.statusCode >= 300) &&
        !tolerate.contains(result.statusCode)) {
      if (result.statusCode == 401 &&
          (auth?.startsWith(_deviceTokenPrefix) ?? false)) {
        final recover = onDeadCredential;
        if (recover != null) {
          try {
            await recover();
          } on Object catch (_) {
            // The caller still has to hear about the 401 it asked about, so a
            // recovery that itself failed is not allowed to replace it.
          }
        }
      }
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
    String? tokenName,
  }) async {
    final (session, uri) = await _sessionUri(const ['topics']);
    final response = await _send(
      'POST',
      uri,
      auth: session.managementCredential,
      body: {
        'name': name,
        'critical': critical,
        'token_name': ?tokenName,
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
  Future<List<TopicTokenInfo>> getTopicTokens(String name) async {
    final (s, u) = await _sessionUri(['topics', name, 'tokens']);
    final json =
        _json(await _send('GET', u, auth: s.managementCredential))
            as List<dynamic>;
    return json
        .map((e) => TopicTokenInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<TopicToken> createTopicToken(String name, {String? tokenName}) async {
    final (s, u) = await _sessionUri(['topics', name, 'tokens']);
    final j =
        _json(
              await _send(
                'POST',
                u,
                auth: s.managementCredential,
                body: tokenName == null ? null : {'name': tokenName},
              ),
            )
            as Map<String, dynamic>;
    return TopicToken.fromJson(j);
  }

  @override
  Future<TopicTokenInfo> renameTopicToken(
    String name,
    String tokenId,
    String tokenName,
  ) async {
    final (s, u) = await _sessionUri(['topics', name, 'tokens', tokenId]);
    final j =
        _json(
              await _send(
                'PATCH',
                u,
                auth: s.managementCredential,
                body: {'name': tokenName},
              ),
            )
            as Map<String, dynamic>;
    return TopicTokenInfo.fromJson(j);
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
    DateTime? since,
  }) async {
    // Always on the wire. An absent `limit` means 20 on the server, never
    // "everything", so this line is the whole fix for paid History.
    final query = <String, String>{'limit': '$limit'};
    if (state != null) query['state'] = state;
    if (topic != null) query['topic'] = topic;
    if (since != null) {
      query['since'] = '${since.toUtc().millisecondsSinceEpoch ~/ 1000}';
    }
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
  Future<AccountLinkResult> linkAccount({
    required String identityToken,
    AccountLinkIntent intent = AccountLinkIntent.signIn,
  }) async {
    final (session, uri) = await _sessionUri(const ['account', 'link']);
    final response = await _send(
      'POST',
      uri,
      auth: session.managementCredential,
      body: {
        'identity_token': identityToken,
        'intent': intent.wireValue,
      },
      tolerate: const {401, 409},
    );
    if (response.statusCode == 401) {
      return const AccountLinkResult.unauthorized();
    }
    final json = _json(response) as Map<String, dynamic>;
    if (response.statusCode == 409) {
      return switch (json['error']) {
        'choose' => AccountLinkResult.choose(
          intoAccount: json['into_account'] as String,
          topics: (json['topics'] as num).toInt(),
          incidents: (json['incidents'] as num).toInt(),
        ),
        'identity has another account' =>
          const AccountLinkResult.identityHasAnotherAccount(),
        _ => const AccountLinkResult.accountHasAnotherIdentity(),
      };
    }
    final accountId = json['account_id'] as String;
    // Read as a string, never an enum: a 200 always carries `account_id` and
    // always means the phone is on that account, so an outcome this build has
    // not heard of must still sign the person in rather than raise an error.
    // `already_linked` arrives under both intents, so the sign-in screen gets
    // it too after a dropped reply.
    return switch (json['outcome']) {
      'attached' => AccountLinkResult.attached(accountId: accountId),
      'linked' => AccountLinkResult.linked(accountId: accountId),
      'already_linked' => AccountLinkResult.alreadyLinked(accountId: accountId),
      _ => AccountLinkResult.claimed(accountId: accountId),
    };
  }

  @override
  Future<AccountJoinTokenResult> mintAccountJoinToken() async {
    final (session, uri) = await _sessionUri(const ['account', 'join-token']);
    final response = await _send(
      'POST',
      uri,
      auth: session.managementCredential,
      tolerate: const {401},
    );
    if (response.statusCode == 401) {
      return const AccountJoinTokenResult.unauthorized();
    }
    final json = _json(response) as Map<String, dynamic>;
    return AccountJoinTokenResult.minted(
      joinToken: json['join_token'] as String,
    );
  }

  @override
  Future<AccountMergeResult> mergeAccount({
    required String identityToken,
    required String intoAccount,
  }) async {
    final (session, uri) = await _sessionUri(const ['account', 'merge']);
    final response = await _send(
      'POST',
      uri,
      auth: session.managementCredential,
      body: {'identity_token': identityToken, 'into_account': intoAccount},
      tolerate: const {401, 409},
    );
    if (response.statusCode == 401) {
      return const AccountMergeResult.unauthorized();
    }
    final json = _json(response) as Map<String, dynamic>;
    if (response.statusCode == 409) {
      return switch (json['error']) {
        'live incident' => AccountMergeResult.liveIncident(
          incidentId: json['incident_id'] as String,
        ),
        'same account' => const AccountMergeResult.sameAccount(),
        _ => const AccountMergeResult.alreadyMerged(),
      };
    }
    return AccountMergeResult.merged(
      accountId: json['account_id'] as String,
      mergedFrom: json['merged_from'] as String,
    );
  }

  @override
  Future<AccountSwitchResult> switchAccount({
    required String identityToken,
    required String intoAccount,
  }) async {
    final (session, uri) = await _sessionUri(const ['account', 'switch']);
    final response = await _send(
      'POST',
      uri,
      auth: session.managementCredential,
      body: {'identity_token': identityToken, 'into_account': intoAccount},
      tolerate: const {401},
    );
    if (response.statusCode == 401) {
      return const AccountSwitchResult.unauthorized();
    }
    final json = _json(response) as Map<String, dynamic>;
    return AccountSwitchResult.switched(
      accountId: json['account_id'] as String,
    );
  }

  @override
  Future<AccountDeleteResult> deleteAccount({String? identityToken}) async {
    final (session, uri) = await _sessionUri(const ['account']);
    final response = await _send(
      'DELETE',
      uri,
      auth: session.managementCredential,
      // Left out entirely when nobody is signed in. A null or an empty string
      // reads to the server as an identity token that does not match, which
      // is a 401 on an account that should have deleted on the device token
      // alone.
      body: identityToken == null ? null : {'identity_token': identityToken},
      tolerate: const {401, 409},
    );
    if (response.statusCode == 401) {
      return const AccountDeleteResult.unauthorized();
    }
    if (response.statusCode == 409) {
      final json = _json(response) as Map<String, dynamic>;
      return AccountDeleteResult.liveIncident(
        incidentId: json['incident_id'] as String,
      );
    }
    // 204 carries no body, so there is nothing to read here.
    return const AccountDeleteResult.deleted();
  }

  @override
  Future<void> deleteDevice({
    required String deviceId,
    required String deviceToken,
    Uri? relayUri,
  }) async {
    final base = relayUri ?? (await _sessions.read())?.relayUri;
    if (base == null) throw StateError('No API session configured');
    await _send(
      'DELETE',
      _rawPath(base, 'relay/v1/devices/${Uri.encodeComponent(deviceId)}'),
      auth: deviceToken,
    );
  }

  @override
  Future<DeviceRegistrationResponse> registerDevice(
    DeviceRegistration registration, {
    Uri? relayUri,
    String? accountJoinToken,
  }) async {
    final base = relayUri ?? (await _sessions.read())?.relayUri;
    if (base == null) throw StateError('No API session configured');
    final uri = _rawPath(base, 'relay/v1/devices');
    final response = await _send(
      'POST',
      uri,
      auth: accountJoinToken,
      body: registration.toJson(),
    );
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
