import 'package:critalarm/core/ack/ack_queue.dart';
import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/models/account_access.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/sync/message_sync_service.dart';
import 'package:critalarm/core/version/app_version.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/account/domain/repositories/identity_repository.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';
import 'package:critalarm/features/search/domain/repositories/recent_searches_repository.dart';

/// The account routes, plus the sign-out dance that needs four of them.
final class ApiAccountRepository implements AccountRepository {
  ApiAccountRepository({
    required this.api,
    required this.sessions,
    required this.devices,
    required this.register,
    required this.identities,
    required this.connections,
    this.acks,
    this.messageCursors,
    this.recentSearches,
    this.signOutBilling,
    this.stopAlarm,
  });

  final ApiClient api;
  final ApiSessionStore sessions;
  final DeviceIdentityStore devices;
  final RegisterDeviceUsecase register;
  final IdentityRepository identities;
  final ConnectionRepository connections;

  /// Acknowledgements still waiting to be sent. Every one names an incident
  /// on the account that is going, so none of them can ever land.
  final AckQueue? acks;

  /// Where the poll cursors live, one per topic.
  final MessageSyncService? messageCursors;

  /// The last few things typed into search. They can name a deleted topic.
  final RecentSearchesRepository? recentSearches;

  /// Drops the store's idea of who this is, back to an anonymous user.
  ///
  /// A callback rather than the service itself, the same way registration
  /// takes `identifyAccount`, so this repository does not reach into the
  /// paywall feature.
  final Future<void> Function()? signOutBilling;

  /// Stops whatever is ringing on this handset.
  final Future<void> Function()? stopAlarm;

  /// True while [recoverFromDeadCredential] is working. Every route on a dead
  /// credential answers 401, so several of them can ask for a recovery at
  /// once, and two recoveries racing would register twice.
  bool _recovering = false;

  @override
  Future<AccountLinkResult> link(String identityToken) =>
      api.linkAccount(identityToken: identityToken);

  @override
  Future<AccountMergeResult> merge({
    required String identityToken,
    required String intoAccount,
  }) => api.mergeAccount(
    identityToken: identityToken,
    intoAccount: intoAccount,
  );

  @override
  Future<AccountSwitchResult> switchTo({
    required String identityToken,
    required String intoAccount,
  }) => api.switchAccount(
    identityToken: identityToken,
    intoAccount: intoAccount,
  );

  @override
  Future<ServerMode?> readServerMode() async => (await sessions.read())?.mode;

  @override
  Future<void> signOutDevice() async {
    final current = await devices.readOrCreate();
    final token = current.deviceToken;
    // Delete first. If the server refuses, the phone still holds a credential
    // that works, which is the difference between a failed sign-out and a
    // handset that can never talk to the server again.
    if (token != null) {
      await api.deleteDevice(deviceId: current.deviceId, deviceToken: token);
    }
    // The next line registers a new anonymous account and logs the store in
    // to it, so the store has to be logged out of the old one first or the
    // purchase is handed straight to the handset's next account. Anonymous
    // already is not a failure: the store answers
    // logOutWithAnonymousUserError and there is nothing to undo.
    try {
      await signOutBilling?.call();
    } on Object catch (_) {}
    await _startOverOnFreshAccount();
  }

  @override
  Future<AccountDeleteResult> deleteAccount({String? identityToken}) =>
      api.deleteAccount(identityToken: identityToken);

  @override
  Future<void> wipeAfterDelete() async {
    // The store knows this phone as the account id that has just gone, so it
    // goes back to an anonymous user before anything else. It is not a
    // failure when it was anonymous already: the store answers
    // logOutWithAnonymousUserError and there is nothing to undo.
    try {
      await signOutBilling?.call();
    } on Object catch (_) {}
    // Everything here names something on the account that is gone: an
    // incident to acknowledge, a message id to poll since, a topic somebody
    // searched for.
    await acks?.clear();
    await messageCursors?.resetAllCursors();
    await recentSearches?.clear();
    await _startOverOnFreshAccount();
  }

  @override
  Future<void> recoverFromDeadCredential() async {
    if (_recovering) return;
    _recovering = true;
    try {
      // Whatever is ringing belongs to an incident on an account that no
      // longer exists, so there is nobody left to acknowledge it to.
      await stopAlarm?.call();
      await wipeAfterDelete();
    } finally {
      _recovering = false;
    }
  }

  @override
  Future<bool> readIsPaid() async =>
      AccountAccess(await devices.readOrCreate()).isPaid;

  /// Drops this phone's identity, its connection and its device credential,
  /// then registers again so it lands on a new anonymous account.
  Future<void> _startOverOnFreshAccount() async {
    final connection = (await connections.getConnection()).getOrNull();
    await identities.clearSession();
    await connections.clearConnection();
    await devices.resetIdentity();
    final response = await register(appVersion: appVersion);
    final fresh = response.deviceToken;
    if (fresh == null) return;
    // Every /v1/ route authenticates on the device token alone, and the saved
    // session and connection both still carry the one that was just deleted.
    final session = await sessions.read();
    if (session != null) {
      await sessions.write(
        ApiSession(
          baseUri: session.baseUri,
          relayUri: session.relayUri,
          mode: session.mode,
          managementCredential: fresh,
        ),
      );
    }
    if (connection != null) {
      await connections.saveConnection(
        ServerConnection(
          serverUrl: connection.serverUrl,
          adminToken: fresh,
        ),
      );
    }
  }
}
