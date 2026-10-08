import 'package:critalarm/core/api/api_exception.dart';
import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/api/network_fault.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/models/server_info_validator.dart';
import 'package:critalarm/core/push/device_token_relay.dart';
import 'package:critalarm/features/onboarding/domain/entities/server_connection.dart';
import 'package:critalarm/features/onboarding/domain/usecases/establish_api_session_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/get_server_info_usecase.dart';
import 'package:critalarm/features/onboarding/domain/usecases/save_connection_usecase.dart';

/// How a [ConnectToServerUsecase] call ended.
sealed class ConnectOutcome {
  const ConnectOutcome();
}

/// The server answered, the session is set and the connection is saved.
final class Connected extends ConnectOutcome {
  const Connected(this.info);

  final ServerInfo info;
}

/// The server did not answer `/v1/info`.
final class ServerUnreachable extends ConnectOutcome {
  const ServerUnreachable(this.failure);

  final Failure failure;
}

/// The server runs a version this app does not speak.
final class ServerIncompatible extends ConnectOutcome {
  const ServerIncompatible(this.version);

  final String version;
}

/// A self-hosted server needs an admin token and none was given.
final class AdminTokenMissing extends ConnectOutcome {
  const AdminTokenMissing(this.info);

  final ServerInfo info;
}

/// A link named one server and its answer names another address: another
/// host, port, scheme or base path. The sheet shows what it was asked to
/// connect to, so it connects to nothing else.
final class ServerAddressDiffers extends ConnectOutcome {
  const ServerAddressDiffers(this.host);

  /// The host the server reported, with its port when not the usual one.
  /// When the host and port are the ones asked for and something else
  /// differs, the whole reported address.
  final String host;
}

/// A link asked for `https` and the server's answer is `http`. A connect
/// link never goes from encrypted to plain. Setup does not return this.
final class ServerDowngrade extends ConnectOutcome {
  const ServerDowngrade();
}

/// The answer to `/v1/info` is not one this app can connect to: an address
/// that is not an `http` or `https` address, or a mode it does not know.
final class ServerAnswerInvalid extends ConnectOutcome {
  const ServerAnswerInvalid();
}

/// A link named a server that is not self-hosted. A link carries an admin
/// token, and only a self-hosted server takes one.
final class LinkServerNotSelfHosted extends ConnectOutcome {
  const LinkServerNotSelfHosted();
}

/// The server did not accept the admin token. Nothing saved was changed.
final class AdminTokenRefused extends ConnectOutcome {
  const AdminTokenRefused();
}

/// The server names a relay other than the one this phone is registered
/// with. The phone's registration stays where it is.
final class RelayDiffers extends ConnectOutcome {
  const RelayDiffers();
}

/// A link named a server and nothing on the phone says whether its relay is
/// the one this phone is registered with.
final class RelayUnchecked extends ConnectOutcome {
  const RelayUnchecked();
}

/// The server would take this phone's device token as its credential, and
/// that token is the credential for another server.
final class RegisteredElsewhere extends ConnectOutcome {
  const RegisteredElsewhere();
}

/// The server answered but the connection could not be saved.
final class ConnectionNotSaved extends ConnectOutcome {
  const ConnectionNotSaved(this.failure);

  final Failure failure;
}

/// The connect threw on the way, which is a transport error.
///
/// Only the kind of error is kept. The text of what was thrown is dropped
/// here, because it can quote what was being sent.
final class ConnectTransportError extends ConnectOutcome {
  ConnectTransportError(Object error) : error = NetworkFault.of(error);

  final NetworkFault error;
}

/// Connects the phone to a server: asks it who it is, checks the whole
/// answer, proves the admin token on a self-hosted server, and only then
/// sets up the session and saves the connection. A connect that is refused
/// leaves the saved session, the saved connection and the device identity
/// as they were.
///
/// The setup connect step and a connect link both call this, so a server is
/// connected one way only. It does not touch the form, a draft, or what
/// comes after: the caller shows the result.
class ConnectToServerUsecase {
  const ConnectToServerUsecase(
    this._getServerInfo,
    this._establishSession,
    this._saveConnection, {
    this.cancelPendingConnect,
    this.readSavedServerUrl,
    this.forgetServerData,
    this.proveAdminToken,
    this.readRelayTrust,
  });

  final GetServerInfoUsecase _getServerInfo;
  final EstablishApiSessionUsecase _establishSession;
  final SaveConnectionUsecase _saveConnection;

  /// Drops a Crit Alarm Cloud connect still waiting behind the user. A
  /// server picked by hand replaces it, and it must not save over this one.
  final Future<void> Function()? cancelPendingConnect;

