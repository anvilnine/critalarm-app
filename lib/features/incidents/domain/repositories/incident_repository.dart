import 'package:critalarm/core/models/send_result.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/incidents/domain/entities/incident.dart';
import 'package:critalarm/features/incidents/domain/entities/message.dart';

/// Domain contract for managing incidents and alarm messages on the server.
abstract interface class IncidentRepository {
  /// [limit] is required and not nullable on purpose: the server reads a
  /// missing `limit` as 20, so there is no way to ask for "all of them".
  ///
  /// The repository reads the phone first and syncs behind that, so a call
  /// that never reaches the server still answers with what is on disk.
  /// [since] left null means "ask for what the phone has not seen"; set
  /// [fullRefresh] to read the server's whole window instead.
  Future<AppResult<List<Incident>>> getIncidents({
    required int limit,
    String? state,
    String? topic,
    DateTime? since,
    bool fullRefresh = false,
  });

  Future<AppResult<Incident>> getIncident(String id);

  Future<AppResult<Incident>> ackIncident(String id);

  Future<AppResult<Incident>> closeIncident(String id);

  /// Writes one incident the caller already holds fresh into the phone's own
  /// copy. Used by the shared list so every path that updates it also updates
  /// the store.
  Future<void> saveIncident(Incident incident);

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
