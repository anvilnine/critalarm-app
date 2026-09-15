/// The management send route returns identifiers, not a full message.
final class SendResult {
  const SendResult({required this.id, this.incidentId});
  factory SendResult.fromJson(Map<String, dynamic> json) => SendResult(
    id: json['id'] as String,
    incidentId: json['incident_id'] as String?,
  );
  final String id;
  final String? incidentId;
  Map<String, dynamic> toJson() => {'id': id, 'incident_id': incidentId};
}
