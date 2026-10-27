import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/packs_api.dart';
import 'package:critalarm/core/api/stale_account_exception.dart';
import 'package:critalarm/core/api/weekly_check_api.dart';
import 'package:critalarm/core/models/account_pack.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/models/send_result.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/models/topic_token.dart';
import 'package:critalarm/core/models/weekly_check.dart';

/// The one place an answer is checked against the account that asked.
///
/// Every call that returns incidents or messages reads the scope (server and
/// account) when it starts and again when the answer arrives. If the two
/// differ, the call throws [StaleAccountException] and the answer goes no
/// further, whether it was an answer or an error. The scopes are compared and
/// nothing else, so a sign-in that changes nothing about the account, or an
/// account that was left and came back, leaves the answer standing.
///
/// Every other call passes straight through.
final class ScopedApiClient implements ApiClient, PacksApi, WeeklyCheckApi {
  ScopedApiClient(this._inner, {required this._readScope});

  final ApiClient _inner;
  final Future<String?> Function() _readScope;

  PacksApi get _packs => _inner as PacksApi;
  WeeklyCheckApi get _weekly => _inner as WeeklyCheckApi;

  Future<String?> _scope() async {
    try {
      return await _readScope();
    } on Object catch (_) {
      return null;
    }
  }

  Future<T> _guard<T>(Future<T> Function() request) async {
    final started = await _scope();
    final T answer;
    try {
      answer = await request();
    } on Object {
      if (started != null && await _scope() != started) {
        throw const StaleAccountException();
      }
      rethrow;
    }
    if (started != null && await _scope() != started) {
      throw const StaleAccountException();
    }
    return answer;
  }

  @override
  Future<List<Incident>> getIncidents({
    required int limit,
    String? state,
    String? topic,
    DateTime? since,
  }) => _guard(
    () => _inner.getIncidents(
      limit: limit,
      state: state,
      topic: topic,
      since: since,
    ),
  );

  @override
  Future<Incident> getIncident(String id) =>
      _guard(() => _inner.getIncident(id));

  @override
  Future<Incident> ackIncident(String id) =>
      _guard(() => _inner.ackIncident(id));

  @override
  Future<Incident> closeIncident(String id) =>
      _guard(() => _inner.closeIncident(id));

  @override
  Future<SendResult> publishMessage(
    String topic, {
    required String message,
    String? title,
    int priority = 3,
    List<String>? tags,
  }) => _guard(
    () => _inner.publishMessage(
      topic,
      message: message,
      title: title,
      priority: priority,
      tags: tags,
    ),
  );

  @override
  Future<List<Message>> pollMessages(
    String topic, {
    required int poll,
    String? since,
  }) => _guard(
    () => _inner.pollMessages(topic, poll: poll, since: since),
  );

  @override
  Future<ServerInfo> getServerInfo([Uri? candidateBaseUri]) =>
      _inner.getServerInfo(candidateBaseUri);

  @override
  Future<List<Topic>> getTopics() => _inner.getTopics();

  @override
  Future<Topic> createTopic({
    required String name,
    bool critical = false,
    int repeatIntervalS = 30,
    int maxRingS = 1800,
    int deskTimerS = 600,
    String relayContent = 'none',
    String? tokenName,
  }) => _inner.createTopic(
    name: name,
    critical: critical,
    repeatIntervalS: repeatIntervalS,
    maxRingS: maxRingS,
    deskTimerS: deskTimerS,
    relayContent: relayContent,
    tokenName: tokenName,
  );

  @override
  Future<Topic> updateTopic(
    String name, {
    bool? critical,
    int? repeatIntervalS,
    int? maxRingS,
    int? deskTimerS,
  }) => _inner.updateTopic(
    name,
    critical: critical,
    repeatIntervalS: repeatIntervalS,
    maxRingS: maxRingS,
    deskTimerS: deskTimerS,
  );

  @override
  Future<void> deleteTopic(String name) => _inner.deleteTopic(name);

  @override
  Future<List<TopicTokenInfo>> getTopicTokens(String name) =>
      _inner.getTopicTokens(name);

