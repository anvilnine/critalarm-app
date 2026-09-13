import 'dart:convert';

import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// In-memory mock server that implements the full Crit Alarm API contract from
/// `docs/api.md`.
class MockServer {
  MockServer({
    ServerInfo? serverInfo,
  }) : serverInfo =
           serverInfo ??
           const ServerInfo(
             version: '0.1.0',
             baseUrl: 'https://alerts.example.com',
             relayUrl: 'https://relay.critalarm.app',
           );

  /// Server metadata returned by /v1/info.
  ServerInfo serverInfo;
  final Map<String, Topic> _topics = {};
  final Map<String, Set<String>> _tokens = {};
  final Map<String, Incident> _incidents = {};
  final Map<String, List<Message>> _messages = {};
  final Map<String, DeviceRegistrationResponse> _devices = {};

  int _counter = 1000;

  /// Makes `GET /v1/incidents/{id}` answer 503, so the app's fallback path can
  /// be exercised. api.md §5.1 and §5.2 leave the title and body out under
  /// `relay_content: none`, and this is what a failed fetch of them looks like.
  bool failIncidentFetch = false;

  static final RegExp _topicRegex = RegExp(r'^[-_A-Za-z0-9]{1,64}$');

  String _nextId(String prefix) => '${prefix}_${++_counter}';

  /// Reset all stored state to empty.
  void reset() {
    _topics.clear();
    _tokens.clear();
    _incidents.clear();
    _messages.clear();
    _devices.clear();
    _counter = 1000;
    failIncidentFetch = false;
  }

  // ---------------------------------------------------------------------------
  // Fixtures
  // ---------------------------------------------------------------------------

  /// One message at every priority on `topic`, oldest first.
  ///
  /// api.md §1.7 sends each of these down a different path: 1-3 are stored and
  /// polled, 4 is forwarded as a high message, and 5 opens an incident when the
  /// topic is critical. The topic is created critical so priority 5 does.
  List<Message> seedPriorityLadder({String topic = 'prod'}) {
    if (!_topics.containsKey(topic)) {
      createTopic(name: topic, critical: true);
    }
    return [
      publishMessage(topic, title: 'Min', message: 'min priority', priority: 1),
      publishMessage(topic, title: 'Low', message: 'low priority', priority: 2),
      publishMessage(
        topic,
        title: 'Default',
        message: 'default priority',
        tags: const ['warning'],
      ),
      publishMessage(
        topic,
        title: 'High',
        message: 'high priority, no incident',
        priority: 4,
        tags: const ['fire', 'db01'],
      ),
      publishMessage(
        topic,
        title: 'Database down',
        message: 'db01 is unreachable from every region, page the on-call',
        priority: 5,
        tags: const ['rotating_light', 'db01'],
        click: 'https://status.example.com/db01',
      ),
    ];
  }

  /// The FCM `data` map (api.md §5.2) the relay would send for [message].
  ///
  /// Priority 1-3 is never forwarded, so those answer null.
  Map<String, String>? pushPayloadFor(
    Message message, {
    String kind = 'open',
    bool relayContentFull = false,
  }) {
    if (message.priority <= 3) return null;
    final isIncident = message.incidentId != null;
    return {
      if (isIncident) 'incident_id': message.incidentId!,
      'server': serverInfo.baseUrl,
      'kind': isIncident ? kind : 'p4',
      'priority': '${message.priority}',
      if (relayContentFull) ...{
        'title': message.title ?? message.topic,
        'body': message.message,
      },
    };
  }

  /// Load a pre-configured fixture corresponding to a [FaceState].
  void loadFixture(FaceState state) {
    switch (state) {
      case FaceState.calm:
        seedCalm();
      case FaceState.watching:
        seedWatching();
      case FaceState.worried:
        seedWorried();
      case FaceState.alarmed:
        seedAlarmed();
      case FaceState.acked:
        seedAcked();
    }
  }