  /// The address of the server saved now, or null when there is none. Read
  /// before the new connection is saved.
  final Future<String?> Function()? readSavedServerUrl;

  /// Clears everything on the phone that belongs to the old server: the
  /// incident archive, the message cursors, the acknowledgements waiting to
  /// be sent and the recent searches. Runs when the new connection names a
  /// different server than the saved one, after it is saved.
  final Future<void> Function()? forgetServerData;

  /// Makes one authenticated read on the server at `baseUri` with the admin
  /// token, and throws an [ApiException] carrying the status when the
  /// server refuses it. Runs before anything is saved. Left out, the read
  /// goes through the same repository `/v1/info` does.
  final Future<void> Function(Uri baseUri, String adminToken)? proveAdminToken;

  /// What the relay a server names is to the device token this phone holds.
  /// Left out, the session use case answers.
  final Future<DeviceTokenRelayTrust> Function(Uri relay)? readRelayTrust;

  /// [serverUrl] and [adminToken] are trimmed here. The token is only
  /// handed to the session store and the saved connection, and it is in no
  /// outcome.
  ///
  /// The server's answer names its own base address, and that is what gets
  /// saved. With [pinToAddress] the answer must also name the scheme, host,
  /// port and base path in [serverUrl], and an `https` [serverUrl] never
  /// ends as `http`: a connect link shows one address and connects to that
  /// one. Typed in setup, the address is the person's own and the server's
  /// answer still stands, scheme included.
  Future<ConnectOutcome> call({
    required String serverUrl,
    required String adminToken,
    bool pinToAddress = false,
  }) async {
    await cancelPendingConnect?.call();
    final token = adminToken.trim();
    final result = await _getServerInfo(Uri.parse(serverUrl.trim()));
    final failure = result.exceptionOrNull();
    if (failure != null) return ServerUnreachable(failure);
    final info = result.getOrThrow();

    if (!ServerInfoValidation.isSemverCompatible(info.version)) {
      return ServerIncompatible(info.version);
    }
    final refused = _refuseAddress(
      asked: serverUrl.trim(),
      reported: info.baseUrl,
      pin: pinToAddress,
    );
    if (refused != null) return refused;
    final mode = _modeOf(info);
    final relay = _relayOf(info);
    if (mode == null ||
        relay == null ||
        !ServerInfoValidation.isValidServerInfo(info)) {
      return const ServerAnswerInvalid();
    }
    final isSelfHosted = mode == ServerMode.selfhosted;
    // A link carries an admin token, and only a self-hosted server takes
    // one. Nothing is registered anywhere for a link.
    if (pinToAddress && !isSelfHosted) return const LinkServerNotSelfHosted();
    if (isSelfHosted && token.isEmpty) return AdminTokenMissing(info);
    // A token an HTTP header cannot carry, or the saved session cannot
    // hold, is one no server issued. It is sent nowhere.
    if (isSelfHosted && !_canBeSent(token)) return const AdminTokenRefused();
    try {
      final trust = await (readRelayTrust ?? _establishSession.relayTrust)(
        relay,
      );
      if (trust == DeviceTokenRelayTrust.otherRelay) {
        return const RelayDiffers();
      }
      // Typed by hand, the server is the person's own choice and its relay
      // is taken as the issuer, as it was before the issuer was kept.
      if (pinToAddress && trust == DeviceTokenRelayTrust.unknownIssuer) {
        return const RelayUnchecked();
      }
      if (isSelfHosted) {
        final refusedToken = await _refuseToken(Uri.parse(info.baseUrl), token);
        if (refusedToken != null) return refusedToken;
      }
    } on Object catch (error) {
      return ConnectTransportError(error);
    }
    // Every check that needs no write has passed. From here a failure puts
    // the session and the identity back as they were.
    final SessionCheckpoint before;
    try {
      before = await _establishSession.checkpoint();
    } on Object catch (error) {
      return ConnectTransportError(error);
    }
    try {
      final savedUrl = await readSavedServerUrl?.call();
      // Refuses another relay or another server before it sends or writes
      // anything, and undoes its own writes when it throws.
      final session = await _establishSession(info, token);
      final Failure? saveFailure;
      try {
        final saved = await _saveConnection(
          ServerConnection(
            serverUrl: info.baseUrl,
            adminToken: session.managementCredential,
          ),
        );
        saveFailure = saved.exceptionOrNull();
      } on Object {
        await _establishSession.rollBack(before);
        rethrow;
      }
      if (saveFailure != null) {
        await _establishSession.rollBack(before);
        return ConnectionNotSaved(saveFailure);
      }
      // Before anything loads from the new server: its incidents must not
      // be asked for from the old server's newest timestamp.
      if (readSavedServerUrl != null && !_sameServer(savedUrl, info.baseUrl)) {
        await forgetServerData?.call();
      }
      return Connected(info);
    } on DeviceTokenRelayMismatch {
      return const RelayDiffers();
    } on DeviceTokenServerMismatch {
      return const RegisteredElsewhere();
    } on Object catch (error) {
      return ConnectTransportError(error);
    }
  }

