import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/core/models/incident.dart';
import 'package:critalarm/core/models/message.dart';
import 'package:critalarm/core/models/send_result.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/models/topic.dart';
import 'package:critalarm/core/models/topic_token.dart';

/// What `GET /v1/incidents` answers when `limit` is left off (api.md §3.2).
///
/// Here so a fake server can behave like the real one. No caller should ever
/// see it, because every caller sends a limit.
const defaultIncidentLimit = 20;

/// The biggest `limit` `GET /v1/incidents` accepts.
///
/// api.md §3.2: leave `limit` off and the server hands back 20, so an absent
/// parameter is not a request for everything. Ask for more than 200 and the
/// server gives you 200. There is no paging in v1, so this is the most
/// incidents one call can read.
const maxIncidentLimit = 200;

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

  /// GET /v1/topics/{name}/tokens
  ///
  /// Ids and dates only. The server has no token values to give back.
  Future<List<TopicTokenInfo>> getTopicTokens(String name);

  /// POST /v1/topics/{name}/tokens
  Future<TopicToken> createTopicToken(String name);

  /// DELETE /v1/topics/{name}/tokens/{token_id}
  Future<void> deleteTopicToken(String name, String tokenId);

  /// GET /v1/incidents
  ///
  /// [limit] is required, and not nullable, because a missing `limit` is not
  /// "no limit": the server answers 20 (api.md §3.2). It used to be optional
  /// here and the query dropped it when it was null, which is how paid
  /// History quietly showed 20 alarms.
  Future<List<Incident>> getIncidents({
    required int limit,
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

  /// POST /v1/topics/{topic}/send
  Future<SendResult> publishMessage(
    String topic, {
    required String message,
    String? title,
    int priority = 3,
    List<String>? tags,
  });

  /// GET /{topic}/json?poll=1
  Future<List<Message>> pollMessages(
    String topic, {
    required int poll,
    String? since,
  });

  /// POST /v1/account/link
  ///
  /// Sign up and sign in are the same call. `dv_` stays in the Authorization
  /// header, because it says which account this handset brings, and the
  /// identity travels in the body (api.md §3.7). One header cannot carry two
  /// secrets.
  ///
  /// [intent] says which screen the person was on. `sign_in` is the sign-in
  /// screen and behaves as it always has; `link` is the account screen adding
  /// a second way in. The server cannot tell them apart on its own.
  Future<AccountLinkResult> linkAccount({
    required String identityToken,
    AccountLinkIntent intent = AccountLinkIntent.signIn,
  });

  /// POST /v1/account/join-token
  ///
  /// Mints a fresh `aj_` for the account this device already belongs to. The
  /// value comes back once and nothing can read it back, because the server
  /// keeps a hash of it. Every call retires the token before it.
  Future<AccountJoinTokenResult> mintAccountJoinToken();

  /// POST /v1/account/merge
  ///
  /// Folds this phone's account into [intoAccount]. Every topic token on both
  /// sides keeps working.
  Future<AccountMergeResult> mergeAccount({
    required String identityToken,
    required String intoAccount,
  });

  /// POST /v1/account/switch
  ///
  /// Joins [intoAccount] and leaves this phone's old account behind, carrying
  /// nothing. The tokens on the old topics stop working.
  Future<AccountSwitchResult> switchAccount({
    required String identityToken,
    required String intoAccount,
  });

  /// DELETE /v1/account
  ///
  /// Erases this device's account and everything under it. `dv_` stays in the
  /// Authorization header and [identityToken] travels in the body, the same
  /// split the other three account routes use.
  ///
  /// [identityToken] is left out when the account holds no identity, because
  /// an account with nobody signed in is deleted on the device token alone
  /// (api.md §3.7).
  Future<AccountDeleteResult> deleteAccount({String? identityToken});

  /// POST /relay/v1/devices
  ///
  /// [accountJoinToken] is the `aj_` from api.md §4.2. With it, a device id
  /// the server has never seen joins that account instead of creating a new
  /// one. Without it the call creates a fresh anonymous account.
  Future<DeviceRegistrationResponse> registerDevice(
    DeviceRegistration registration, {
    Uri? relayUri,
    String? accountJoinToken,
  });

  /// PATCH /relay/v1/devices/{device_id}
  Future<DeviceRegistrationResponse> refreshDevice(
    DeviceRegistration registration,
    String deviceToken, {
    Uri? relayUri,
  });

  /// POST /relay/v1/devices/{device_id}/subscriptions
  Future<void> subscribeTopic({
    required String deviceId,
    required String deviceToken,
    required String topicHash,
  });

  /// DELETE /relay/v1/devices/{device_id}/subscriptions/{topic_hash}
  Future<void> unsubscribeTopic({
    required String deviceId,
    required String deviceToken,
    required String topicHash,
  });

  /// DELETE /relay/v1/devices/{device_id}
  ///
  /// Half of signing out. api.md §3.7: the other half is registering again
  /// with a new device id, because a phone that drops `dv_` and keeps its old
  /// device id can never register again.
  Future<void> deleteDevice({
    required String deviceId,
    required String deviceToken,
    Uri? relayUri,
  });

  /// POST /relay/v1/devices/{device_id}/tokens. la_update requires activityId.
  Future<void> uploadActivityToken({
    required String deviceId,
    required String deviceToken,
    required String kind,
    required String token,
    String? incidentId,
    String? activityId,
  });
}
