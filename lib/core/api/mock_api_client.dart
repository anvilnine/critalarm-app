import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/models/topic.dart';

/// In-memory implementation of [ApiClient] backed by [MockServer].
class MockApiClient implements ApiClient {
  MockApiClient([MockServer? server]) : server = server ?? MockServer();

  final MockServer server;

  @override
  Future<ServerInfo> getServerInfo([Uri? candidateBaseUri]) async =>
      server.getInfo();

  @override
  Future<List<Topic>> getTopics() async => server.getTopics();

  @override
  Future<Topic> createTopic({
    required String name,
    bool critical = false,
    int repeatIntervalS = 30,
    int maxRingS = 1800,
    int deskTimerS = 600,
    String relayContent = 'none',
  }) async {
    return server.createTopic(
      name: name,
      critical: critical,
      repeatIntervalS: repeatIntervalS,
      maxRingS: maxRingS,
      deskTimerS: deskTimerS,
      relayContent: relayContent,
    );
  }

  @override
  Future<Topic> updateTopic(
    String name, {
    bool? critical,
    int? repeatIntervalS,
    int? maxRingS,
    int? deskTimerS,
  }) async {
    return server.updateTopic(
      name,
      critical: critical,
      repeatIntervalS: repeatIntervalS,
      maxRingS: maxRingS,
      deskTimerS: deskTimerS,
    );
  }

  @override
  Future<void> deleteTopic(String name) async => server.deleteTopic(name);

  @override
  Future<String> createTopicToken(String name) async =>
      server.createTopicToken(name);

  @override
  Future<void> deleteTopicToken(String name, String tokenId) async =>
      server.deleteTopicToken(name, tokenId);

  @override
  Future<List<Incident>> getIncidents({
    int? limit,
    String? state,
    String? topic,
  }) async {
    return server.getIncidents(limit: limit, state: state, topic: topic);
  }

  @override
  Future<Incident> getIncident(String id) async => server.getIncident(id);

  @override
  Future<Incident> ackIncident(String id) async => server.ackIncident(id);

  @override
  Future<Incident> closeIncident(String id) async => server.closeIncident(id);

  @override
  Future<String> triggerTest({required String topic}) async =>
      server.triggerTest(topic: topic);

  @override
  Future<Message> publishMessage(
    String topic, {
    String? message,
    String? title,
    int priority = 3,
    List<String>? tags,
    String? click,
    bool? markdown,
  }) async {
    return server.publishMessage(
      topic,
      message: message,
      title: title,
      priority: priority,
      tags: tags,
      click: click,
      markdown: markdown,
    );
  }

  @override
  Future<List<Message>> pollMessages(
    String topic, {
    required int poll,
    String? since,
  }) async {
    return server.pollMessages(topic, poll: poll, since: since);
  }

  @override
  Future<DeviceRegistrationResponse> registerDevice(
    DeviceRegistration registration,
  ) async {
    return server.registerDevice(registration);
  }
}