  /// Calm fixture: All clear, 4 topics (`prod-db`, `nas-backup`, `uptime-kuma`,
  /// `home-ha`), last alert acknowledged, 0 open incidents.
  void seedCalm() {
    reset();
    final now = DateTime.now().toUtc();

    final prodDb = Topic(
      name: 'prod-db',
      critical: true,
      createdAt: now.subtract(const Duration(days: 30)),
    );
    final nasBackup = Topic(
      name: 'nas-backup',
      createdAt: now.subtract(const Duration(days: 20)),
    );
    final uptimeKuma = Topic(
      name: 'uptime-kuma',
      critical: true,
      createdAt: now.subtract(const Duration(days: 15)),
    );
    final homeHa = Topic(
      name: 'home-ha',
      createdAt: now.subtract(const Duration(days: 10)),
    );

    _topics[prodDb.name] = prodDb;
    _topics[nasBackup.name] = nasBackup;
    _topics[uptimeKuma.name] = uptimeKuma;
    _topics[homeHa.name] = homeHa;

    _tokens[prodDb.name] = {'tk_calm_proddb'};
    _tokens[nasBackup.name] = {'tk_calm_nasbackup'};
    _tokens[uptimeKuma.name] = {'tk_calm_uptimekuma'};
    _tokens[homeHa.name] = {'tk_calm_homeha'};

    // Last alert acknowledged and closed (0 open incidents)
    final closedMsg = Message(
      id: 'm_calm_resolved_1',
      topic: 'prod-db',
      time:
          now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000,
      title: 'High CPU load',
      message: 'CPU load reached 98%, returned to normal',
      priority: 5,
      tags: const ['cpu', 'warning'],
      incidentId: 'inc_calm_closed',
    );

    final closedIncident = Incident(
      id: 'inc_calm_closed',
      topic: 'prod-db',
      state: IncidentStates.closed,
      openedAt: now.subtract(const Duration(hours: 2)),
      ackedAt: now.subtract(const Duration(hours: 1, minutes: 50)),
      closedAt: now.subtract(const Duration(hours: 1, minutes: 30)),
      lastMessageAt: now.subtract(const Duration(hours: 2)),
      messages: [closedMsg],
    );

    _incidents[closedIncident.id] = closedIncident;
    _messages['prod-db'] = [closedMsg];
  }

  /// Watching fixture: Empty state (0 topics) or waiting for first message.
  void seedWatching() {
    reset();
  }

  /// Worried fixture: High priority message open on `nas-backup`
  /// ("Backup finished with 2 warnings", rsync: 2 files vanished), 1 warning.
  void seedWorried() {
    reset();
    final now = DateTime.now().toUtc();

    final nasBackup = Topic(
      name: 'nas-backup',
      createdAt: now.subtract(const Duration(days: 10)),
    );
    final prodDb = Topic(
      name: 'prod-db',
      critical: true,
      createdAt: now.subtract(const Duration(days: 20)),
    );

    _topics[nasBackup.name] = nasBackup;
    _topics[prodDb.name] = prodDb;
    _tokens[nasBackup.name] = {'tk_worried_nas'};
    _tokens[prodDb.name] = {'tk_worried_prod'};

    final warningMsg = Message(
      id: 'm_worried_nas_1',
      topic: 'nas-backup',
      time:
          now.subtract(const Duration(minutes: 10)).millisecondsSinceEpoch ~/
          1000,
      title: 'Backup finished with 2 warnings',
      message: 'rsync: 2 files vanished',
      priority: 4,
      tags: const ['warning', 'backup'],
    );

    _messages['nas-backup'] = [warningMsg];
  }