  @override
  Future<TopicToken> createTopicToken(String name, {String? tokenName}) =>
      _inner.createTopicToken(name, tokenName: tokenName);

  @override
  Future<TopicTokenInfo> renameTopicToken(
    String name,
    String tokenId,
    String tokenName,
  ) => _inner.renameTopicToken(name, tokenId, tokenName);

  @override
  Future<void> deleteTopicToken(String name, String tokenId) =>
      _inner.deleteTopicToken(name, tokenId);

  @override
  Future<String> triggerTest({required String topic}) =>
      _inner.triggerTest(topic: topic);

  @override
  Future<AccountLinkResult> linkAccount({
    required String identityToken,
    AccountLinkIntent intent = AccountLinkIntent.signIn,
  }) => _inner.linkAccount(identityToken: identityToken, intent: intent);

  @override
  Future<AccountJoinTokenResult> mintAccountJoinToken() =>
      _inner.mintAccountJoinToken();

  @override
  Future<AccountMergeResult> mergeAccount({
    required String identityToken,
    required String intoAccount,
  }) => _inner.mergeAccount(
    identityToken: identityToken,
    intoAccount: intoAccount,
  );

  @override
  Future<AccountSwitchResult> switchAccount({
    required String identityToken,
    required String intoAccount,
  }) => _inner.switchAccount(
    identityToken: identityToken,
    intoAccount: intoAccount,
  );

  @override
  Future<AccountDeleteResult> deleteAccount({String? identityToken}) =>
      _inner.deleteAccount(identityToken: identityToken);

  @override
  Future<DeviceRegistrationResponse> registerDevice(
    DeviceRegistration registration, {
    Uri? relayUri,
    String? accountJoinToken,
  }) => _inner.registerDevice(
    registration,
    relayUri: relayUri,
    accountJoinToken: accountJoinToken,
  );

  @override
  Future<DeviceRegistrationResponse> refreshDevice(
    DeviceRegistration registration,
    String deviceToken, {
    Uri? relayUri,
  }) => _inner.refreshDevice(registration, deviceToken, relayUri: relayUri);

  @override
  Future<void> subscribeTopic({
    required String deviceId,
    required String deviceToken,
    required String topicHash,
  }) => _inner.subscribeTopic(
    deviceId: deviceId,
    deviceToken: deviceToken,
    topicHash: topicHash,
  );

  @override
  Future<void> unsubscribeTopic({
    required String deviceId,
    required String deviceToken,
    required String topicHash,
  }) => _inner.unsubscribeTopic(
    deviceId: deviceId,
    deviceToken: deviceToken,
    topicHash: topicHash,
  );

  @override
  Future<void> deleteDevice({
    required String deviceId,
    required String deviceToken,
    Uri? relayUri,
  }) => _inner.deleteDevice(
    deviceId: deviceId,
    deviceToken: deviceToken,
    relayUri: relayUri,
  );

  @override
  Future<void> uploadActivityToken({
    required String deviceId,
    required String deviceToken,
    required String kind,
    required String token,
    String? incidentId,
    String? activityId,
  }) => _inner.uploadActivityToken(
    deviceId: deviceId,
    deviceToken: deviceToken,
    kind: kind,
    token: token,
    incidentId: incidentId,
    activityId: activityId,
  );

  @override
  Future<PacksAnswer> getPacks() => _packs.getPacks();

  @override
  Future<PacksRefreshAnswer> refreshPacks() => _packs.refreshPacks();

  @override
  Future<WeeklyCheck> setWeeklyCheck({required bool enabled}) =>
      _weekly.setWeeklyCheck(enabled: enabled);

  @override
  Future<WeeklyCheck> getWeeklyCheck() => _weekly.getWeeklyCheck();

  @override
  Future<WeeklyCheckReceipt> sendWeeklyCheckReceipt(
    String checkId, {
    int? attempt,
    int? receivedAt,
  }) => _weekly.sendWeeklyCheckReceipt(
    checkId,
    attempt: attempt,
    receivedAt: receivedAt,
  );

  @override
  Future<List<WeeklyCheckRound>> listWeeklyCheckRounds({int? limit}) =>
      _weekly.listWeeklyCheckRounds(limit: limit);
}
