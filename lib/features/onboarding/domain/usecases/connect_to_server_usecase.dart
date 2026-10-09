import 'package:critalarm/core/api/api_session.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/models/server_info.dart';
import 'package:critalarm/core/models/server_info_validator.dart';
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

/// The server answered but the connection could not be saved.
final class ConnectionNotSaved extends ConnectOutcome {
  const ConnectionNotSaved(this.failure);

  final Failure failure;
}

/// The connect threw on the way, which is a transport error.
final class ConnectTransportError extends ConnectOutcome {
  const ConnectTransportError(this.error);

  final Object error;
}

/// Connects the phone to a server: asks it who it is, checks the version,
/// sets up the session and saves the connection.
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
    final mode = ServerMode.fromWireValue(info.mode);
    // How to connect, not a plan: a self-hosted server wants its token.
    final needsToken = mode == ServerMode.selfhosted; // access-ok: connect
    if (needsToken && token.isEmpty) {
      return AdminTokenMissing(info);
    }
    try {
      final savedUrl = await readSavedServerUrl?.call();
      final session = await _establishSession(info, token);
      final saved = await _saveConnection(
        ServerConnection(
          serverUrl: info.baseUrl,
          adminToken: session.managementCredential,
        ),
      );
      final saveFailure = saved.exceptionOrNull();
      if (saveFailure != null) return ConnectionNotSaved(saveFailure);
      // Before anything loads from the new server: its incidents must not
      // be asked for from the old server's newest timestamp.
      if (readSavedServerUrl != null && !_sameServer(savedUrl, info.baseUrl)) {
        await forgetServerData?.call();
      }
      return Connected(info);
    } on Object catch (error) {
      return ConnectTransportError(error);
    }
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
    String norm(String url) {
      final trimmed = ServerInfoValidation.normalizeBaseUrl(url);
      return Uri.tryParse(trimmed)?.toString() ?? trimmed;
    }

    return norm(saved) == norm(reported);
  }
}
