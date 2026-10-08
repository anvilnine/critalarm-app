import 'package:critalarm/core/models/device_identity.dart';
import 'package:critalarm/core/models/server_info_validator.dart';

/// What a relay is to the device token this phone holds.
enum DeviceTokenRelayTrust {
  /// The phone holds no device token, so there is nothing to keep back.
  noToken,

  /// The relay issued the token.
  issuer,

  /// The phone holds a token and nothing says which relay issued it.
  unknownIssuer,

  /// Another relay issued the token.
  otherRelay,
}

/// A device token is the phone's credential on the relay that issued it, so
/// it goes to that relay and to no other.
///
/// The issuer is the relay saved beside the token. A token saved by an
/// older version has none, and counts as issued by [sessionRelay], the relay
/// of the saved session.
DeviceTokenRelayTrust deviceTokenRelayTrust({
  required DeviceIdentity? identity,
  required Uri? sessionRelay,
  required Uri relay,
}) => _trust(
  token: identity?.deviceToken,
  recorded: identity?.tokenRelay,
  fallback: sessionRelay,
  asked: relay,
);

/// On a server that is not self-hosted the device token is the management
/// credential, so it is that for one server address and for no other.
///
/// The address is the one saved beside the token. A token with none belongs
/// to [sessionServer], the server of the saved session. The answer reads as
/// [deviceTokenRelayTrust] does, with the server in the relay's place.
DeviceTokenRelayTrust deviceTokenServerTrust({
  required DeviceIdentity? identity,
  required Uri? sessionServer,
  required Uri server,
}) => _trust(
  token: identity?.deviceToken,
  recorded: identity?.tokenServer,
  fallback: sessionServer,
  asked: server,
);

DeviceTokenRelayTrust _trust({
  required String? token,
  required String? recorded,
  required Uri? fallback,
  required Uri asked,
}) {
  if (token == null || token.trim().isEmpty) {
    return DeviceTokenRelayTrust.noToken;
  }
  final owner = recorded ?? fallback?.toString();
  if (owner == null || owner.trim().isEmpty) {
    return DeviceTokenRelayTrust.unknownIssuer;
  }
  return ServerInfoValidation.isSameAddress(owner, asked.toString())
      ? DeviceTokenRelayTrust.issuer
      : DeviceTokenRelayTrust.otherRelay;
}

/// Thrown instead of sending the device token to a relay that did not issue
/// it. Nothing was sent.
final class DeviceTokenRelayMismatch implements Exception {
  const DeviceTokenRelayMismatch();

  @override
  String toString() => 'Device token belongs to another relay';
}

/// Thrown instead of making the device token the credential for a server
/// other than the one it belongs to. Nothing was sent.
final class DeviceTokenServerMismatch implements Exception {
  const DeviceTokenServerMismatch();

  @override
  String toString() => 'Device token belongs to another server';
}
