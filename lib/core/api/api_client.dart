import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/models/topic.dart';

/// Contract for communicating with a Crit Alarm server.
abstract interface class ApiClient {
  /// GET /v1/info
  Future<ServerInfo> getServerInfo([Uri? candidateBaseUri]);

  /// GET /v1/topics
  Future<List<Topic>> getTopics();

  /// POST /v1/topics
  Future<Topic> createTopic({
    required String name,
    bool critical = false,
    int repeatIntervalS = 30,
    int maxRingS = 1800,
    int deskTimerS = 600,
    String relayContent = 'none',
  });

  /// PATCH /v1/topics/{name}
  Future<Topic> updateTopic(
    String name, {
    bool? critical,
    int? repeatIntervalS,
    int? maxRingS,
    int? deskTimerS,
  });

  /// DELETE /v1/topics/{name}
  Future<void> deleteTopic(String name);

  /// POST /v1/topics/{name}/tokens
  Future<String> createTopicToken(String name);

  /// DELETE /v1/topics/{name}/tokens/{token_id}
  Future<void> deleteTopicToken(String name, String tokenId);

  /// GET /v1/incidents
  Future<List<Incident>> getIncidents({
    int? limit,
    String? state,
    String? topic,
  });

  /// GET /v1/incidents/{id}
  Future<Incident> getIncident(String id);

  /// POST /v1/incidents/{id}/ack
  Future<Incident> ackIncident(String id);

  /// POST /v1/incidents/{id}/close
  Future<Incident> closeIncident(String id);

  /// POST /v1/test?topic={name}
  Future<String> triggerTest({required String topic});

  /// POST /{topic}
  Future<Message> publishMessage(
    String topic, {
    String? message,
    String? title,
    int priority = 3,
    List<String>? tags,
    String? click,
    bool? markdown,
  });

  /// GET /{topic}/json?poll=1
  Future<List<Message>> pollMessages(
    String topic, {
    required int poll,
    String? since,
  });

  /// POST /relay/v1/devices
  Future<DeviceRegistrationResponse> registerDevice(
    DeviceRegistration registration,
  );
}
