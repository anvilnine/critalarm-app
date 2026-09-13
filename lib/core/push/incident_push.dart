/// What the relay says this push is for. Matches `kind` in api.md §4.1/§5.2.
enum IncidentPushKind {
  open,
  repeat,
  reopen,
  p4;

  static IncidentPushKind? tryParse(String? value) {
    for (final kind in IncidentPushKind.values) {
      if (kind.name == value) return kind;
    }
    return null;
  }

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
  });

  /// Null only for a `p4` forward: api.md §4.1 sends no incident id for those.
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

  /// True when the relay stripped the content and the app has to fetch it
  /// with `GET /v1/incidents/{id}`.
  bool get needsContentFetch => title == null && body == null;

  /// This push opens or continues an incident, so the alarm path owns it.
  bool get isIncident => kind != IncidentPushKind.p4 && incidentId != null;

  /// FCM data message, api.md §5.2. Every value arrives as a string.
  static IncidentPush? fromFcmData(Map<String, String> data) => _parse(
    incidentId: data['incident_id'],
    server: data['server'],
    kind: data['kind'],
    priority: int.tryParse(data['priority'] ?? ''),
    requirePriority: true,
    title: data['title'],
    body: data['body'],
  );

  /// APNs payload, api.md §5.1. `incident_id`, `server` and `kind` sit at the
  /// top level next to `aps`; the display text lives inside `aps.alert`, and
  /// there is no `priority` key, so it comes from [IncidentPushKind].
  static IncidentPush? fromApnsPayload(Map<String, dynamic> payload) {
    final aps = payload['aps'];
    final alert = aps is Map ? aps['alert'] : null;
    final title = alert is Map ? alert['title'] : null;
    final body = alert is Map ? alert['body'] : null;
    return _parse(
      incidentId: payload['incident_id'] as String?,
      server: payload['server'] as String?,
      kind: payload['kind'] as String?,
      priority: (payload['priority'] as num?)?.toInt(),
      requirePriority: false,
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
  }) {
    final parsedKind = IncidentPushKind.tryParse(kind);
    if (parsedKind == null) return null;

    final id = (incidentId ?? '').isEmpty ? null : incidentId;
    if (id == null && parsedKind != IncidentPushKind.p4) return null;

    final uri = Uri.tryParse(server ?? '');
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }

    if (priority == null && requirePriority) return null;
    final resolvedPriority = priority ?? parsedKind.impliedPriority;
    if (resolvedPriority < 1 || resolvedPriority > 5) return null;

    return IncidentPush(
      incidentId: id,
      server: uri,
      kind: parsedKind,
      priority: resolvedPriority,
      title: (title ?? '').isEmpty ? null : title,
      body: (body ?? '').isEmpty ? null : body,
    );
  }
}
