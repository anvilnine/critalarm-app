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
}) {
  final token = identity?.deviceToken;
  if (token == null || token.trim().isEmpty) {
    return DeviceTokenRelayTrust.noToken;
  }
  final issuer = identity?.tokenRelay ?? sessionRelay?.toString();
  if (issuer == null || issuer.trim().isEmpty) {
    return DeviceTokenRelayTrust.unknownIssuer;
  }
  return ServerInfoValidation.isSameAddress(issuer, relay.toString())
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
