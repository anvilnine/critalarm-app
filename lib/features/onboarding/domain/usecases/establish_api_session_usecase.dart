import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/models/server_info_validator.dart';
import 'package:critalarm/core/push/device_token_relay.dart';
import 'package:critalarm/core/storage/api_session_store.dart';
import 'package:critalarm/core/storage/device_identity_store.dart';
import 'package:critalarm/core/version/app_version.dart';
import 'package:critalarm/features/onboarding/domain/usecases/register_device_usecase.dart';

/// Writes the session for a server. The caller has checked the server's
/// answer and, for a self-hosted server, its admin token.
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
    // The relay of the saved session is where the device token goes from
    // then on, whatever the mode. So a session never names a relay that did
    // not issue the token this phone holds.
    if (await relayTrust(relay) == DeviceTokenRelayTrust.otherRelay) {
      throw const DeviceTokenRelayMismatch();
    }
    var credential = adminToken;
    if (mode != ServerMode.selfhosted) {
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
    }
    final session = ApiSession(
      baseUri: Uri.parse(info.baseUrl),
      relayUri: relay,
      mode: mode,
      managementCredential: credential,
    );
    await _sessions.write(session);
    return session;
  }
}
