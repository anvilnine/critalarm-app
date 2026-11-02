import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/models/device_identity.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/models/server_info_validator.dart';
import 'package:critalarm/core/push/device_token_relay.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/version/app_version.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';

/// The saved session and the device identity as they were at one moment, to
/// put back when a connect does not land.
final class SessionCheckpoint {
  const SessionCheckpoint(this.session, this.identity);

  final ApiSession? session;

  /// What `DeviceIdentityStore.snapshot` answered.
  final Object identity;
}

/// Writes the session for a server. The caller has checked the server's
/// answer and, for a self-hosted server, its admin token.
///
/// A call that throws leaves the saved session and the device identity as
/// they were.
class EstablishApiSessionUsecase {
  const EstablishApiSessionUsecase(
    this._sessions,
    this._register,
    this._identity,
  );
  final ApiSessionStore _sessions;
  final RegisterDeviceUsecase _register;
  final DeviceIdentityStore _identity;

  /// What [relay] is to the device token this phone holds, for a connect.
  /// Reads only: it mints no identity.
  ///
  /// [DeviceTokenRelayTrust.otherRelay] means the connect is refused: the
  /// token belongs to another relay and a server is saved on a relay of its
  /// own, so going ahead would replace a working connection.
  Future<DeviceTokenRelayTrust> relayTrust(Uri relay) async =>
      _relayPlan(await _identity.read(), await _sessions.read(), relay);

  /// [DeviceTokenRelayTrust.unknownIssuer] means the phone starts fresh on
  /// [relay]: it holds a token that relay did not issue, and nothing saved
  /// would be replaced. That is the case with no session saved, or, for a
  /// token with no issuer written down, with the session already on [relay].
  static DeviceTokenRelayTrust _relayPlan(
    DeviceIdentity? held,
    ApiSession? session,
    Uri relay,
  ) {
    final trust = deviceTokenRelayTrust(identity: held, relay: relay);
    switch (trust) {
      case DeviceTokenRelayTrust.noToken || DeviceTokenRelayTrust.issuer:
        return trust;
      case DeviceTokenRelayTrust.unknownIssuer ||
          DeviceTokenRelayTrust.otherRelay:
        if (session == null) return DeviceTokenRelayTrust.unknownIssuer;
        final onThisRelay = ServerInfoValidation.isSameAddress(
          session.relayUri.toString(),
          relay.toString(),
        );
        return trust == DeviceTokenRelayTrust.unknownIssuer && onThisRelay
            ? DeviceTokenRelayTrust.unknownIssuer
            : DeviceTokenRelayTrust.otherRelay;
    }
  }

  /// What the session and the identity hold now.
  Future<SessionCheckpoint> checkpoint() async =>
      SessionCheckpoint(await _sessions.read(), await _identity.snapshot());

  /// Puts the session and the identity back as [checkpoint] found them. For
  /// a connect whose last step failed after the session was written.
  Future<void> rollBack(SessionCheckpoint checkpoint) async {
    await _identity.restore(checkpoint.identity);
    final session = checkpoint.session;
    if (session == null) {
      await _sessions.clear();
    } else {
      await _sessions.write(session);
    }
  }

  /// [pushToken] is for a caller that already holds the token and has to
  /// tell "no token yet" apart from "the relay refused". Left out, the
  /// registration reads the token itself.
  Future<ApiSession> call(
    ServerInfo info,
    String adminToken, {
    String? pushToken,
  }) async {
    final mode = ServerMode.fromWireValue(info.mode);
    final relay = Uri.parse(info.relayUrl);
    final server = Uri.parse(info.baseUrl);
    // How to connect, not a plan: only a server with accounts registers
    // the device.
    final usesDeviceToken = mode != ServerMode.selfhosted; // access-ok: connect
    final previous = await _sessions.read();
    final held = await _identity.read();
    // The relay of the saved session is where the device token goes from
    // then on, whatever the mode, the native weekly check receipt included.
    // So a session never names a relay that did not issue the token this
    // phone holds: the phone starts fresh there, or the connect is refused.
    final relayPlan = _relayPlan(held, previous, relay);
    if (relayPlan == DeviceTokenRelayTrust.otherRelay) {
      throw const DeviceTokenRelayMismatch();
    }
    var startsFresh = relayPlan == DeviceTokenRelayTrust.unknownIssuer;
    // Where the device token is the credential, it is that for one server.
    if (usesDeviceToken && !startsFresh) {
      final serverTrust = deviceTokenServerTrust(
        identity: held,
        server: server,
      );
      if (serverTrust == DeviceTokenRelayTrust.otherRelay ||
          serverTrust == DeviceTokenRelayTrust.unknownIssuer) {
        // With nothing saved there is no working connection to keep, so the
        // phone starts fresh. Otherwise the connect is refused.
        if (previous != null) throw const DeviceTokenServerMismatch();
        startsFresh = true;
      }
    }
    final before = await checkpoint();
    try {
      if (startsFresh) await _identity.startFresh();
      var credential = adminToken;
      if (usesDeviceToken) {
        await _register(
          appVersion: appVersion,
          pushToken: pushToken,
          relayUri: relay,
          forServer: server,
        );
        final identity = await _identity.readOrCreate();
        final issuer = identity.tokenRelay;
        if (issuer != null &&
            !ServerInfoValidation.isSameAddress(issuer, relay.toString())) {
          throw const DeviceTokenRelayMismatch();
        }
        credential = identity.deviceToken!;
        // A token that belonged to no server yet belongs to this one now.
        if (identity.tokenServer == null) {
          await _identity.saveTokenOrigin(server: server);
        }
      }
      final session = ApiSession(
        baseUri: server,
        relayUri: relay,
        mode: mode,
        managementCredential: credential,
      );
      if (!session.canBeSaved) {
        throw ArgumentError('A session field holds the separator');
      }
      await _sessions.write(session);
      return session;
    } on Object {
      await rollBack(before);
      rethrow;
    }
  }
}
