enum IncidentNativeAction {
  ack('ack'),
  close('close');

  const IncidentNativeAction(this.wireValue);
  final String wireValue;
}

final class IncidentActionRoute {
  const IncidentActionRoute({required this.action, required this.path});

  final IncidentNativeAction action;
  final String path;

  static IncidentActionRoute? fromTrigger(String trigger, String incidentId) {
    if (incidentId.isEmpty) return null;
    final action = switch (trigger) {
      'stop' => IncidentNativeAction.ack,
      'acknowledge' => IncidentNativeAction.close,
      _ => null,
    };
    if (action == null) return null;
    final path =
        '/${Uri(
          pathSegments: ['v1', 'incidents', incidentId, action.wireValue],
        ).path}';
    return IncidentActionRoute(action: action, path: path);
  }
}