  /// Alarmed fixture: Critical incident open on `prod-db`
  /// ("Primary database down", ringing 2 min 14 s, repeats every 30 s).
  void seedAlarmed() {
    reset();
    final now = DateTime.now().toUtc();

    final prodDb = Topic(
      name: 'prod-db',
      critical: true,
      createdAt: now.subtract(const Duration(days: 30)),
    );
    final nasBackup = Topic(
      name: 'nas-backup',
      createdAt: now.subtract(const Duration(days: 10)),
    );
    final uptimeKuma = Topic(
      name: 'uptime-kuma',
      critical: true,
      createdAt: now.subtract(const Duration(days: 15)),
    );

    _topics[prodDb.name] = prodDb;
    _topics[nasBackup.name] = nasBackup;
    _topics[uptimeKuma.name] = uptimeKuma;

    _tokens[prodDb.name] = {'tk_alarmed_proddb'};
    _tokens[nasBackup.name] = {'tk_alarmed_nas'};
    _tokens[uptimeKuma.name] = {'tk_alarmed_kuma'};

    const incidentId = 'inc_alarmed_proddb';
    final openedAt = now.subtract(const Duration(seconds: 134));
    final lastMessageAt = now.subtract(const Duration(seconds: 14));

    final messages = [
      Message(
        id: 'm_alarm_1',
        topic: 'prod-db',
        time: openedAt.millisecondsSinceEpoch ~/ 1000,
        title: 'Primary database down',
        message: 'Connection pool exhausted (500/500 connections in use)',
        priority: 5,
        tags: const ['critical', 'database'],
        incidentId: incidentId,
      ),
      Message(
        id: 'm_alarm_2',
        topic: 'prod-db',
        time:
            now.subtract(const Duration(seconds: 104)).millisecondsSinceEpoch ~/
            1000,
        title: 'Primary database down',
        message: 'Repeat alarm: database still unresponsive',
        priority: 5,
        tags: const ['critical', 'database'],
        incidentId: incidentId,
      ),
      Message(
        id: 'm_alarm_3',
        topic: 'prod-db',
        time:
            now.subtract(const Duration(seconds: 74)).millisecondsSinceEpoch ~/
            1000,
        title: 'Primary database down',
        message: 'Repeat alarm: database still unresponsive',
        priority: 5,
        tags: const ['critical', 'database'],
        incidentId: incidentId,
      ),
      Message(
        id: 'm_alarm_4',
        topic: 'prod-db',
        time:
            now.subtract(const Duration(seconds: 44)).millisecondsSinceEpoch ~/
            1000,
        title: 'Primary database down',
        message: 'Repeat alarm: database still unresponsive',
        priority: 5,
        tags: const ['critical', 'database'],
        incidentId: incidentId,
      ),
      Message(
        id: 'm_alarm_5',
        topic: 'prod-db',
        time: lastMessageAt.millisecondsSinceEpoch ~/ 1000,
        title: 'Primary database down',
        message: 'Repeat alarm: database still unresponsive',
        priority: 5,
        tags: const ['critical', 'database'],
        incidentId: incidentId,
      ),
    ];

    final incident = Incident(
      id: incidentId,
      topic: 'prod-db',
      openedAt: openedAt,
      lastMessageAt: lastMessageAt,
      messages: messages,
    );

    _incidents[incidentId] = incident;
    _messages['prod-db'] = List<Message>.from(messages);
  }

  /// Acked fixture: Incident acknowledged by Z at 03:14, quiet hours active.
  void seedAcked() {
    reset();
    final today = DateTime.now().toUtc();
    final ackedTime = DateTime.utc(
      today.year,
      today.month,
      today.day,
      3,
      14,
    );
    final openedTime = ackedTime.subtract(const Duration(minutes: 4));
    final deskTimerFiresAt = ackedTime.add(const Duration(minutes: 10));

    final prodDb = Topic(
      name: 'prod-db',
      critical: true,
      createdAt: openedTime.subtract(const Duration(days: 30)),
    );
    final nasBackup = Topic(
      name: 'nas-backup',
      createdAt: openedTime.subtract(const Duration(days: 10)),
    );

    _topics[prodDb.name] = prodDb;
    _topics[nasBackup.name] = nasBackup;
    _tokens[prodDb.name] = {'tk_acked_prod'};
    _tokens[nasBackup.name] = {'tk_acked_nas'};

    const incidentId = 'inc_acked_proddb';
    final ackedMsg = Message(
      id: 'm_acked_1',
      topic: 'prod-db',
      time: openedTime.millisecondsSinceEpoch ~/ 1000,
      title: 'Primary database down',
      message: 'Connection pool exhausted',
      priority: 5,
      tags: const ['critical'],
      incidentId: incidentId,
    );

    final incident = Incident(
      id: incidentId,
      topic: 'prod-db',
      state: IncidentStates.acked,
      openedAt: openedTime,
      ackedAt: ackedTime,
      deskTimerFiresAt: deskTimerFiresAt,
      lastMessageAt: openedTime,
      messages: [ackedMsg],
    );

    _incidents[incidentId] = incident;
    _messages['prod-db'] = [ackedMsg];
  }

