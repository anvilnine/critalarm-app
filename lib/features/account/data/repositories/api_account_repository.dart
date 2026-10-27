import 'package:critalarm/core/access/holding.dart';
import 'package:critalarm/core/access/holdings.dart';
import 'package:critalarm/core/api/account_results.dart';
import 'package:critalarm/core/api/api_client.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/version/app_version.dart';
import 'package:critalarm/features/account/domain/repositories/account_repository.dart';
import 'package:critalarm/features/account/domain/repositories/identity_repository.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/repositories/connection_repository.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';

/// The account routes, plus the sign-out dance that needs four of them.
final class ApiAccountRepository implements AccountRepository {
  ApiAccountRepository({
    required this.api,
    required this.sessions,
    required this.devices,
    required this.register,
    required this.identities,
    required this.connections,
    this.forgetAccountData,
    this.forgetDeletedAccountData,
    this.forgetMergedAccount,
    this.readAccountId,
    this.signOutBilling,
    this.stopAlarm,
    this.holdings,
  });

  final ApiClient api;
  final ApiSessionStore sessions;
  final DeviceIdentityStore devices;
  final RegisterDeviceUsecase register;
  final IdentityRepository identities;
  final ConnectionRepository connections;

  /// Drops everything on this phone that belongs to the account it is
  /// leaving: acknowledgements still waiting, the poll cursors, the recent
  /// searches, and what the paid features keep (challenge choices, alarm
  /// looks and their notes). The list itself is `AccountData` in
  /// `lib/app/account_data.dart`, which a connect to a different server
  /// calls too.
  final Future<void> Function()? forgetAccountData;

  /// [forgetAccountData], and the phone's copy of the account's alarm
  /// history, for an account that was deleted. Falls back to
  /// [forgetAccountData] when not given.
  ///
  /// Called with the account that was deleted, as [readAccountId] named it
  /// when the delete started, or null when that is not known.
  final Future<void> Function(String? accountId)? forgetDeletedAccountData;

  /// The account this phone is on now: the one the person signed in to, or
  /// the device's own. A delete reads it before anything is signed out, so the
  /// archive of the account that went is the one removed.
  final Future<String?> Function()? readAccountId;

  /// Called with the account folded away and the one it went into once the
  /// server has merged, so what the phone kept for the first moves to the
  /// second. A failure here never turns a merge into an error.
  final Future<void> Function(String from, String into)? forgetMergedAccount;

  /// Drops the store's idea of who this is, back to an anonymous user.
  ///
  /// A callback rather than the service itself, the same way registration
  /// takes `identifyAccount`, so this repository does not reach into the
  /// paywall feature.
  final Future<void> Function()? signOutBilling;

  /// Stops whatever is ringing on this handset.
  final Future<void> Function()? stopAlarm;

  /// What this install holds. Null in tests that never ask, and then
  /// nothing is held.
  final Holdings? holdings;

  /// True while [recoverFromDeadCredential] is working. Every route on a dead
  /// credential answers 401, so several of them can ask for a recovery at
  /// once, and two recoveries racing would register twice.
  bool _recovering = false;

  /// The account a delete is about, read when the delete started. A delete
  /// that is refused as unauthorized signs the person in again and sends it a
  /// second time, and by then the sign-in is gone, so the phone no longer
  /// names that account. Held across that one retry only.
  String? _deleting;

  @override
  Future<AccountLinkResult> link(
    String identityToken, {
    AccountLinkIntent intent = AccountLinkIntent.signIn,
  }) => api.linkAccount(identityToken: identityToken, intent: intent);

  @override
  Future<AccountJoinTokenResult> mintJoinToken() => api.mintAccountJoinToken();

  @override
  Future<AccountMergeResult> merge({
    required String identityToken,
    required String intoAccount,
  }) async {
    final result = await api.mergeAccount(
      identityToken: identityToken,
      intoAccount: intoAccount,
    );
    String? from;
    String? into;
    switch (result) {
      case AccountMerged(:final accountId, :final mergedFrom):
        from = mergedFrom;
        into = accountId;
      case AccountMergeAlreadyMerged():
        // A retry after a reply that never arrived: the server merged the
        // first time. The phone still names its own account until the next
        // registration, so that is the one that was folded in.
        try {
          from = await readAccountId?.call();
        } on Object catch (_) {}
        into = intoAccount;
      case _:
        break;
    }
    if (from != null && into != null && from != into) {
      try {
        await forgetMergedAccount?.call(from, into);
      } on Object catch (_) {}
    }
    return result;
  }

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
    // The device is deleted on the server, so this phone has left the
    // account. What the account left here goes before the next one starts.
    // A drop that fails never stops the registration below: without it the
    // phone has no credential at all.
    try {
      await forgetAccountData?.call();
    } on Object catch (_) {}
    await _startOverOnFreshAccount();
  }

  @override
  Future<AccountDeleteResult> deleteAccount({String? identityToken}) async {
    if (_deleting == null) {
      try {
        _deleting = await readAccountId?.call();
      } on Object catch (_) {}
    }
    final AccountDeleteResult result;
    try {
      result = await api.deleteAccount(identityToken: identityToken);
    } on Object {
      _deleting = null;
      rethrow;
    }
    // Kept only while a delete went through, or a retry is about to follow a
    // refused one. Any other answer ends the attempt.
    final retryFollows =
        result is AccountDeleteUnauthorized && identityToken != null;
    if (result is! AccountDeleted && !retryFollows) _deleting = null;
    return result;
  }

  @override
  Future<void> wipeAfterDelete() {
    final deleted = _deleting;
    _deleting = null;
    final forgetDeleted = forgetDeletedAccountData;
    return _wipe(
      forget: forgetDeleted == null
          ? forgetAccountData
          : () => forgetDeleted(deleted),
    );
  }

  Future<void> _wipe({required Future<void> Function()? forget}) async {
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
    await forget?.call();
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
      // The credential is dead, not the account, so the history stays.
      await _wipe(forget: forgetAccountData);
    } finally {
      _recovering = false;
    }
  }

  @override
  Future<bool> readHoldsHosted() async =>
      await holdings?.holdsOnceReady(Holding.hosted) ?? false;

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
