import 'package:critalarm/core/models/send_result.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/entities/message.dart';

/// Domain contract for managing incidents and alarm messages on the server.
abstract interface class IncidentRepository {
  Future<AppResult<List<Incident>>> getIncidents({
    int? limit,
    String? state,
    String? topic,
  });

  Future<AppResult<Incident>> getIncident(String id);

  Future<AppResult<Incident>> ackIncident(String id);

  Future<AppResult<Incident>> closeIncident(String id);

  Future<AppResult<String>> triggerTest({required String topic});

  Future<AppResult<SendResult>> publishMessage(
    String topic, {
    required String message,
    String? title,
    int priority = 3,
    List<String>? tags,
  });

  Future<AppResult<List<Message>>> pollMessages(
    String topic, {
    required int poll,
    String? since,
  });
}
