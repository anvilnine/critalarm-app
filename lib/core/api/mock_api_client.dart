import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/mock_server.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/models/send_result.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/models/topic_token.dart';

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
  Future<List<TopicTokenInfo>> getTopicTokens(String name) async =>
      server.getTopicTokens(name);

  @override
  Future<TopicToken> createTopicToken(String name) async =>
      server.createTopicToken(name);

  @override
  Future<void> deleteTopicToken(String name, String tokenId) async =>
      server.deleteTopicToken(name, tokenId);

  @override
  Future<List<Incident>> getIncidents({
    required int limit,
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
  Future<SendResult> publishMessage(
    String topic, {
    required String message,
    String? title,
    int priority = 3,
    List<String>? tags,
  }) async {
    return server.sendMessage(
      topic,
      message: message,
      title: title,
      priority: priority,
      tags: tags,
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

  /// The device token this fake hands to the account routes.
  ///
  /// The real client reads it off the session store, which a widget test has
  /// no reason to set up, so the fake uses whichever device registered last.
  String? deviceToken;

  @override
  Future<AccountLinkResult> linkAccount({
    required String identityToken,
    AccountLinkIntent intent = AccountLinkIntent.signIn,
  }) async {
    return server.linkAccount(
      deviceToken: deviceToken ?? '',
      identityToken: identityToken,
      intent: intent,
    );
  }

  @override
  Future<AccountJoinTokenResult> mintAccountJoinToken() async {
    return server.mintAccountJoinToken(deviceToken: deviceToken ?? '');
  }

  @override
  Future<AccountMergeResult> mergeAccount({
    required String identityToken,
    required String intoAccount,
  }) async {
    return server.mergeAccount(
      deviceToken: deviceToken ?? '',
      identityToken: identityToken,
      intoAccount: intoAccount,
    );
  }

  @override
  Future<AccountSwitchResult> switchAccount({
    required String identityToken,
    required String intoAccount,
  }) async {
    return server.switchAccount(
      deviceToken: deviceToken ?? '',
      identityToken: identityToken,
      intoAccount: intoAccount,
    );
  }

  @override
  Future<AccountDeleteResult> deleteAccount({String? identityToken}) async {
    return server.deleteAccount(
      deviceToken: deviceToken ?? '',
      identityToken: identityToken,
    );
  }

  @override
  Future<void> deleteDevice({
    required String deviceId,
    required String deviceToken,
    Uri? relayUri,
  }) async => server.deleteDevice(
    deviceId: deviceId,
    deviceToken: deviceToken,
  );

  @override
  Future<DeviceRegistrationResponse> registerDevice(
    DeviceRegistration registration, {
    Uri? relayUri,
    String? accountJoinToken,
  }) async {
    final response = server.registerDevice(
      registration,
      accountJoinToken: accountJoinToken,
    );
    deviceToken = response.deviceToken;
    return response;
  }

  @override
  Future<void> subscribeTopic({
    required String deviceId,
    required String deviceToken,
    required String topicHash,
  }) async => server.subscribeTopic(
    deviceId: deviceId,
    deviceToken: deviceToken,
    topicHash: topicHash,
  );

  @override
  Future<void> unsubscribeTopic({
    required String deviceId,
    required String deviceToken,
    required String topicHash,
  }) async => server.unsubscribeTopic(
    deviceId: deviceId,
    deviceToken: deviceToken,
    topicHash: topicHash,
  );

  /// Every token the app has handed over, newest last. The diagnostics test
  /// reads this instead of a real relay.
  final List<Map<String, String?>> activityTokens = [];

  @override
  Future<void> uploadActivityToken({
    required String deviceId,
    required String deviceToken,
    required String kind,
    required String token,
    String? incidentId,
    String? activityId,
  }) async {
    server.uploadActivityToken(
      deviceId: deviceId,
      deviceToken: deviceToken,
      kind: kind,
      token: token,
      activityId: kind == 'la_update' ? activityId : null,
      incidentId: kind == 'la_update' ? incidentId : null,
    );
    activityTokens.add({
      'device_id': deviceId,
      'kind': kind,
      'token': token,
      'incident_id': incidentId,
      if (kind == 'la_update') 'activity_id': activityId,
    });
  }

  @override
  Future<DeviceRegistrationResponse> refreshDevice(
    DeviceRegistration registration,
    String deviceToken, {
    Uri? relayUri,
  }) async {
    // The development fixture is recreated on launch, while identity persists.
    server.registerDevice(registration, deviceToken: deviceToken);
    return server.refreshDevice(registration.deviceId, deviceToken);
  }
}
