import 'package:critalarm/core/api/api_session.dart';
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

  /// What [relay] is to the device token this phone holds. Reads only: it
  /// mints no identity.
  Future<DeviceTokenRelayTrust> relayTrust(Uri relay) async =>
      deviceTokenRelayTrust(
        identity: await _identity.read(),
        sessionRelay: (await _sessions.read())?.relayUri,
        relay: relay,
      );

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
    // then on, whatever the mode. So a session never names a relay that did
    // not issue the token this phone holds.
    if (deviceTokenRelayTrust(
          identity: held,
          sessionRelay: previous?.relayUri,
          relay: relay,
        ) ==
        DeviceTokenRelayTrust.otherRelay) {
      throw const DeviceTokenRelayMismatch();
    }
    // Where the device token is the credential, it is that for one server.
    if (usesDeviceToken &&
        deviceTokenServerTrust(
              identity: held,
              sessionServer: previous?.baseUri,
              server: server,
            ) ==
            DeviceTokenRelayTrust.otherRelay) {
      throw const DeviceTokenServerMismatch();
    }
    final before = await checkpoint();
    try {
      // The session is about to change. A token whose relay or server was
      // only known from the session gets both written down first.
      if (held?.deviceToken != null && previous != null) {
        await _identity.saveTokenOrigin(
          relay: held?.tokenRelay == null ? previous.relayUri : null,
          server: held?.tokenServer == null ? previous.baseUri : null,
        );
      }
      var credential = adminToken;
      if (usesDeviceToken) {
        await _register(
          appVersion: appVersion,
          pushToken: pushToken,
          relayUri: relay,
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
