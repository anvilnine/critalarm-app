/// The two things the user can send about an incident (api.md §3.2).
enum AckAction {
  ack,
  close;

  static AckAction? tryParse(String? value) {
    for (final action in AckAction.values) {
      if (action.name == value) return action;
    }
    return null;
  }
}

/// One queued send, as it is stored on disk.
final class AckQueueEntry {
  const AckQueueEntry({
    required this.id,
    required this.action,
    required this.incidentId,
    required this.enqueuedAtMs,
    this.attempts = 0,
    this.nextAttemptAtMs = 0,
    this.alarmFiredAtMs,
  });

  /// Unique per enqueue, so two acks for one incident never collapse.
  final String id;
  final AckAction action;
  final String incidentId;
  final int enqueuedAtMs;
  final int attempts;

  /// Epoch milliseconds. The queue skips the entry until the clock passes it.
  final int nextAttemptAtMs;

  /// When the alarm started ringing, so `time_to_ack_ms` can be reported once
  /// the send actually lands.
  final int? alarmFiredAtMs;

  AckQueueEntry copyWith({int? attempts, int? nextAttemptAtMs}) =>
      AckQueueEntry(
        id: id,
        action: action,
        incidentId: incidentId,
        enqueuedAtMs: enqueuedAtMs,
        attempts: attempts ?? this.attempts,
        nextAttemptAtMs: nextAttemptAtMs ?? this.nextAttemptAtMs,
        alarmFiredAtMs: alarmFiredAtMs,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'action': action.name,
    'incident_id': incidentId,
    'enqueued_at_ms': enqueuedAtMs,
    'attempts': attempts,
    'next_attempt_at_ms': nextAttemptAtMs,
    if (alarmFiredAtMs != null) 'alarm_fired_at_ms': alarmFiredAtMs,
  };

  static AckQueueEntry? fromJson(Map<String, dynamic> json) {
    final action = AckAction.tryParse(json['action'] as String?);
    final id = json['id'] as String?;
    final incidentId = json['incident_id'] as String?;
    if (action == null ||
        id == null ||
        id.isEmpty ||
        incidentId == null ||
        incidentId.isEmpty) {
      return null;
    }
    return AckQueueEntry(
      id: id,
      action: action,
      incidentId: incidentId,
      enqueuedAtMs: (json['enqueued_at_ms'] as num?)?.toInt() ?? 0,
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      nextAttemptAtMs: (json['next_attempt_at_ms'] as num?)?.toInt() ?? 0,
      alarmFiredAtMs: (json['alarm_fired_at_ms'] as num?)?.toInt(),
    );
  }
}
