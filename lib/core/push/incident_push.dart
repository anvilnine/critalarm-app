/// What the relay says this push is for. Matches `kind` in api.md §4.1/§5.2.
enum IncidentPushKind {
  open,
  repeat,
  reopen,
  p4,
  p5,

  /// The incident was acknowledged, closed or expired somewhere else
  /// (api.md §5.2). Data only, never a ring: the phone stops whatever is going
  /// off for that id, drops any local re-arm and updates its card.
  ack,
  close,
  expire;

  static IncidentPushKind? tryParse(String? value) {
    for (final kind in IncidentPushKind.values) {
      if (kind.name == value) return kind;
    }
    return null;
  }

  /// True when this kind never opens or continues an alarm, so it shows as a
  /// heads-up instead of ringing.
  ///
  /// `p5` is priority 5 on a topic whose critical switch is off (api.md §4.1).
  /// It may still carry an incident id, because the server names one when the
  /// message joined an incident that was already live.
  bool get isForward =>
      this == IncidentPushKind.p4 || this == IncidentPushKind.p5;

  /// True when the server is reporting where the incident ended up rather than
  /// paging anyone. These never ring and never post a notification.
  bool get isStateChange =>
      this == IncidentPushKind.ack ||
      this == IncidentPushKind.close ||
      this == IncidentPushKind.expire;

  /// Priority the contract implies when the payload does not carry one.
  ///
  /// api.md §1.7: a priority-5 message on a critical topic opens, joins or
  /// reopens an incident, so `open`, `repeat` and `reopen` are always
  /// priority 5. `p4` is the forward path for priority 4 and for priority 5 on
  /// a non-critical topic; those two look the same on the wire, so the lower
  /// of the pair is used.
  int get impliedPriority => this == IncidentPushKind.p4 ? 4 : 5;
}

/// One push, whichever platform delivered it.
///
/// Built from the FCM `data` map (api.md §5.2) or from the APNs custom keys
/// that sit beside `aps` (api.md §5.1). Everything the two have in common
/// lands on the same fields so the rest of the app never branches on platform.
final class IncidentPush {
  const IncidentPush({
    required this.server,
    required this.kind,
    required this.priority,
    this.incidentId,
    this.title,
    this.body,
    this.mutableContent = false,
    this.ringUntil,
  });

  /// Null on a forward: api.md §4.1 sends no incident id for `p4`, and a `p5`
  /// only carries one when the message joined a live incident.
  final String? incidentId;

  /// The server the message came from. One connection per app in v1, so a
  /// payload from any other server is dropped by the caller.
  final Uri server;

  final IncidentPushKind kind;

  /// 1-5, as in api.md §1.3.
  final int priority;

  /// Present only when the topic runs `relay_content: full`.
  final String? title;

  /// Present only when the topic runs `relay_content: full`.
  final String? body;

  /// `aps.mutable-content: 1`, which api.md §5.1 sets on APNs only when the
  /// text in `aps.alert` is a placeholder. `relay_content: full` drops it.
  /// FCM has no matching key, so it stays false there.
  final bool mutableContent;

  /// The last second this phone may ring for the incident on its own
  /// (api.md §5.1). Absent on a `p4` and on the three state kinds, which
  /// never ring at all.
  final DateTime? ringUntil;

  /// True when the relay stripped the content and the app has to fetch it
  /// with `GET /v1/incidents/{id}`.
  ///
  /// On APNs the placeholder text is always in `aps.alert`, so the flag is
  /// what says the text is a placeholder. On FCM there is no text at all.
  bool get needsContentFetch =>
      mutableContent || (title == null && body == null);

  /// This push opens or continues an incident, so the alarm path owns it.
  bool get isIncident =>
      !kind.isForward && !kind.isStateChange && incidentId != null;

  /// FCM data message, api.md §5.2. Every value arrives as a string.
  static IncidentPush? fromFcmData(Map<String, String> data) => _parse(
    incidentId: data['incident_id'],
    server: data['server'],
    kind: data['kind'],
    priority: int.tryParse(data['priority'] ?? ''),
    requirePriority: true,
    ringUntil: _epochSeconds(int.tryParse(data['ring_until'] ?? '')),
    title: data['title'],
    body: data['body'],
  );

  /// APNs payload, api.md §5.1. `incident_id`, `server` and `kind` sit at the
  /// top level next to `aps`; the display text lives inside `aps.alert`, and
  /// there is no `priority` key, so it comes from [IncidentPushKind].
  /// `aps.mutable-content: 1` marks that text as a placeholder.
  static IncidentPush? fromApnsPayload(Map<String, dynamic> payload) {
    final aps = payload['aps'];
    final alert = aps is Map ? aps['alert'] : null;
    final title = alert is Map ? alert['title'] : null;
    final body = alert is Map ? alert['body'] : null;
    final mutable = aps is Map && aps['mutable-content'] == 1;
    return _parse(
      mutableContent: mutable,
      incidentId: payload['incident_id'] as String?,
      server: payload['server'] as String?,
      kind: payload['kind'] as String?,
      priority: (payload['priority'] as num?)?.toInt(),
      requirePriority: false,
      ringUntil: _epochSeconds((payload['ring_until'] as num?)?.toInt()),
      title: title as String?,
      body: body as String?,
    );
  }

  static IncidentPush? _parse({
    required String? incidentId,
    required String? server,
    required String? kind,
    required int? priority,
    required bool requirePriority,
    required String? title,
    required String? body,
    bool mutableContent = false,
    DateTime? ringUntil,
  }) {
    final parsedKind = IncidentPushKind.tryParse(kind);
    if (parsedKind == null) return null;

    final id = (incidentId ?? '').isEmpty ? null : incidentId;
    if (id == null && !parsedKind.isForward) return null;

    final uri = Uri.tryParse(server ?? '');
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }

    // FCM spells every value out (api.md §5.2), so a missing priority there
    // is a malformed push. The three state kinds are the exception: they
    // carry none, because they never ring.
    if (priority == null && requirePriority && !parsedKind.isStateChange) {
      return null;
    }
    final resolvedPriority = priority ?? parsedKind.impliedPriority;
    if (resolvedPriority < 1 || resolvedPriority > 5) return null;

    return IncidentPush(
      incidentId: id,
      server: uri,
      kind: parsedKind,
      priority: resolvedPriority,
      title: (title ?? '').isEmpty ? null : title,
      body: (body ?? '').isEmpty ? null : body,
      mutableContent: mutableContent,
      ringUntil: ringUntil,
    );
  }

  /// `ring_until` is epoch seconds in UTC. Zero and anything unparseable read
  /// as absent, which stops the re-arm rather than ringing on a guess.
  static DateTime? _epochSeconds(int? value) =>
      (value == null || value <= 0)
      ? null
      : DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
}
