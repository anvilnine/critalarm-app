final class IncidentUpdateOrder {
  const IncidentUpdateOrder(this.timestamp);
  final DateTime timestamp;

  bool accepts(IncidentUpdateOrder incoming) =>
      !incoming.timestamp.isBefore(timestamp);
}
