enum FcmIncidentKind { open, repeat, reopen, p4 }

final class FcmIncidentPayload {
  const FcmIncidentPayload({
    required this.incidentId,
    required this.server,
    required this.kind,
    required this.priority,
    this.title,
    this.body,
  });

  final String incidentId;
  final Uri server;
  final FcmIncidentKind kind;
  final int priority;
  final String? title;
  final String? body;

  static FcmIncidentPayload? tryParse(Map<String, String> data) {
    final incidentId = data['incident_id'];
    final server = Uri.tryParse(data['server'] ?? '');
    final kind = FcmIncidentKind.values
        .where((value) => value.name == data['kind'])
        .firstOrNull;
    final priority = int.tryParse(data['priority'] ?? '');
    if (incidentId == null ||
        incidentId.isEmpty ||
        server == null ||
        !server.hasAuthority ||
        (server.scheme != 'http' && server.scheme != 'https') ||
        kind == null ||
        priority == null ||
        priority < 1 ||
        priority > 5) {
      return null;
    }
    return FcmIncidentPayload(
      incidentId: incidentId,
      server: server,
      kind: kind,
      priority: priority,
      title: data['title'],
      body: data['body'],
    );
  }
}
