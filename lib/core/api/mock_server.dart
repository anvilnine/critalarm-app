import 'dart:convert';

import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/models/send_result.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/models/topic_token.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// One token this fake server holds: the name it shows and when it was made.
typedef _HeldToken = ({String name, DateTime createdAt});

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

  /// Token id to its name and when it was made. The value is never kept: the
  /// real server holds a hash of it, so neither can this.
  final Map<String, Map<String, _HeldToken>> _tokens = {};
  final Map<String, Set<String>> subscriptions = {};
  final Map<String, Map<String, Map<String, String>>> pushTokens = {};
  final Map<String, Incident> _incidents = {};
  final Map<String, List<Message>> _messages = {};
  final Map<String, DeviceRegistrationResponse> _devices = {};

  /// Identity tokens the auth surface has handed out, and the account each one
  /// already belongs to. A token that is not in here has never signed in, so
  /// linking it claims whatever account the handset brings.
  final Map<String, String> identityAccounts = {};

  /// Accounts that already hold an identity, and every identity on each one.
  /// Since 1.14.0 an account may hold more than one, so the same person can
  /// use Apple on an iPhone and Google on an Android phone (api.md §3.7). A
  /// second, different identity arriving with intent `sign_in` is still the
  /// shared-handset refusal.
  final Map<String, Set<String>> accountIdentities = {};

  /// Accounts left behind by a merge or a switch.
  final Set<String> tombstonedAccounts = {};

  /// Every live `aj_`, and the account it attaches a device to. One is minted
  /// per account on the call that created it (api.md §4.2), and
  /// `POST /v1/account/join-token` replaces it with a fresh one (api.md §3.7).
  final Map<String, String> accountJoinTokens = {};

  int _counter = 1000;

  /// Makes `GET /v1/incidents/{id}` answer 503, so the app's fallback path can
  /// be exercised. api.md §5.1 and §5.2 leave the title and body out under
  /// `relay_content: none`, and this is what a failed fetch of them looks like.
  bool failIncidentFetch = false;

  static final RegExp _topicRegex = RegExp(r'^[-_A-Za-z0-9]{1,64}$');

  String _nextId(String prefix) => '${prefix}_${++_counter}';

  /// When every seeded token was made. Fixed so a test can name it.
  static final DateTime _seedTime = DateTime.utc(2026, 9);

  /// Reset all stored state to empty.
  void reset() {
    _topics.clear();
    _tokens.clear();
    _incidents.clear();
    _messages.clear();
    _devices.clear();
    identityAccounts.clear();
    accountIdentities.clear();
    tombstonedAccounts.clear();
    accountJoinTokens.clear();
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
      // Refresh and expression faces only show during gestures or previews.
      // There is no dedicated server fixture for them.
      case FaceState.working:
      case FaceState.success:
      case FaceState.shocked:
      case FaceState.laughing:
      case FaceState.surprised:
      case FaceState.skeptical:
      case FaceState.dizzy:
      case FaceState.determined:
      case FaceState.confused:
      case FaceState.sad:
      case FaceState.blink:
      case FaceState.happy:
      case FaceState.content:
      case FaceState.curious:
      case FaceState.lookLeft:
      case FaceState.lookRight:
      case FaceState.thinking:
      case FaceState.interested:
      case FaceState.concerned:
      case FaceState.realization:
      case FaceState.yawn:
      case FaceState.sleepy:
      case FaceState.dozing:
      case FaceState.wakesUp:
      case FaceState.shakeHead:
      case FaceState.breatheIn:
      case FaceState.breatheOut:
      case FaceState.proud:
      case FaceState.cheeky:
      case FaceState.confident:
      case FaceState.love:
        seedCalm();
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

    _tokens[prodDb.name] = {
      'tok_calm_proddb': (name: 'Token 1', createdAt: _seedTime),
    };
    _tokens[nasBackup.name] = {
      'tok_calm_nasbackup': (name: 'Token 1', createdAt: _seedTime),
    };
    _tokens[uptimeKuma.name] = {
      'tok_calm_uptimekuma': (name: 'Token 1', createdAt: _seedTime),
    };
    _tokens[homeHa.name] = {
      'tok_calm_homeha': (name: 'Token 1', createdAt: _seedTime),
    };

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
    _tokens[nasBackup.name] = {
      'tok_worried_nas': (name: 'Token 1', createdAt: _seedTime),
    };
    _tokens[prodDb.name] = {
      'tok_worried_prod': (name: 'Token 1', createdAt: _seedTime),
    };

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

    _tokens[prodDb.name] = {
      'tok_alarmed_proddb': (name: 'Token 1', createdAt: _seedTime),
    };
    _tokens[nasBackup.name] = {
      'tok_alarmed_nas': (name: 'Token 1', createdAt: _seedTime),
    };
    _tokens[uptimeKuma.name] = {
      'tok_alarmed_kuma': (name: 'Token 1', createdAt: _seedTime),
    };

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
    _tokens[prodDb.name] = {
      'tok_acked_prod': (name: 'Token 1', createdAt: _seedTime),
    };
    _tokens[nasBackup.name] = {
      'tok_acked_nas': (name: 'Token 1', createdAt: _seedTime),
    };

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
          (_tokens[t.name] ??= {})[t.tokenId ?? t.token!] = (
            name: t.tokenName ?? 'Token 1',
            createdAt: _seedTime,
          );
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
    String? tokenName,
  }) {
    if (!_topicRegex.hasMatch(name)) {
      throw const ApiException(
        statusCode: 400,
        message: 'invalid topic name',
        code: 40001,
      );
    }

    if (_topics.containsKey(name)) {
      throw const ApiException(
        statusCode: 409,
        code: 40901,
        message: 'topic already exists',
      );
    }
    final token = _nextId('tk');
    final tokenId = _nextId('tok');
    final heldName = _defaultedTokenName(name, tokenName);
    final topic = Topic(
      name: name,
      critical: critical,
      repeatIntervalS: repeatIntervalS,
      maxRingS: maxRingS,
      deskTimerS: deskTimerS,
      relayContent: relayContent,
      createdAt: DateTime.now().toUtc(),
      token: token,
      tokenId: tokenId,
      tokenName: heldName,
    );

    _topics[name] = topic.copyWith(
      token: null,
      tokenId: null,
      tokenName: null,
    );
    (_tokens[name] ??= {})[tokenId] = (
      name: heldName,
      createdAt: DateTime.now().toUtc(),
    );

    return topic;
  }

  /// The name a token ends up with, the way the real server works it out.
  ///
  /// api.md §3.1: trim it, cut it to 40 characters, and when nothing is left
  /// call it `Token N`, where N is the topic's current token count plus one.
  /// The cut can land on a space, so trim once more after it: a 41-character
  /// name whose 40th character is a space must not be stored with a trailing
  /// space.
  String _defaultedTokenName(String topicName, String? wanted) {
    final trimmed = (wanted ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Token ${(_tokens[topicName]?.length ?? 0) + 1}';
    }
    return trimmed.length > 40 ? trimmed.substring(0, 40).trim() : trimmed;
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

  /// GET /v1/topics/{name}/tokens
  ///
  /// Ids, names and dates, oldest first. No value, the same as the real
  /// server, which only ever stored a hash of it.
  List<TopicTokenInfo> getTopicTokens(String name) {
    if (!_topics.containsKey(name)) {
      throw const ApiException(statusCode: 404, message: 'topic not found');
    }
    final held = _tokens[name] ?? const <String, _HeldToken>{};
    return [
      for (final entry in held.entries)
        TopicTokenInfo(
          tokenId: entry.key,
          name: entry.value.name,
          createdAt: entry.value.createdAt,
        ),
    ]..sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
  }

  /// POST /v1/topics/{name}/tokens
  TopicToken createTopicToken(String name, {String? tokenName}) {
    if (!_topics.containsKey(name)) {
      throw const ApiException(
        statusCode: 404,
        message: 'topic not found',
      );
    }
    final token = TopicToken(
      token: _nextId('tk'),
      tokenId: _nextId('tok'),
      name: _defaultedTokenName(name, tokenName),
    );
    (_tokens[name] ??= {})[token.tokenId] = (
      name: token.name,
      createdAt: DateTime.now().toUtc(),
    );
    return token;
  }

  /// PATCH /v1/topics/{name}/tokens/{token_id}
  ///
  /// The name is required here. Unlike creation, a blank one does not fall
  /// back to `Token N`: api.md §3.1 says `name` on the PATCH may not be left
  /// off, so a name that is empty after trimming is a bad request.
  TopicTokenInfo renameTopicToken(
    String name,
    String tokenId,
    String tokenName,
  ) {
    // The real router reads the body before it looks anything up, so a blank
    // name answers 400 even when the token does not exist.
    if (tokenName.trim().isEmpty) {
      throw const ApiException(statusCode: 400, message: 'invalid request');
    }
    if (!_topics.containsKey(name) ||
        !(_tokens[name] ?? const {}).containsKey(tokenId)) {
      throw const ApiException(statusCode: 404, message: 'not found');
    }
    final held = _tokens[name]![tokenId]!;
    final renamed = (
      name: _defaultedTokenName(name, tokenName),
      createdAt: held.createdAt,
    );
    _tokens[name]![tokenId] = renamed;
    return TopicTokenInfo(
      tokenId: tokenId,
      name: renamed.name,
      createdAt: renamed.createdAt,
    );
  }

  /// DELETE /v1/topics/{name}/tokens/{token_id}
  void deleteTopicToken(String name, String tokenId) {
    if (!_topics.containsKey(name)) {
      throw const ApiException(
        statusCode: 404,
        message: 'topic not found',
      );
    }
    if (!_tokens[name]!.containsKey(tokenId)) {
      throw const ApiException(statusCode: 404, message: 'not found');
    }
    if (_tokens[name]!.length == 1) {
      throw const ApiException(
        statusCode: 409,
        message: 'topic must retain a token',
      );
    }
    _tokens[name]!.remove(tokenId);
  }

  /// GET /v1/incidents
  ///
  /// `limit` behaves the way api.md §3.2 says the real server behaves: absent
  /// means [defaultIncidentLimit], above [maxIncidentLimit] is cut down to it,
  /// and below 1 is a 400. A fake that answered "everything" for an absent
  /// limit would hide the bug this models.
  List<Incident> getIncidents({
    int? limit,
    String? state,
    String? topic,
    DateTime? since,
  }) {
    if (limit != null && limit < 1) {
      throw const ApiException(statusCode: 400, message: 'invalid request');
    }
    final take = limit == null
        ? defaultIncidentLimit
        : (limit > maxIncidentLimit ? maxIncidentLimit : limit);
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

    // api.md §3.2: `since` is exclusive, on `opened_at`.
    if (since != null) {
      items = items
          .where((inc) => (inc.openedAt?.isAfter(since) ?? false))
          .toList();
    }

    items.sort((a, b) {
      final aTime = a.openedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.openedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    if (items.length > take) items = items.sublist(0, take);

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

    if (since != 'all') {
      final timestamp = int.tryParse(since ?? '');
      final duration = RegExp(r'^(\d+)(s|m|h|d)$').firstMatch(since ?? '');
      if (timestamp != null) {
        items = items.where((m) => m.time > timestamp).toList();
      } else if (since == null || duration != null) {
        final seconds = duration == null
            ? 12 * 3600
            : int.parse(duration[1]!) *
                  switch (duration[2]) {
                    's' => 1,
                    'm' => 60,
                    'h' => 3600,
                    _ => 86400,
                  };
        final cutoff =
            DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 - seconds;
        items = items.where((m) => m.time >= cutoff).toList();
      } else {
        final idx = items.indexWhere((m) => m.id == since);
        items = idx == -1 ? [] : items.sublist(idx + 1);
      }
    }

    return items;
  }

  /// POST /relay/v1/devices
  ///
  /// With an [accountJoinToken] the device attaches to the account that token
  /// belongs to and no new join token is handed back. Without one the call
  /// creates an account and mints its join token (api.md §4.2).
  DeviceRegistrationResponse registerDevice(
    DeviceRegistration registration, {
    String? deviceToken,
    String? accountJoinToken,
  }) {
    deviceToken ??= _nextId('dv');
    const caps = AccountCaps.free;
    final String accountId;
    String? joinToken;
    if (accountJoinToken != null) {
      final joined = accountJoinTokens[accountJoinToken];
      if (joined == null) {
        throw const ApiException(statusCode: 401, message: 'unauthorized');
      }
      accountId = joined;
    } else {
      accountId = _nextId('acc');
      joinToken = _nextId('aj');
      accountJoinTokens[joinToken] = accountId;
    }

    final response = DeviceRegistrationResponse(
      deviceToken: deviceToken,
      accountId: accountId,
      accountJoinToken: joinToken,
      caps: caps,
    );

    _devices[registration.deviceId] = response;
    return response;
  }

  DeviceRegistrationResponse _authorizedDevice(String id, String token) {
    final device = _devices[id];
    if (device == null || device.deviceToken != token) {
      throw const ApiException(statusCode: 401, message: 'unauthorized');
    }
    return device;
  }

  /// PATCH /relay/v1/devices/{device_id}. Neither secret comes back: the
  /// caller already holds both (api.md §4.2).
  DeviceRegistrationResponse refreshDevice(String id, String token) =>
      _authorizedDevice(
        id,
        token,
      ).copyWith(deviceToken: null, accountJoinToken: null);

  void subscribeTopic({
    required String deviceId,
    required String deviceToken,
    required String topicHash,
  }) {
    final device = _authorizedDevice(deviceId, deviceToken);
    final hashes = subscriptions[deviceId] ??= {};
    final limit = device.caps.criticalTopics;
    if (!hashes.contains(topicHash) &&
        limit != null &&
        hashes.length >= limit) {
      throw const ApiException(
        statusCode: 429,
        message: 'cap',
        cap: 'critical_topics',
      );
    }
    hashes.add(topicHash);
  }

  void unsubscribeTopic({
    required String deviceId,
    required String deviceToken,
    required String topicHash,
  }) {
    _authorizedDevice(deviceId, deviceToken);
    subscriptions[deviceId]?.remove(topicHash);
  }

  void uploadActivityToken({
    required String deviceId,
    required String deviceToken,
    required String kind,
    required String token,
    String? activityId,
    String? incidentId,
  }) {
    _authorizedDevice(deviceId, deviceToken);
    if (!['apns', 'fcm', 'la_start', 'la_update'].contains(kind) ||
        (kind == 'la_update'
            ? activityId == null || activityId.isEmpty
            : activityId != null || incidentId != null)) {
      throw const ApiException(statusCode: 400, message: 'invalid request');
    }
    (pushTokens[deviceId] ??= {})['$kind:${activityId ?? ''}'] = {
      'kind': kind,
      'token': token,
      'activity_id': ?activityId,
      'incident_id': ?incidentId,
    };
  }

  // ---------------------------------------------------------------------------
  // Accounts and sign-in (api.md §3.7)
  // ---------------------------------------------------------------------------

  /// The account a device token speaks for, or 401 when no device holds it.
  String _accountForDeviceToken(String deviceToken) {
    for (final device in _devices.values) {
      if (device.deviceToken == deviceToken) return device.accountId;
    }
    throw const ApiException(statusCode: 401, message: 'unauthorized');
  }

  /// Moves whichever device holds [deviceToken] onto [accountId].
  void _pointDeviceAtAccount(String deviceToken, String accountId) {
    for (final entry in _devices.entries) {
      if (entry.value.deviceToken == deviceToken) {
        _devices[entry.key] = entry.value.copyWith(accountId: accountId);
        return;
      }
    }
  }

  /// A self-hosted server has one operator and no accounts to sign in to, so
  /// every route here refuses with 501 rather than 404. The client has to be
  /// able to tell "this server does not do sign-in" from "you typed the path
  /// wrong".
  void _requireAccountsSupported() {
    if (serverInfo.mode == ServerModes.selfhosted) {
      throw const ApiException(
        statusCode: 501,
        message: 'not supported in selfhosted mode',
      );
    }
  }

  /// The alarm that blocks a merge, if one is up. Only `open` and `acked`
  /// count: nothing else is ringing or waiting on a person.
  Incident? get _liveIncident {
    for (final incident in _incidents.values) {
      if (incident.isOpen || incident.isAcked) return incident;
    }
    return null;
  }

  /// POST /v1/account/link
  AccountLinkResult linkAccount({
    required String deviceToken,
    required String identityToken,
    AccountLinkIntent intent = AccountLinkIntent.signIn,
  }) {
    _requireAccountsSupported();
    final account = _accountForDeviceToken(deviceToken);
    final owners = accountIdentities[account] ?? const <String>{};
    final identityAccount = identityAccounts[identityToken];
    // The identity already points at this handset's own account, so there is
    // nothing left to do. Both intents answer this, which is what a retry
    // after a dropped reply looks like. Before 1.14.0 the same request
    // answered `claimed`.
    if (identityAccount == account) {
      return AccountLinkResult.alreadyLinked(accountId: account);
    }
    if (intent == AccountLinkIntent.link) {
      // Adding a second way in. The identity joins the account this handset
      // already has, unless it is spoken for somewhere else.
      if (identityAccount != null) {
        return const AccountLinkResult.identityHasAnotherAccount();
      }
      identityAccounts[identityToken] = account;
      (accountIdentities[account] ??= <String>{}).add(identityToken);
      return AccountLinkResult.linked(accountId: account);
    }
    if (owners.isNotEmpty) {
      return const AccountLinkResult.accountHasAnotherIdentity();
    }
    if (identityAccount == null) {
      identityAccounts[identityToken] = account;
      (accountIdentities[account] ??= <String>{}).add(identityToken);
      return AccountLinkResult.claimed(accountId: account);
    }
    // An empty account is one with no topics and no incidents. Registration
    // runs long before any sign-in screen, so a device with no account cannot
    // happen and this is the only "nothing to decide" case there is.
    if (_topics.isEmpty && _incidents.isEmpty) {
      tombstonedAccounts.add(account);
      _pointDeviceAtAccount(deviceToken, identityAccount);
      return AccountLinkResult.attached(accountId: identityAccount);
    }
    return AccountLinkResult.choose(
      intoAccount: identityAccount,
      topics: _topics.length,
      incidents: _incidents.length,
    );
  }

  /// POST /v1/account/merge
  AccountMergeResult mergeAccount({
    required String deviceToken,
    required String identityToken,
    required String intoAccount,
  }) {
    _requireAccountsSupported();
    final account = _accountForDeviceToken(deviceToken);
    if (!identityAccounts.containsKey(identityToken)) {
      return const AccountMergeResult.unauthorized();
    }
    if (account == intoAccount) return const AccountMergeResult.sameAccount();
    if (tombstonedAccounts.contains(account) ||
        tombstonedAccounts.contains(intoAccount)) {
      return const AccountMergeResult.alreadyMerged();
    }
    final live = _liveIncident;
    if (live != null) {
      return AccountMergeResult.liveIncident(incidentId: live.id);
    }
    tombstonedAccounts.add(account);
    _pointDeviceAtAccount(deviceToken, intoAccount);
    (accountIdentities[intoAccount] ??= <String>{}).add(identityToken);
    return AccountMergeResult.merged(
      accountId: intoAccount,
      mergedFrom: account,
    );
  }

  /// POST /v1/account/switch
  AccountSwitchResult switchAccount({
    required String deviceToken,
    required String identityToken,
    required String intoAccount,
  }) {
    _requireAccountsSupported();
    final account = _accountForDeviceToken(deviceToken);
    if (!identityAccounts.containsKey(identityToken)) {
      return const AccountSwitchResult.unauthorized();
    }
    tombstonedAccounts.add(account);
    _pointDeviceAtAccount(deviceToken, intoAccount);
    (accountIdentities[intoAccount] ??= <String>{}).add(identityToken);
    return AccountSwitchResult.switched(accountId: intoAccount);
  }

  /// The alarm that blocks a delete, if one is up.
  ///
  /// Only `open` counts here. An acked alarm is not ringing, and api.md §3.7
  /// says a person must never be stuck unable to leave, so this is narrower
  /// than [_liveIncident], which the merge route uses.
  Incident? get _openIncident {
    for (final incident in _incidents.values) {
      if (incident.isOpen) return incident;
    }
    return null;
  }

  /// DELETE /v1/account
  AccountDeleteResult deleteAccount({
    required String deviceToken,
    String? identityToken,
  }) {
    _requireAccountsSupported();
    final account = _accountForDeviceToken(deviceToken);
    final owners = accountIdentities[account] ?? const <String>{};
    // An account with no identity goes on the device token alone. One that
    // holds identities needs one of them too, so a handset left in a drawer
    // cannot wipe a signed-in account. Any one of them is enough: they all
    // belong to the same person.
    if (owners.isNotEmpty && !owners.contains(identityToken)) {
      return const AccountDeleteResult.unauthorized();
    }
    final open = _openIncident;
    if (open != null) {
      return AccountDeleteResult.liveIncident(incidentId: open.id);
    }
    _devices.removeWhere((id, device) {
      if (device.accountId != account) return false;
      subscriptions.remove(id);
      pushTokens.remove(id);
      return true;
    });
    _topics.clear();
    _tokens.clear();
    _messages.clear();
    _incidents.clear();
    tombstonedAccounts.remove(account);
    accountIdentities.remove(account);
    identityAccounts.removeWhere((_, owned) => owned == account);
    return const AccountDeleteResult.deleted();
  }

  /// POST /v1/account/join-token
  ///
  /// Mints a fresh `aj_` for the account this device belongs to and retires
  /// whichever one the account held before, so only the newest value ever
  /// works (api.md §3.7).
  AccountJoinTokenResult mintAccountJoinToken({required String deviceToken}) {
    _requireAccountsSupported();
    final String account;
    try {
      account = _accountForDeviceToken(deviceToken);
    } on ApiException {
      return const AccountJoinTokenResult.unauthorized();
    }
    accountJoinTokens.removeWhere((_, owner) => owner == account);
    final joinToken = _nextId('aj');
    accountJoinTokens[joinToken] = account;
    return AccountJoinTokenResult.minted(joinToken: joinToken);
  }

  /// DELETE /relay/v1/devices/{device_id}
  void deleteDevice({required String deviceId, required String deviceToken}) {
    _authorizedDevice(deviceId, deviceToken);
    _devices.remove(deviceId);
    subscriptions.remove(deviceId);
    pushTokens.remove(deviceId);
  }

  SendResult sendMessage(
    String topic, {
    required String message,
    String? title,
    int priority = 3,
    List<String>? tags,
  }) {
    if (!_topics.containsKey(topic)) {
      throw const ApiException(statusCode: 404, message: 'not found');
    }
    if (priority < 1 || priority > 5) {
      throw const ApiException(statusCode: 400, message: 'invalid priority');
    }
    final result = publishMessage(
      topic,
      message: message,
      title: title,
      priority: priority,
      tags: tags,
    );
    return SendResult(id: result.id, incidentId: result.incidentId);
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
            tokenName: body['token_name'] as String?,
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
          final body = bodyString.isNotEmpty
              ? jsonDecode(bodyString) as Map<String, dynamic>
              : <String, dynamic>{};
          final token = createTopicToken(
            topicName,
            tokenName: body['name'] as String?,
          );
          return _jsonResponse(token.toJson(), 201);
        }
        if (method == 'GET') {
          return _jsonResponse(
            getTopicTokens(topicName).map((t) => t.toJson()).toList(),
            200,
          );
        }
      }

      // 4. /v1/topics/{name}/tokens/{token_id}
      final oneTokenMatch = RegExp(
        r'^/v1/topics/([^/]+)/tokens/([^/]+)$',
      ).firstMatch(path);
      if (oneTokenMatch != null) {
        final topicName = Uri.decodeComponent(oneTokenMatch[1]!);
        final tokenId = Uri.decodeComponent(oneTokenMatch[2]!);
        if (method == 'DELETE') {
          deleteTopicToken(topicName, tokenId);
          return http.Response('', 204);
        }
        if (method == 'PATCH') {
          final body = bodyString.isNotEmpty
              ? jsonDecode(bodyString) as Map<String, dynamic>
              : <String, dynamic>{};
          final renamed = renameTopicToken(
            topicName,
            tokenId,
            body['name'] as String? ?? '',
          );
          return _jsonResponse(renamed.toJson(), 200);
        }
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
        final rawLimit = query['limit'];
        final limit = rawLimit == null ? null : int.tryParse(rawLimit);
        if (rawLimit != null && limit == null) {
          throw const ApiException(
            statusCode: 400,
            message: 'invalid request',
          );
        }
        final state = query['state'];
        final topic = query['topic'];
        final rawSince = query['since'];
        final sinceSeconds = rawSince == null ? null : int.tryParse(rawSince);
        if (rawSince != null && sinceSeconds == null) {
          throw const ApiException(
            statusCode: 400,
            message: 'invalid request',
          );
        }
        final incidents = getIncidents(
          limit: limit,
          state: state,
          topic: topic,
          since: sinceSeconds == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(
                  sinceSeconds * 1000,
                  isUtc: true,
                ),
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

      // 11. /v1/account
      if (path == '/v1/account' && method == 'DELETE') {
        final body = bodyString.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(bodyString) as Map<String, dynamic>;
        final credential = (request.headers['authorization'] ?? '')
            .replaceFirst('Bearer ', '');
        return _deleteAccountResponse(
          deleteAccount(
            deviceToken: credential,
            identityToken: body['identity_token'] as String?,
          ),
        );
      }

      // 12. /v1/account/join-token
      if (path == '/v1/account/join-token' && method == 'POST') {
        final credential = (request.headers['authorization'] ?? '')
            .replaceFirst('Bearer ', '');
        return _joinTokenResponse(
          mintAccountJoinToken(deviceToken: credential),
        );
      }

      // 13. /v1/account/{link,merge,switch}
      final accountMatch = RegExp(
        r'^/v1/account/(link|merge|switch)$',
      ).firstMatch(path);
      if (accountMatch != null && method == 'POST') {
        final body = bodyString.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(bodyString) as Map<String, dynamic>;
        // `dv_` stays in the header and the identity travels in the body.
        final credential = (request.headers['authorization'] ?? '')
            .replaceFirst('Bearer ', '');
        final identityToken = body['identity_token'] as String? ?? '';
        final intoAccount = body['into_account'] as String? ?? '';
        return switch (accountMatch[1]) {
          'link' => _linkResponse(
            linkAccount(
              deviceToken: credential,
              identityToken: identityToken,
              // Absent reads as "sign_in", exactly as api.md §3.7 says.
              intent: body['intent'] == AccountLinkIntent.link.wireValue
                  ? AccountLinkIntent.link
                  : AccountLinkIntent.signIn,
            ),
          ),
          'merge' => _mergeResponse(
            mergeAccount(
              deviceToken: credential,
              identityToken: identityToken,
              intoAccount: intoAccount,
            ),
          ),
          _ => _switchResponse(
            switchAccount(
              deviceToken: credential,
              identityToken: identityToken,
              intoAccount: intoAccount,
            ),
          ),
        };
      }

      // 14. /relay/v1/devices
      if (path == '/relay/v1/devices' && method == 'POST') {
        final body = bodyString.isNotEmpty
            ? jsonDecode(bodyString) as Map<String, dynamic>
            : <String, dynamic>{};
        final registration = DeviceRegistration.fromJson(body);
        // A bearer here is an `aj_`, never a `dv_`: it is the only auth
        // api.md §4.2 accepts on a registration.
        final join = (request.headers['authorization'] ?? '').replaceFirst(
          'Bearer ',
          '',
        );
        final response = registerDevice(
          registration,
          accountJoinToken: join.isEmpty ? null : join,
        );
        return _jsonResponse(response.toJson(), 201);
      }

      final deviceRoute = RegExp(
        r'^/relay/v1/devices/([^/]+)(?:/(subscriptions|tokens)(?:/([^/]+))?)?$',
      ).firstMatch(path);
      if (deviceRoute != null) {
        final id = Uri.decodeComponent(deviceRoute[1]!);
        final credential = (request.headers['authorization'] ?? '')
            .replaceFirst('Bearer ', '');
        final body = bodyString.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(bodyString) as Map<String, dynamic>;
        if (deviceRoute[2] == null && method == 'DELETE') {
          deleteDevice(deviceId: id, deviceToken: credential);
          return http.Response('', 204);
        }
        if (deviceRoute[2] == null && method == 'PATCH') {
          if (body.keys.toSet().difference({
                'push_token',
                'app_version',
              }).isNotEmpty ||
              body['push_token'] is! String ||
              body['app_version'] is! String) {
            throw const ApiException(
              statusCode: 400,
              message: 'invalid request',
            );
          }
          return _jsonResponse(refreshDevice(id, credential).toJson(), 200);
        }
        if (deviceRoute[2] == 'subscriptions') {
          if (method == 'POST') {
            subscribeTopic(
              deviceId: id,
              deviceToken: credential,
              topicHash: body['topic_hash'] as String,
            );
            return http.Response('', 204);
          }
          if (method == 'DELETE' && deviceRoute[3] != null) {
            unsubscribeTopic(
              deviceId: id,
              deviceToken: credential,
              topicHash: deviceRoute[3]!,
            );
            return http.Response('', 204);
          }
        }
        if (deviceRoute[2] == 'tokens' && method == 'POST') {
          uploadActivityToken(
            deviceId: id,
            deviceToken: credential,
            kind: body['kind'] as String,
            token: body['token'] as String,
            activityId: body['activity_id'] as String?,
            incidentId: body['incident_id'] as String?,
          );
          return http.Response('', 204);
        }
      }
      final sendMatch = RegExp(r'^/v1/topics/([^/]+)/send$').firstMatch(path);
      if (sendMatch != null && method == 'POST') {
        final body = jsonDecode(bodyString) as Map<String, dynamic>;
        if (body['message'] is! String) {
          throw const ApiException(statusCode: 400, message: 'invalid request');
        }
        final result = sendMessage(
          Uri.decodeComponent(sendMatch[1]!),
          message: body['message'] as String,
          title: body['title'] as String?,
          priority: body['priority'] as int? ?? 3,
          tags: (body['tags'] as List<dynamic>?)?.cast<String>(),
        );
        return _jsonResponse(result.toJson(), 200);
      }

      // 15. GET /{topic}/json?poll=1
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

      // 16. POST /{topic} or PUT /{topic}
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
      if (e.cap != null) body['cap'] = e.cap;
      return _jsonResponse(body, e.statusCode);
    } on Exception catch (e) {
      return _jsonResponse({'error': e.toString()}, 500);
    }
  }

  static http.Response _linkResponse(AccountLinkResult result) =>
      switch (result) {
        AccountLinkClaimed(:final accountId) => _jsonResponse({
          'account_id': accountId,
          'outcome': 'claimed',
        }, 200),
        AccountLinkAttached(:final accountId) => _jsonResponse({
          'account_id': accountId,
          'outcome': 'attached',
        }, 200),
        AccountLinkChoose(
          :final intoAccount,
          :final topics,
          :final incidents,
        ) =>
          _jsonResponse({
            'error': 'choose',
            'into_account': intoAccount,
            'topics': topics,
            'incidents': incidents,
          }, 409),
        AccountLinkLinked(:final accountId) => _jsonResponse({
          'account_id': accountId,
          'outcome': 'linked',
        }, 200),
        AccountLinkAlreadyLinked(:final accountId) => _jsonResponse({
          'account_id': accountId,
          'outcome': 'already_linked',
        }, 200),
        AccountLinkAccountHasAnotherIdentity() => _jsonResponse({
          'error': 'account has another identity',
        }, 409),
        AccountLinkIdentityHasAnotherAccount() => _jsonResponse({
          'error': 'identity has another account',
        }, 409),
        AccountLinkUnauthorized() => _jsonResponse(
          {'error': 'unauthorized'},
          401,
        ),
      };

  static http.Response _mergeResponse(AccountMergeResult result) =>
      switch (result) {
        AccountMerged(:final accountId, :final mergedFrom) => _jsonResponse({
          'account_id': accountId,
          'merged_from': mergedFrom,
        }, 200),
        AccountMergeLiveIncident(:final incidentId) => _jsonResponse({
          'error': 'live incident',
          'incident_id': incidentId,
        }, 409),
        AccountMergeAlreadyMerged() => _jsonResponse({
          'error': 'already merged',
        }, 409),
        AccountMergeSameAccount() => _jsonResponse({
          'error': 'same account',
        }, 409),
        AccountMergeUnauthorized() => _jsonResponse(
          {'error': 'unauthorized'},
          401,
        ),
      };

  static http.Response _deleteAccountResponse(AccountDeleteResult result) =>
      switch (result) {
        // 204 carries no body, the same as the real server.
        AccountDeleted() => http.Response('', 204),
        AccountDeleteLiveIncident(:final incidentId) => _jsonResponse({
          'error': 'live incident',
          'incident_id': incidentId,
        }, 409),
        AccountDeleteUnauthorized() => _jsonResponse(
          {'error': 'unauthorized'},
          401,
        ),
      };

  static http.Response _joinTokenResponse(AccountJoinTokenResult result) =>
      switch (result) {
        AccountJoinTokenMinted(:final joinToken) => _jsonResponse({
          'join_token': joinToken,
        }, 200),
        AccountJoinTokenUnauthorized() => _jsonResponse(
          {'error': 'unauthorized'},
          401,
        ),
      };

  static http.Response _switchResponse(AccountSwitchResult result) =>
      switch (result) {
        AccountSwitched(:final accountId) => _jsonResponse({
          'account_id': accountId,
        }, 200),
        AccountSwitchUnauthorized() => _jsonResponse(
          {'error': 'unauthorized'},
          401,
        ),
      };

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