  /// Seed custom state.
  void seedState({
    List<Topic>? topics,
    List<Incident>? incidents,
    List<Message>? messages,
  }) {
    if (topics != null) {
      for (final t in topics) {
        _topics[t.name] = t;
        if (t.token != null) {
          (_tokens[t.name] ??= {}).add(t.token!);
        }
      }
    }
    if (incidents != null) {
      for (final inc in incidents) {
        _incidents[inc.id] = inc;
      }
    }
    if (messages != null) {
      for (final msg in messages) {
        (_messages[msg.topic] ??= []).add(msg);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Endpoints
  // ---------------------------------------------------------------------------

  /// GET /v1/info
  ServerInfo getInfo() => serverInfo;

  /// GET /v1/topics
  ///
  /// Per docs/api.md §3.1: stored topics return `token: null`.
  List<Topic> getTopics() {
    return _topics.values.map((t) => t.copyWith(token: null)).toList();
  }

  /// POST /v1/topics
  ///
  /// Per docs/api.md §3.1:
  /// - `critical` defaults to `false` (Apple entitlement commitment).
  /// - token is returned ONCE on creation only.
  Topic createTopic({
    required String name,
    bool critical = false,
    int repeatIntervalS = 30,
    int maxRingS = 1800,
    int deskTimerS = 600,
    String relayContent = 'none',
  }) {
    if (!_topicRegex.hasMatch(name)) {
      throw const ApiException(
        statusCode: 400,
        message: 'invalid topic name',
        code: 40001,
      );
    }

    final token = _nextId('tk');
    final topic = Topic(
      name: name,
      critical: critical,
      repeatIntervalS: repeatIntervalS,
      maxRingS: maxRingS,
      deskTimerS: deskTimerS,
      relayContent: relayContent,
      createdAt: DateTime.now().toUtc(),
      token: token,
    );

    _topics[name] = topic.copyWith(token: null);
    (_tokens[name] ??= {}).add(token);

    return topic;
  }

  /// PATCH /v1/topics/{name}
  Topic updateTopic(
    String name, {
    bool? critical,
    int? repeatIntervalS,
    int? maxRingS,
    int? deskTimerS,
  }) {
    final existing = _topics[name];
    if (existing == null) {
      throw const ApiException(
        statusCode: 404,
        message: 'topic not found',
      );
    }

    final updated = existing.copyWith(
      critical: critical ?? existing.critical,
      repeatIntervalS: repeatIntervalS ?? existing.repeatIntervalS,
      maxRingS: maxRingS ?? existing.maxRingS,
      deskTimerS: deskTimerS ?? existing.deskTimerS,
      token: null,
    );

    _topics[name] = updated;
    return updated;
  }

  /// DELETE /v1/topics/{name}
  void deleteTopic(String name) {
    if (!_topics.containsKey(name)) {
      throw const ApiException(
        statusCode: 404,
        message: 'topic not found',
      );
    }
    _topics.remove(name);
    _tokens.remove(name);
    _messages.remove(name);
  }

  /// POST /v1/topics/{name}/tokens
  String createTopicToken(String name) {
    if (!_topics.containsKey(name)) {
      throw const ApiException(
        statusCode: 404,
        message: 'topic not found',
      );
    }
    final token = _nextId('tk');
    (_tokens[name] ??= {}).add(token);
    return token;
  }

  /// DELETE /v1/topics/{name}/tokens/{token_id}
  void deleteTopicToken(String name, String tokenId) {
    if (!_topics.containsKey(name)) {
      throw const ApiException(
        statusCode: 404,
        message: 'topic not found',
      );
    }
    _tokens[name]?.remove(tokenId);
  }

  /// GET /v1/incidents
  List<Incident> getIncidents({
    int? limit,
    String? state,
    String? topic,
  }) {
    var items = _incidents.values.toList();

    if (state != null && state.isNotEmpty) {
      items = items
          .where(
            (inc) => inc.state.toLowerCase() == state.toLowerCase(),
          )
          .toList();
    }

    if (topic != null && topic.isNotEmpty) {
      items = items.where((inc) => inc.topic == topic).toList();
    }

    items.sort((a, b) {
      final aTime = a.openedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.openedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    if (limit != null && limit > 0 && items.length > limit) {
      items = items.sublist(0, limit);
    }

    return items;
  }

  /// GET /v1/incidents/{id}
  Incident getIncident(String id) {
    if (failIncidentFetch) {
      throw const ApiException(
        statusCode: 503,
        message: 'incident fetch unavailable',
      );
    }
    final incident = _incidents[id];
    if (incident == null) {
      throw const ApiException(
        statusCode: 404,
        message: 'incident not found',
      );
    }
    return incident;
  }

  /// POST /v1/incidents/{id}/ack
  ///
  /// Transitions open -> acked. Returns 409 if state is not open.
  Incident ackIncident(String id) {
    final incident = _incidents[id];
    if (incident == null) {
      throw const ApiException(
        statusCode: 404,
        message: 'incident not found',
      );
    }

    if (incident.state != IncidentStates.open) {
      throw const ApiException(
        statusCode: 409,
        message: 'incident is not open',
      );
    }

    final now = DateTime.now().toUtc();
    final topic = _topics[incident.topic];
    final deskTimerS = topic?.deskTimerS ?? 600;
    final deskTimerFiresAt = now.add(Duration(seconds: deskTimerS));

    final updated = incident.copyWith(
      state: IncidentStates.acked,
      ackedAt: now,
      deskTimerFiresAt: deskTimerFiresAt,
    );

    _incidents[id] = updated;
    return updated;
  }

  /// POST /v1/incidents/{id}/close
  ///
  /// Transitions acked -> closed. Returns 409 if state is not acked.
  Incident closeIncident(String id) {
    final incident = _incidents[id];
    if (incident == null) {
      throw const ApiException(
        statusCode: 404,
        message: 'incident not found',
      );
    }

    if (incident.state != IncidentStates.acked) {
      throw const ApiException(
        statusCode: 409,
        message: 'incident is not acked',
      );
    }

    final now = DateTime.now().toUtc();
    final updated = incident.copyWith(
      state: IncidentStates.closed,
      closedAt: now,
    );

    _incidents[id] = updated;
    return updated;
  }

  /// POST /v1/test?topic={name}
  ///
  /// Publishes a priority-5 message to the topic. Requires the topic to be
  /// `critical: true`; otherwise returns 409.
  String triggerTest({required String topic}) {
    final t = _topics[topic];
    if (t == null) {
      throw const ApiException(
        statusCode: 404,
        message: 'topic not found',
      );
    }

    if (!t.critical) {
      throw const ApiException(
        statusCode: 409,
        message: 'topic is not critical',
      );
    }

    final msg = publishMessage(
      topic,
      title: 'Crit Alarm test',
      message: 'Crit Alarm test alarm',
      priority: 5,
    );

    return msg.incidentId ?? '';
  }

  /// POST /{topic}
  ///
  /// Publishes a message. If priority is 5 and topic.critical is true, opens or
  /// joins an incident (flapping guard).
  Message publishMessage(
    String topic, {
    String? message,
    String? title,
    int priority = 3,
    List<String>? tags,
    String? click,
    bool? markdown,
  }) {
    if (!_topicRegex.hasMatch(topic)) {
      throw const ApiException(
        statusCode: 400,
        message: 'invalid topic name',
        code: 40001,
      );
    }

    // Ensure topic exists
    final existingTopic =
        _topics[topic] ??
        Topic(
          name: topic,
          createdAt: DateTime.now().toUtc(),
        );
    _topics[topic] = existingTopic;

    final now = DateTime.now().toUtc();
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
    final msgId = _nextId('m');
    String? incidentId;

    if (priority == 5 && existingTopic.critical) {
      // Check for an existing open or acked incident (flapping guard)
      Incident? activeIncident;
      for (final inc in _incidents.values) {
        if (inc.topic == topic &&
            (inc.state == IncidentStates.open ||
                inc.state == IncidentStates.acked)) {
          activeIncident = inc;
          break;
        }
      }

      if (activeIncident != null) {
        // Join active incident
        incidentId = activeIncident.id;
        final newMsg = Message(
          id: msgId,
          topic: topic,
          time: nowSeconds,
          title: title ?? topic,
          message: message ?? 'triggered',
          priority: priority,
          tags: tags ?? const [],
          click: click,
          markdown: markdown ?? false,
          incidentId: incidentId,
        );

        final updatedIncident = activeIncident.copyWith(
          lastMessageAt: now,
          messages: [...activeIncident.messages, newMsg],
        );
        _incidents[incidentId] = updatedIncident;
      } else {
        // Open new incident
        incidentId = _nextId('inc');
        final newMsg = Message(
          id: msgId,
          topic: topic,
          time: nowSeconds,
          title: title ?? topic,
          message: message ?? 'triggered',
          priority: priority,
          tags: tags ?? const [],
          click: click,
          markdown: markdown ?? false,
          incidentId: incidentId,
        );

        final newIncident = Incident(
          id: incidentId,
          topic: topic,
          openedAt: now,
          lastMessageAt: now,
          messages: [newMsg],
        );
        _incidents[incidentId] = newIncident;
      }
    }

    final published = Message(
      id: msgId,
      topic: topic,
      time: nowSeconds,
      title: title ?? topic,
      message: message ?? 'triggered',
      priority: priority,
      tags: tags ?? const [],
      click: click,
      markdown: markdown ?? false,
      incidentId: incidentId,
    );

    (_messages[topic] ??= []).add(published);
    return published;
  }

  /// GET /{topic}/json?poll=1
  List<Message> pollMessages(
    String topic, {
    required int poll,
    String? since,
  }) {
    if (poll != 1) {
      throw const ApiException(
        statusCode: 501,
        message: 'streaming not supported in v1',
      );
    }

    var items = _messages[topic] ?? const <Message>[];

    if (since != null && since.isNotEmpty && since != 'all') {
      final sinceTs = int.tryParse(since);
      if (sinceTs != null) {
        items = items.where((m) => m.time >= sinceTs).toList();
      } else {
        // Message ID lookup. Everything after that id, which is nothing at
        // all when the caller already has the newest message.
        final idx = items.indexWhere((m) => m.id == since);
        if (idx != -1) items = items.sublist(idx + 1);
      }
    }

    return items;
  }

  /// POST /relay/v1/devices
  DeviceRegistrationResponse registerDevice(DeviceRegistration registration) {
    final accountId = _nextId('acc');
    final deviceToken = _nextId('dv');
    const caps = AccountCaps();

    final response = DeviceRegistrationResponse(
      deviceToken: deviceToken,
      accountId: accountId,
      caps: caps,
    );

    _devices[registration.deviceId] = response;
    return response;
  }

  // ---------------------------------------------------------------------------
  // HTTP Request Handler & MockClient
  // ---------------------------------------------------------------------------

  /// An [http.Client] that routes directly to this mock server.
  http.Client get httpClient => MockClient(handleHttpRequest);

  /// Handles incoming [http.BaseRequest] and maps to endpoints.
  Future<http.Response> handleHttpRequest(http.BaseRequest request) async {
    try {
      final path = request.url.path;
      final method = request.method.toUpperCase();
      final query = request.url.queryParameters;

      var bodyString = '';
      if (request is http.Request) {
        bodyString = request.body;
      }

      // 1. GET /v1/info
      if (method == 'GET' && path == '/v1/info') {
        return _jsonResponse(getInfo().toJson(), 200);
      }

      // 2. /v1/topics
      if (path == '/v1/topics') {
        if (method == 'GET') {
          final topics = getTopics();
          return _jsonResponse(topics.map((t) => t.toJson()).toList(), 200);
        } else if (method == 'POST') {
          final body = bodyString.isNotEmpty
              ? jsonDecode(bodyString) as Map<String, dynamic>
              : <String, dynamic>{};
          final name = body['name'] as String? ?? '';
          final critical = body['critical'] as bool? ?? false;
          final repeatIntervalS = body['repeat_interval_s'] as int? ?? 30;
          final maxRingS = body['max_ring_s'] as int? ?? 1800;
          final deskTimerS = body['desk_timer_s'] as int? ?? 600;
          final relayContent = body['relay_content'] as String? ?? 'none';

          final topic = createTopic(
            name: name,
            critical: critical,
            repeatIntervalS: repeatIntervalS,
            maxRingS: maxRingS,
            deskTimerS: deskTimerS,
            relayContent: relayContent,
          );
          return _jsonResponse(topic.toJson(), 201);
        }
      }

      // 3. /v1/topics/{name}/tokens
      final tokensMatch = RegExp(
        r'^/v1/topics/([^/]+)/tokens$',
      ).firstMatch(path);
      if (tokensMatch != null) {
        final topicName = Uri.decodeComponent(tokensMatch[1]!);
        if (method == 'POST') {
          final token = createTopicToken(topicName);
          return _jsonResponse({'token': token}, 201);
        }
      }

      // 4. /v1/topics/{name}/tokens/{token_id}
      final deleteTokenMatch = RegExp(
        r'^/v1/topics/([^/]+)/tokens/([^/]+)$',
      ).firstMatch(path);
      if (deleteTokenMatch != null && method == 'DELETE') {
        final topicName = Uri.decodeComponent(deleteTokenMatch[1]!);
        final tokenId = Uri.decodeComponent(deleteTokenMatch[2]!);
        deleteTopicToken(topicName, tokenId);
        return http.Response('', 204);
      }

      // 5. /v1/topics/{name}
      final topicDetailMatch = RegExp(r'^/v1/topics/([^/]+)$').firstMatch(path);
      if (topicDetailMatch != null) {
        final topicName = Uri.decodeComponent(topicDetailMatch[1]!);
        if (method == 'PATCH') {
          final body = bodyString.isNotEmpty
              ? jsonDecode(bodyString) as Map<String, dynamic>
              : <String, dynamic>{};
          final updated = updateTopic(
            topicName,
            critical: body['critical'] as bool?,
            repeatIntervalS: body['repeat_interval_s'] as int?,
            maxRingS: body['max_ring_s'] as int?,
            deskTimerS: body['desk_timer_s'] as int?,
          );
          return _jsonResponse(updated.toJson(), 200);
        } else if (method == 'DELETE') {
          deleteTopic(topicName);
          return http.Response('', 204);
        }
      }

      // 6. /v1/incidents
      if (path == '/v1/incidents' && method == 'GET') {
        final limit = int.tryParse(query['limit'] ?? '');
        final state = query['state'];
        final topic = query['topic'];
        final incidents = getIncidents(
          limit: limit,
          state: state,
          topic: topic,
        );
        return _jsonResponse(incidents.map((i) => i.toJson()).toList(), 200);
      }

      // 7. /v1/incidents/{id}/ack
      final ackMatch = RegExp(r'^/v1/incidents/([^/]+)/ack$').firstMatch(path);
      if (ackMatch != null && method == 'POST') {
        final id = Uri.decodeComponent(ackMatch[1]!);
        final incident = ackIncident(id);
        return _jsonResponse(incident.toJson(), 200);
      }

      // 8. /v1/incidents/{id}/close
      final closeMatch = RegExp(
        r'^/v1/incidents/([^/]+)/close$',
      ).firstMatch(path);
      if (closeMatch != null && method == 'POST') {
        final id = Uri.decodeComponent(closeMatch[1]!);
        final incident = closeIncident(id);
        return _jsonResponse(incident.toJson(), 200);
      }

      // 9. /v1/incidents/{id}
      final incidentDetailMatch = RegExp(
        r'^/v1/incidents/([^/]+)$',
      ).firstMatch(path);
      if (incidentDetailMatch != null && method == 'GET') {
        final id = Uri.decodeComponent(incidentDetailMatch[1]!);
        final incident = getIncident(id);
        return _jsonResponse(incident.toJson(), 200);
      }

      // 10. /v1/test?topic={name}
      if (path == '/v1/test' && method == 'POST') {
        final topic = query['topic'] ?? '';
        final incidentId = triggerTest(topic: topic);
        return _jsonResponse({'incident_id': incidentId}, 200);
      }

      // 11. /relay/v1/devices
      if (path == '/relay/v1/devices' && method == 'POST') {
        final body = bodyString.isNotEmpty
            ? jsonDecode(bodyString) as Map<String, dynamic>
            : <String, dynamic>{};
        final registration = DeviceRegistration.fromJson(body);
        final response = registerDevice(registration);
        return _jsonResponse(response.toJson(), 201);
      }

      // 12. GET /{topic}/json?poll=1
      final pollMatch = RegExp(r'^/([^/]+)/json$').firstMatch(path);
      if (pollMatch != null && method == 'GET') {
        final topic = Uri.decodeComponent(pollMatch[1]!);
        final poll = int.tryParse(query['poll'] ?? '') ?? 0;
        final since = query['since'];
        final messages = pollMessages(topic, poll: poll, since: since);
        final ndjson = messages.map((m) => jsonEncode(m.toJson())).join('\n');
        return http.Response(
          ndjson.isEmpty ? '' : '$ndjson\n',
          200,
          headers: {'content-type': 'application/x-ndjson'},
        );
      }

      // 13. POST /{topic} or PUT /{topic}
      final publishMatch = RegExp(r'^/([^/]+)$').firstMatch(path);
      if (publishMatch != null && (method == 'POST' || method == 'PUT')) {
        final topic = Uri.decodeComponent(publishMatch[1]!);

        // Check for delay headers -> 400
        for (final header in [
          'x-delay',
          'delay',
          'x-at',
          'at',
          'x-in',
          'in',
        ]) {
          if (request.headers.containsKey(header)) {
            return _jsonResponse(
              {'error': 'scheduled delivery not supported'},
              400,
            );
          }
        }

        String? title;
        String? message;
        var priority = 3;
        var tags = <String>[];
        String? click;
        var markdown = false;

        // Header extraction with aliases
        for (final entry in request.headers.entries) {
          final k = entry.key.toLowerCase();
          final v = entry.value;
          if (['x-title', 'title', 'ti', 't'].contains(k)) {
            title = v;
          } else if (['x-priority', 'priority', 'prio', 'p'].contains(k)) {
            priority = _parsePriority(v);
          } else if (['x-tags', 'tags', 'tag', 'ta'].contains(k)) {
            tags = v.split(',').map((s) => s.trim()).toList();
          } else if (['x-click', 'click'].contains(k)) {
            click = v;
          } else if (['x-markdown', 'markdown', 'md'].contains(k)) {
            markdown = ['true', '1', 'yes'].contains(v.toLowerCase());
          }
        }

        // Query param overrides
        if (query.containsKey('t')) title = query['t'];
        if (query.containsKey('p')) priority = _parsePriority(query['p']);
        if (query.containsKey('ta')) {
          tags = query['ta']!.split(',').map((s) => s.trim()).toList();
        }
        if (query.containsKey('m')) message = query['m'];

        // JSON body check
        final contentType = request.headers['content-type'] ?? '';
        if (contentType.contains('application/json') && bodyString.isNotEmpty) {
          try {
            final jsonBody = jsonDecode(bodyString) as Map<String, dynamic>;
            if (jsonBody.containsKey('message')) {
              message = jsonBody['message'] as String?;
            }
            if (jsonBody.containsKey('title')) {
              title = jsonBody['title'] as String?;
            }
            if (jsonBody.containsKey('priority')) {
              priority = _parsePriority(jsonBody['priority']);
            }
            if (jsonBody.containsKey('tags')) {
              tags = (jsonBody['tags'] as List<dynamic>)
                  .map((e) => e.toString())
                  .toList();
            }
            if (jsonBody.containsKey('click')) {
              click = jsonBody['click'] as String?;
            }
            if (jsonBody.containsKey('markdown')) {
              markdown = jsonBody['markdown'] as bool? ?? false;
            }
          } on FormatException catch (_) {}
        } else if (message == null && bodyString.isNotEmpty) {
          message = bodyString;
        }

        final published = publishMessage(
          topic,
          message: message,
          title: title,
          priority: priority,
          tags: tags,
          click: click,
          markdown: markdown,
        );

        return _jsonResponse(published.toJson(), 200);
      }

      return _jsonResponse({'error': 'not found'}, 404);
    } on ApiException catch (e) {
      final body = <String, dynamic>{
        'error': e.message,
        'http': e.statusCode,
      };
      if (e.code != null) body['code'] = e.code;
      return _jsonResponse(body, e.statusCode);
    } on Exception catch (e) {
      return _jsonResponse({'error': e.toString()}, 500);
    }
  }

  static int _parsePriority(dynamic value) {
    if (value is int) return value.clamp(1, 5);
    final s = value.toString().toLowerCase().trim();
    return switch (s) {
      '1' || 'min' => 1,
      '2' || 'low' => 2,
      '3' || 'default' => 3,
      '4' || 'high' => 4,
      '5' || 'urgent' || 'max' => 5,
      _ => int.tryParse(s)?.clamp(1, 5) ?? 3,
    };
  }

  static http.Response _jsonResponse(dynamic body, int statusCode) {
    return http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
}