  /// Every character is one an `Authorization` header can carry and the
  /// saved session can hold: visible ASCII, and not the session's separator.
  static bool _canBeSent(String token) =>
      !token.contains(ApiSession.fieldSeparator) &&
      token.codeUnits.every((unit) => unit > 0x20 && unit < 0x7F);

  /// Null when the server accepts [token].
  /// A `401` or `403` is a wrong token. Any other answer is a server that
  /// could not be asked.
  Future<ConnectOutcome?> _refuseToken(Uri baseUri, String token) async {
    final prove = proveAdminToken ?? _getServerInfo.proveAdminToken;
    try {
      await prove(baseUri, token);
      return null;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        return const AdminTokenRefused();
      }
      // Only the status is kept. The server wrote the rest of its answer,
      // and it may have written the token into it.
      return ServerUnreachable(Failure.api(statusCode: error.statusCode));
    }
  }

  /// The mode exactly as api.md §3.4 spells it, or null for anything else.
  static ServerMode? _modeOf(ServerInfo info) {
    try {
      return ServerMode.fromWireValue(info.mode);
    } on FormatException {
      return null;
    }
  }

  /// The relay address, or null when it is not a plain `http` or `https`
  /// address: one with a user name, a query or a fragment is refused.
  static Uri? _relayOf(ServerInfo info) {
    final relay = Uri.tryParse(info.relayUrl.trim());
    if (relay == null ||
        relay.host.isEmpty ||
        relay.userInfo.isNotEmpty ||
        relay.hasQuery ||
        relay.hasFragment) {
      return null;
    }
    return relay;
  }

  ConnectOutcome? _refuseAddress({
    required String asked,
    required String reported,
    required bool pin,
  }) {
    final from = Uri.tryParse(asked);
    final to = Uri.tryParse(reported.trim());
    if (to == null || to.host.isEmpty) {
      return pin ? ServerAddressDiffers(reported) : null;
    }
    // Only a link refuses any of this. Setup keeps following the server's
    // own base address, scheme included, because that address is hashed into
    // the push subscription key.
    if (!pin || from == null) return null;
    if (from.scheme == 'https' && to.scheme == 'http') {
      return const ServerDowngrade();
    }
    if (!_sameHostAndPort(from, to)) {
      return ServerAddressDiffers(_hostLabel(to));
    }
    // The host is the one the sheet showed, so naming it again would say
    // nothing. The whole reported address shows what differs.
    if (!_sameAddress(from, to)) return ServerAddressDiffers(to.toString());
    return null;
  }

  /// Same host and port. The letter case of the host does not matter, and
  /// neither does `https` against `https://...:443`.
  static bool _sameHostAndPort(Uri a, Uri b) {
    if (a.host.toLowerCase() != b.host.toLowerCase()) return false;
    final bothDefault = !a.hasPort && !b.hasPort;
    return bothDefault || a.port == b.port;
  }

  /// [reported] is the address the sheet showed as [agreed]: the same
  /// scheme, host, port (the usual one counts when none is written) and base
  /// path. One closing slash on the path does not matter, and nothing else is
  /// let through: a reported address with a user name, a query or a fragment
  /// is another address.
  static bool _sameAddress(Uri agreed, Uri reported) {
    if (reported.userInfo.isNotEmpty ||
        reported.hasQuery ||
        reported.hasFragment) {
      return false;
    }
    return agreed.scheme == reported.scheme &&
        agreed.host.toLowerCase() == reported.host.toLowerCase() &&
        agreed.port == reported.port &&
        _basePath(agreed) == _basePath(reported);
  }

  /// The path with one closing slash dropped, so `/one/` is `/one` and `/` is
  /// no path at all.
  static String _basePath(Uri uri) {
    final path = uri.path;
    return path.endsWith('/') ? path.substring(0, path.length - 1) : path;
  }

  static String _hostLabel(Uri uri) {
    final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
    return uri.hasPort ? '$host:${uri.port}' : host;
  }

  /// [saved] and [reported] are the same server when they differ at most by
  /// trailing slashes, spaces and the letter case of scheme and host.
  static bool _sameServer(String? saved, String reported) {
    if (saved == null || saved.trim().isEmpty) return false;
    return ServerInfoValidation.isSameAddress(saved, reported);
  }
}
