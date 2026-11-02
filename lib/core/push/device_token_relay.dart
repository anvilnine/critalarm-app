import 'package:critalarm/core/models/device_identity.dart';
import 'package:critalarm/core/models/server_info_validator.dart';

/// The Crit Alarm Cloud relay. A relay credential this phone holds with no
/// relay written beside it counts as issued here: a device token saved by an
/// older version, the `aj_` join token in the synced iPhone account item, and
/// the device token of the old shared iPhone row.
const hostedRelayUrl = 'https://relay.critalarm.app';

/// True when [relay] is [hostedRelayUrl].
bool isHostedRelay(Uri relay) =>
    ServerInfoValidation.isSameAddress(hostedRelayUrl, relay.toString());

/// The Crit Alarm Cloud server. A device token with no server written beside
/// it counts as the management credential for this server and no other.
const hostedServerUrl = 'https://api.critalarm.app';

/// True when [server] is [hostedServerUrl].
bool isHostedServer(Uri server) =>
    ServerInfoValidation.isSameAddress(hostedServerUrl, server.toString());

/// What a relay is to the device token this phone holds.
enum DeviceTokenRelayTrust {
  /// The phone holds no device token, so there is nothing to keep back.
  noToken,

  /// The relay issued the token.
  issuer,

  /// The token has no issuer written beside it, so it counts as issued by
  /// the hosted relay, and this relay is another one. The token is not sent
  /// here. A registration here starts fresh.
  unknownIssuer,

  /// The relay written beside the token is another one.
  otherRelay,
}

/// A device token is the phone's credential on the relay that issued it, so
/// it goes to that relay and to no other.
///
/// The issuer is the relay saved beside the token. A token saved by an
/// older version has none and counts as issued by [hostedRelayUrl].
DeviceTokenRelayTrust deviceTokenRelayTrust({
  required DeviceIdentity? identity,
  required Uri relay,
}) {
  final token = identity?.deviceToken;
  if (token == null || token.trim().isEmpty) {
    return DeviceTokenRelayTrust.noToken;
  }
  final recorded = identity?.tokenRelay;
  if (recorded == null || recorded.trim().isEmpty) {
    return isHostedRelay(relay)
        ? DeviceTokenRelayTrust.issuer
        : DeviceTokenRelayTrust.unknownIssuer;
  }
  return ServerInfoValidation.isSameAddress(recorded, relay.toString())
      ? DeviceTokenRelayTrust.issuer
      : DeviceTokenRelayTrust.otherRelay;
}

/// On a server that is not self-hosted the device token is the management
/// credential, so it is that for one server address and for no other.
///
/// The address is the one saved beside the token. A token with none counts
/// as [hostedServerUrl]'s. The answer reads as [deviceTokenRelayTrust] does,
/// with the server in the relay's place: [DeviceTokenRelayTrust.unknownIssuer]
/// is a token with no server written down and a server that is not the
/// hosted one.
DeviceTokenRelayTrust deviceTokenServerTrust({
  required DeviceIdentity? identity,
  required Uri server,
}) {
  final token = identity?.deviceToken;
  if (token == null || token.trim().isEmpty) {
    return DeviceTokenRelayTrust.noToken;
  }
  final recorded = identity?.tokenServer;
  if (recorded == null || recorded.trim().isEmpty) {
    return isHostedServer(server)
        ? DeviceTokenRelayTrust.issuer
        : DeviceTokenRelayTrust.unknownIssuer;
  }
  return ServerInfoValidation.isSameAddress(recorded, server.toString())
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
